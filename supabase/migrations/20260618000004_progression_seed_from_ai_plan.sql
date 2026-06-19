-- Fix (2026-06-18): el overlay de progresión (recompute_progression_state)
-- ESTABA MUERTO en producción — referenciaba 3 columnas inexistentes y tenía
-- ambigüedades, así que SIEMPRE lanzaba excepción (atrapada en cliente →
-- overlay vacío). Por eso las series/reps que veía el usuario salían del plan
-- de IA (que era uniforme por prompt perezoso), no de la progresión.
--
-- Bugs corregidos (estaban apilados, cada uno enmascaraba al siguiente):
--   1. profiles.experience_level no existe → tier ahora desde
--      user_onboarding_data.training_level.
--   2. set_logs.created_at / reps_completed no existen → son logged_at / reps.
--   3. Ambigüedad OUT-param vs columna (exercise_name, etc.) → pragma
--      #variable_conflict use_column + alias de tablas.
--
-- Mejoras: siembra el estado inicial POR EJERCICIO desde el plan de IA
-- (params p_base_sets/p_base_reps_min/p_base_reps_max alineados con
-- p_exercise_names) → compuesto 4x6-8, aislamiento 3x12-15 (antes 3x8-12 para
-- todos). Normaliza el objetivo (GAIN_MUSCLE->MUSCLE_GAIN, etc.) que antes caía
-- siempre a MAINTAIN. Clearance/embarazo mantienen el esquema seguro de reglas.
--
-- NOTA: aplicada via MCP Supabase. Backup del DDL final.
DROP FUNCTION IF EXISTS public.recompute_progression_state(text[]);

CREATE OR REPLACE FUNCTION public.recompute_progression_state(
  p_exercise_names text[],
  p_base_sets integer[] DEFAULT NULL,
  p_base_reps_min integer[] DEFAULT NULL,
  p_base_reps_max integer[] DEFAULT NULL
)
 RETURNS TABLE(exercise_name text, current_sets integer, reps_min integer, reps_max integer, nudge_type text, nudge_message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
DECLARE
  v_uid uuid := auth.uid();
  v_tier text;
  v_goal text;
  v_clearance boolean;
  v_ed_risk boolean;
  v_pregnancy boolean;
  v_muscle_lookup jsonb := '{}'::jsonb;
  v_name text;
  v_rules jsonb;
  v_state public.exercise_progression_state%ROWTYPE;
  v_has_state boolean;
  v_last_3 jsonb;
  v_last_workout_at timestamptz;
  v_days_since_last int;
  v_reps_min_eff int;
  v_reps_max_eff int;
  v_max_sets_eff int;
  v_consec_needed int;
  v_consec_topped int;
  v_new_sets int;
  v_new_reps_min int;
  v_new_reps_max int;
  v_nudge_type text;
  v_nudge_msg text;
  v_weekly_sets int;
  v_muscle text;
  v_iso_week_now int;
  v_iso_year_now int;
  v_iso_week_last int;
  v_iso_year_last int;
  v_weeks_inc int;
  v_new_weeks_on int;
  v_new_weeks_since_deload int;
  v_failed_count int;
  v_sets_in_session int;
  v_failed_in_session int;
  v_idx int := 0;
  v_base_sets int;
  v_base_reps_min int;
  v_base_reps_max int;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  IF p_exercise_names IS NULL OR array_length(p_exercise_names, 1) IS NULL THEN
    RETURN;
  END IF;

  SELECT
    coalesce(p.fitness_goal, 'MAINTAIN'),
    coalesce(p.requires_medical_clearance, false),
    coalesce(p.eating_disorder_risk, false),
    coalesce(p.pregnancy_status, false)
    INTO v_goal, v_clearance, v_ed_risk, v_pregnancy
  FROM public.profiles p
  WHERE p.id = v_uid;

  SELECT coalesce(o.training_level, o.experience_level, 'BEGINNER')
    INTO v_tier
  FROM public.user_onboarding_data o
  WHERE o.user_id = v_uid
  ORDER BY o.created_at DESC
  LIMIT 1;

  v_tier := upper(coalesce(v_tier, 'BEGINNER'));
  v_tier := CASE
    WHEN v_tier LIKE 'ADVANCED%' THEN 'ADVANCED'
    WHEN v_tier LIKE 'INTERMEDIATE%' THEN 'INTERMEDIATE'
    ELSE 'BEGINNER'
  END;

  v_goal := upper(coalesce(v_goal, 'MAINTAIN'));
  v_goal := CASE
    WHEN v_goal IN ('GAIN_MUSCLE','MUSCLE_GAIN','HYPERTROPHY') THEN 'MUSCLE_GAIN'
    WHEN v_goal IN ('LOSE_WEIGHT','FAT_LOSS','CUTTING','TONE_BODY') THEN 'FAT_LOSS'
    WHEN v_goal IN ('STRENGTH','GET_STRONG') THEN 'STRENGTH'
    ELSE 'MAINTAIN'
  END;

  SELECT coalesce(jsonb_object_agg(name_es, muscle_group_primary), '{}'::jsonb)
    INTO v_muscle_lookup
  FROM public.exercise_catalog
  WHERE name_es = ANY(p_exercise_names);

  v_iso_week_now := extract(week FROM now() AT TIME ZONE 'UTC')::int;
  v_iso_year_now := extract(isoyear FROM now() AT TIME ZONE 'UTC')::int;

  FOREACH v_name IN ARRAY p_exercise_names LOOP
    v_idx := v_idx + 1;

    IF p_base_sets IS NOT NULL AND array_length(p_base_sets, 1) >= v_idx THEN
      v_base_sets := p_base_sets[v_idx];
    ELSE
      v_base_sets := NULL;
    END IF;
    IF p_base_reps_min IS NOT NULL AND array_length(p_base_reps_min, 1) >= v_idx THEN
      v_base_reps_min := p_base_reps_min[v_idx];
    ELSE
      v_base_reps_min := NULL;
    END IF;
    IF p_base_reps_max IS NOT NULL AND array_length(p_base_reps_max, 1) >= v_idx THEN
      v_base_reps_max := p_base_reps_max[v_idx];
    ELSE
      v_base_reps_max := NULL;
    END IF;

    v_rules := public._get_progression_rules(v_tier, v_goal);

    SELECT * INTO v_state
    FROM public.exercise_progression_state eps
    WHERE eps.user_id = v_uid AND eps.exercise_name = v_name;
    v_has_state := FOUND;

    v_reps_min_eff := (v_rules->>'reps_min')::int;
    v_reps_max_eff := (v_rules->>'reps_max')::int;
    v_max_sets_eff := (v_rules->>'max_sets')::int;
    v_consec_needed := (v_rules->>'consec_topped_needed')::int;
    IF v_clearance OR v_pregnancy THEN
      v_reps_min_eff := v_reps_min_eff + 2;
      IF v_reps_min_eff > v_reps_max_eff THEN
        v_reps_max_eff := v_reps_min_eff + 2;
      END IF;
      IF v_has_state THEN
        v_max_sets_eff := v_state.current_sets;
      END IF;
      v_consec_needed := v_consec_needed + 1;
    END IF;

    IF v_ed_risk THEN
      v_rules := jsonb_set(v_rules, '{deload_every}', to_jsonb(4));
    END IF;

    IF v_has_state THEN
      v_new_sets := v_state.current_sets;
      v_new_reps_min := v_state.reps_min;
      v_new_reps_max := v_state.reps_max;
      v_consec_topped := v_state.consecutive_topped;
    ELSE
      IF NOT v_clearance AND NOT v_pregnancy
         AND v_base_sets IS NOT NULL AND v_base_sets > 0 THEN
        v_new_sets := least(greatest(v_base_sets, 1), v_max_sets_eff);
      ELSE
        v_new_sets := 3;
      END IF;
      IF NOT v_clearance AND NOT v_pregnancy
         AND v_base_reps_min IS NOT NULL AND v_base_reps_max IS NOT NULL
         AND v_base_reps_min > 0 AND v_base_reps_max >= v_base_reps_min THEN
        v_new_reps_min := v_base_reps_min;
        v_new_reps_max := v_base_reps_max;
      ELSE
        v_new_reps_min := v_reps_min_eff;
        v_new_reps_max := v_reps_max_eff;
      END IF;
      v_consec_topped := 0;
    END IF;

    v_nudge_type := NULL;
    v_nudge_msg := NULL;

    SELECT coalesce(jsonb_agg(s.row ORDER BY s.created_at DESC), '[]'::jsonb)
      INTO v_last_3
    FROM (
      SELECT
        sl.workout_log_id,
        max(sl.logged_at) AS created_at,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY sl.reps)::numeric AS median_reps,
        count(*) FILTER (WHERE sl.reps < v_new_reps_min) AS failed_sets,
        count(*) AS total_sets,
        jsonb_build_object(
          'workout_log_id', sl.workout_log_id,
          'created_at', max(sl.logged_at),
          'median_reps', percentile_cont(0.5) WITHIN GROUP (ORDER BY sl.reps),
          'failed_sets', count(*) FILTER (WHERE sl.reps < v_new_reps_min),
          'total_sets', count(*)
        ) AS row
      FROM public.set_logs sl
      WHERE sl.user_id = v_uid AND sl.exercise_name = v_name
      GROUP BY sl.workout_log_id
      ORDER BY max(sl.logged_at) DESC
      LIMIT 3
    ) s;

    SELECT max(sl.logged_at) INTO v_last_workout_at
    FROM public.set_logs sl
    WHERE sl.user_id = v_uid AND sl.exercise_name = v_name;

    IF v_last_workout_at IS NOT NULL THEN
      v_days_since_last := greatest(0, extract(day FROM (now() - v_last_workout_at))::int);
    ELSE
      v_days_since_last := NULL;
    END IF;

    v_new_weeks_on := NULL;
    v_new_weeks_since_deload := NULL;

    IF v_days_since_last IS NOT NULL AND v_days_since_last > 14 THEN
      v_nudge_type := 'return_after_break';
      v_nudge_msg := 'Volviste tras una pausa. Empeza con menos peso esta semana, tu cuerpo necesita reactivarse.';
      v_consec_topped := 0;
      IF v_days_since_last > 60 THEN
        v_new_weeks_on := 0;
        v_new_weeks_since_deload := 0;
      ELSE
        v_new_weeks_on := coalesce(v_state.weeks_on_exercise, 0);
        v_new_weeks_since_deload := coalesce(v_state.weeks_since_deload, 0);
      END IF;
    END IF;

    IF v_nudge_type IS NULL AND jsonb_array_length(v_last_3) >= 2 THEN
      v_failed_count := 0;
      FOR i IN 0..(jsonb_array_length(v_last_3) - 1) LOOP
        v_sets_in_session := ((v_last_3->i)->>'total_sets')::int;
        v_failed_in_session := ((v_last_3->i)->>'failed_sets')::int;
        IF v_sets_in_session > 0 AND v_failed_in_session = v_sets_in_session THEN
          v_failed_count := v_failed_count + 1;
        END IF;
      END LOOP;
      IF v_failed_count >= 2 THEN
        v_nudge_type := 'failed_reps';
        v_nudge_msg := 'Baja un poco el peso o descansa mas entre series. Estas forzando.';
        v_consec_topped := 0;
      END IF;
    END IF;

    IF v_nudge_type IS NULL AND v_has_state THEN
      IF v_state.weeks_since_deload >= (v_rules->>'deload_every')::int THEN
        v_nudge_type := 'deload';
        v_nudge_msg := 'Esta semana haz menos series por ejercicio, igual peso. Tu cuerpo necesita asimilar.';
        v_new_sets := greatest(1, round(v_new_sets * 0.6)::int);
        v_consec_topped := 0;
      END IF;
    END IF;

    IF v_nudge_type IS NULL AND jsonb_array_length(v_last_3) >= 1 THEN
      v_consec_topped := 0;
      FOR i IN 0..(jsonb_array_length(v_last_3) - 1) LOOP
        IF ((v_last_3->i)->>'median_reps')::numeric >= v_new_reps_max THEN
          v_consec_topped := v_consec_topped + 1;
        ELSE
          EXIT;
        END IF;
      END LOOP;
      IF v_consec_topped >= v_consec_needed THEN
        v_nudge_type := 'increase_weight';
        v_nudge_msg := 'Listo para subir. Proba un poco mas de peso esta vez y baja las reps al rango bajo.';
        v_consec_topped := 0;
      END IF;
    END IF;

    IF v_nudge_type IS NULL
       AND v_has_state
       AND (v_rules->>'add_set_every')::int > 0
       AND v_state.weeks_on_exercise > 0
       AND v_state.weeks_on_exercise % (v_rules->>'add_set_every')::int = 0
       AND v_new_sets < v_max_sets_eff
       AND NOT v_clearance
       AND NOT v_ed_risk
       AND NOT v_pregnancy
    THEN
      v_muscle := v_muscle_lookup->>v_name;
      v_weekly_sets := 0;
      IF v_muscle IS NOT NULL THEN
        SELECT coalesce(sum(eps.current_sets), 0) INTO v_weekly_sets
        FROM public.exercise_progression_state eps
        JOIN public.exercise_catalog ec ON ec.name_es = eps.exercise_name
        WHERE eps.user_id = v_uid AND ec.muscle_group_primary = v_muscle;
      END IF;
      IF v_weekly_sets + 1 <= (v_rules->>'weekly_cap')::int THEN
        v_new_sets := v_new_sets + 1;
        v_nudge_type := 'add_set';
        v_nudge_msg := 'Esta semana suma una serie. Tu cuerpo esta listo para mas volumen.';
      END IF;
    END IF;

    IF v_has_state THEN
      v_new_weeks_on := coalesce(v_new_weeks_on, v_state.weeks_on_exercise);
      v_new_weeks_since_deload := coalesce(v_new_weeks_since_deload, v_state.weeks_since_deload);
      IF v_state.last_workout_at IS NOT NULL AND v_last_workout_at IS NOT NULL THEN
        v_iso_week_last := extract(week FROM v_state.last_workout_at AT TIME ZONE 'UTC')::int;
        v_iso_year_last := extract(isoyear FROM v_state.last_workout_at AT TIME ZONE 'UTC')::int;
        v_iso_week_now := extract(week FROM v_last_workout_at AT TIME ZONE 'UTC')::int;
        v_iso_year_now := extract(isoyear FROM v_last_workout_at AT TIME ZONE 'UTC')::int;
        IF v_iso_year_now <> v_iso_year_last OR v_iso_week_now <> v_iso_week_last THEN
          v_weeks_inc := 1;
        ELSE
          v_weeks_inc := 0;
        END IF;
        v_new_weeks_on := v_new_weeks_on + v_weeks_inc;
        IF v_nudge_type = 'deload' THEN
          v_new_weeks_since_deload := 0;
        ELSE
          v_new_weeks_since_deload := v_new_weeks_since_deload + v_weeks_inc;
        END IF;
      END IF;
    ELSE
      v_new_weeks_on := 0;
      v_new_weeks_since_deload := 0;
    END IF;

    INSERT INTO public.exercise_progression_state AS t (
      user_id, exercise_name, current_sets, reps_min, reps_max,
      nudge_type, nudge_message, last_workout_at,
      weeks_on_exercise, weeks_since_deload,
      consecutive_topped, consecutive_failed, computed_at
    ) VALUES (
      v_uid, v_name, v_new_sets, v_new_reps_min, v_new_reps_max,
      v_nudge_type, v_nudge_msg,
      coalesce(v_last_workout_at, v_state.last_workout_at),
      coalesce(v_new_weeks_on, 0),
      coalesce(v_new_weeks_since_deload, 0),
      v_consec_topped, 0, now()
    )
    ON CONFLICT (user_id, exercise_name) DO UPDATE SET
      current_sets = EXCLUDED.current_sets,
      reps_min = EXCLUDED.reps_min,
      reps_max = EXCLUDED.reps_max,
      nudge_type = EXCLUDED.nudge_type,
      nudge_message = EXCLUDED.nudge_message,
      last_workout_at = EXCLUDED.last_workout_at,
      weeks_on_exercise = EXCLUDED.weeks_on_exercise,
      weeks_since_deload = EXCLUDED.weeks_since_deload,
      consecutive_topped = EXCLUDED.consecutive_topped,
      computed_at = now();

    exercise_name := v_name;
    current_sets := v_new_sets;
    reps_min := v_new_reps_min;
    reps_max := v_new_reps_max;
    nudge_type := v_nudge_type;
    nudge_message := v_nudge_msg;
    RETURN NEXT;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.recompute_progression_state(text[], integer[], integer[], integer[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.recompute_progression_state(text[], integer[], integer[], integer[]) TO authenticated;
