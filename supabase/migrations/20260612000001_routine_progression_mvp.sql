-- Routine progression MVP (Fase 1)
-- Overlay deterministico encima del plan IA. Cero llamadas a IA.
-- Respaldo: NSCA, ACSM, ACOG 804/2020, Schoenfeld 2017, Plotkin 2022,
-- Pritchard 2015, Bosquet 2013. Validado por IronCoach (agente interno).
--
-- Cambios:
-- 1) profiles.pregnancy_status (boolean)
-- 2) Tabla exercise_progression_state (overlay por user x ejercicio)
-- 3) RPC recompute_progression_state(p_exercise_names text[])
-- 4) Helper privado _get_progression_rules(tier, goal) -> jsonb

-- =============================================================
-- 1. profiles.pregnancy_status
-- =============================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS pregnancy_status boolean DEFAULT false;
COMMENT ON COLUMN public.profiles.pregnancy_status IS
  'Embarazo actual (ACOG 804/2020). Bloquea auto-incremento de volumen y filtra ejercicios con contraindicacion "embarazo".';

-- =============================================================
-- 2. exercise_progression_state
-- =============================================================
CREATE TABLE IF NOT EXISTS public.exercise_progression_state (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  exercise_name text NOT NULL,
  current_sets integer NOT NULL,
  reps_min integer NOT NULL,
  reps_max integer NOT NULL,
  nudge_type text,
  nudge_message text,
  last_workout_at timestamptz,
  weeks_on_exercise integer NOT NULL DEFAULT 0,
  weeks_since_deload integer NOT NULL DEFAULT 0,
  consecutive_topped integer NOT NULL DEFAULT 0,
  consecutive_failed integer NOT NULL DEFAULT 0,
  computed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT exercise_progression_state_uniq UNIQUE (user_id, exercise_name)
);

CREATE INDEX IF NOT EXISTS idx_exercise_progression_state_user
  ON public.exercise_progression_state (user_id);

ALTER TABLE public.exercise_progression_state ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "exercise_progression_state_select_own"
  ON public.exercise_progression_state;
CREATE POLICY "exercise_progression_state_select_own"
  ON public.exercise_progression_state
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "exercise_progression_state_insert_own"
  ON public.exercise_progression_state;
CREATE POLICY "exercise_progression_state_insert_own"
  ON public.exercise_progression_state
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "exercise_progression_state_update_own"
  ON public.exercise_progression_state;
CREATE POLICY "exercise_progression_state_update_own"
  ON public.exercise_progression_state
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- =============================================================
-- 3. Helper: reglas de progresion por tier + goal
-- =============================================================
CREATE OR REPLACE FUNCTION public._get_progression_rules(
  p_tier text,
  p_goal text
) RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_tier text := upper(coalesce(p_tier, 'BEGINNER'));
  v_goal text := upper(coalesce(p_goal, 'MAINTAIN'));
  v_reps_min int;
  v_reps_max int;
  v_add_set_every int;  -- 0 = nunca
  v_max_sets int;
  v_deload_every int;   -- semanas
  v_weekly_cap int;
  v_consec_topped_needed int;
BEGIN
  -- Normalizar goal
  IF v_goal NOT IN ('STRENGTH','MUSCLE_GAIN','FAT_LOSS','MAINTAIN') THEN
    v_goal := 'MAINTAIN';
  END IF;

  IF v_tier = 'ADVANCED' THEN
    v_deload_every := 4;
    v_weekly_cap := 25;
    v_max_sets := 6;
    v_consec_topped_needed := 3;
    IF v_goal = 'STRENGTH' THEN
      v_reps_min := 3; v_reps_max := 5; v_add_set_every := 6;
    ELSIF v_goal = 'MUSCLE_GAIN' THEN
      v_reps_min := 5; v_reps_max := 8; v_add_set_every := 4;
    ELSE
      v_reps_min := 6; v_reps_max := 10; v_add_set_every := 8;
    END IF;
  ELSIF v_tier = 'INTERMEDIATE' THEN
    v_deload_every := 6;
    v_weekly_cap := 20;
    v_max_sets := 5;
    v_consec_topped_needed := 2;
    IF v_goal = 'STRENGTH' THEN
      v_reps_min := 4; v_reps_max := 6; v_add_set_every := 6;
    ELSIF v_goal = 'MUSCLE_GAIN' THEN
      v_reps_min := 6; v_reps_max := 10; v_add_set_every := 4;
    ELSE
      v_reps_min := 8; v_reps_max := 12; v_add_set_every := 6;
    END IF;
  ELSE
    -- BEGINNER
    v_tier := 'BEGINNER';
    v_deload_every := 8;
    v_weekly_cap := 14;
    v_max_sets := 3;
    v_consec_topped_needed := 1;
    IF v_goal = 'STRENGTH' THEN
      v_reps_min := 5; v_reps_max := 8; v_add_set_every := 0;
    ELSIF v_goal = 'MUSCLE_GAIN' THEN
      v_reps_min := 8; v_reps_max := 12; v_add_set_every := 4; v_max_sets := 4;
    ELSE
      v_reps_min := 8; v_reps_max := 12; v_add_set_every := 0;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'tier', v_tier,
    'goal', v_goal,
    'reps_min', v_reps_min,
    'reps_max', v_reps_max,
    'add_set_every', v_add_set_every,
    'max_sets', v_max_sets,
    'deload_every', v_deload_every,
    'weekly_cap', v_weekly_cap,
    'consec_topped_needed', v_consec_topped_needed
  );
END;
$$;

-- =============================================================
-- 4. RPC recompute_progression_state
-- =============================================================
-- Entrada: array de exercise_name (los que se mostraran HOY al usuario).
-- Salida: una fila por ejercicio con sets/reps actuales y nudge opcional.
-- Reglas evaluadas en orden, primera que matchea gana:
--   (a) regression por abandono (>14d, reset si >60d)
--   (b) falla repetida (2/3 sesiones bajo reps_min)
--   (c) deload programado (weeks_since_deload >= deload_every)
--   (d) trigger subida (N sesiones consecutivas tocando reps_max)
--   (e) +1 set programado (respeta weekly_cap y banderas clinicas)
--   (f) sin cambio
DROP FUNCTION IF EXISTS public.recompute_progression_state(text[]);
CREATE OR REPLACE FUNCTION public.recompute_progression_state(
  p_exercise_names text[]
) RETURNS TABLE (
  exercise_name text,
  current_sets int,
  reps_min int,
  reps_max int,
  nudge_type text,
  nudge_message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  IF p_exercise_names IS NULL OR array_length(p_exercise_names, 1) IS NULL THEN
    RETURN;
  END IF;

  -- Perfil + flags clinicos + tier + goal
  SELECT
    coalesce(p.experience_level, 'BEGINNER'),
    coalesce(p.fitness_goal, 'MAINTAIN'),
    coalesce(p.requires_medical_clearance, false),
    coalesce(p.eating_disorder_risk, false),
    coalesce(p.pregnancy_status, false)
    INTO v_tier, v_goal, v_clearance, v_ed_risk, v_pregnancy
  FROM public.profiles p
  WHERE p.id = v_uid;

  IF v_tier IS NULL THEN v_tier := 'BEGINNER'; END IF;
  IF v_goal IS NULL THEN v_goal := 'MAINTAIN'; END IF;

  -- Map exercise_name -> muscle_group_primary para el cap semanal
  SELECT coalesce(jsonb_object_agg(name_es, muscle_group_primary), '{}'::jsonb)
    INTO v_muscle_lookup
  FROM public.exercise_catalog
  WHERE name_es = ANY(p_exercise_names);

  v_iso_week_now := extract(week FROM now() AT TIME ZONE 'UTC')::int;
  v_iso_year_now := extract(isoyear FROM now() AT TIME ZONE 'UTC')::int;

  FOREACH v_name IN ARRAY p_exercise_names LOOP
    v_rules := public._get_progression_rules(v_tier, v_goal);

    -- Estado previo
    SELECT * INTO v_state
    FROM public.exercise_progression_state
    WHERE user_id = v_uid AND exercise_name = v_name;
    v_has_state := FOUND;

    -- Adaptaciones clinicas: reps_min += 2, max_sets congelado
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

    -- Deload acelerado si riesgo TCA
    IF v_ed_risk THEN
      -- usar 4 semanas independiente del tier
      v_rules := jsonb_set(v_rules, '{deload_every}', to_jsonb(4));
    END IF;

    -- Inicializar valores actuales (si no hay estado, usar 3 sets defaults)
    IF v_has_state THEN
      v_new_sets := v_state.current_sets;
      v_new_reps_min := v_state.reps_min;
      v_new_reps_max := v_state.reps_max;
      v_consec_topped := v_state.consecutive_topped;
    ELSE
      v_new_sets := 3;
      v_new_reps_min := v_reps_min_eff;
      v_new_reps_max := v_reps_max_eff;
      v_consec_topped := 0;
    END IF;

    v_nudge_type := NULL;
    v_nudge_msg := NULL;

    -- Cargar ultimas 3 sesiones distintas de este ejercicio para el user.
    -- Una "sesion" = workout_log_id. Para cada sesion calculamos median reps
    -- y cuantos sets quedaron bajo reps_min (failed).
    SELECT coalesce(jsonb_agg(s.row ORDER BY s.created_at DESC), '[]'::jsonb)
      INTO v_last_3
    FROM (
      SELECT
        workout_log_id,
        max(created_at) AS created_at,
        percentile_cont(0.5) WITHIN GROUP (
          ORDER BY reps_completed
        )::numeric AS median_reps,
        count(*) FILTER (WHERE reps_completed < v_new_reps_min) AS failed_sets,
        count(*) AS total_sets,
        jsonb_build_object(
          'workout_log_id', workout_log_id,
          'created_at', max(created_at),
          'median_reps', percentile_cont(0.5) WITHIN GROUP (
            ORDER BY reps_completed
          ),
          'failed_sets', count(*) FILTER (WHERE reps_completed < v_new_reps_min),
          'total_sets', count(*)
        ) AS row
      FROM public.set_logs
      WHERE user_id = v_uid AND exercise_name = v_name
      GROUP BY workout_log_id
      ORDER BY max(created_at) DESC
      LIMIT 3
    ) s;

    -- Ultima sesion (si existe)
    SELECT max(created_at) INTO v_last_workout_at
    FROM public.set_logs
    WHERE user_id = v_uid AND exercise_name = v_name;

    IF v_last_workout_at IS NOT NULL THEN
      v_days_since_last := greatest(0,
        extract(day FROM (now() - v_last_workout_at))::int);
    ELSE
      v_days_since_last := NULL;
    END IF;

    -- ------------------------------------------------------------
    -- Regla (a): regression por abandono
    -- ------------------------------------------------------------
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

    -- ------------------------------------------------------------
    -- Regla (b): falla repetida (2 de las ultimas 3 sesiones)
    --           ALL_OF las series < reps_min
    -- ------------------------------------------------------------
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

    -- ------------------------------------------------------------
    -- Regla (c): deload programado
    -- ------------------------------------------------------------
    IF v_nudge_type IS NULL AND v_has_state THEN
      IF v_state.weeks_since_deload >= (v_rules->>'deload_every')::int THEN
        v_nudge_type := 'deload';
        v_nudge_msg := 'Esta semana haz menos series por ejercicio, igual peso. Tu cuerpo necesita asimilar.';
        v_new_sets := greatest(1, round(v_new_sets * 0.6)::int);
        v_consec_topped := 0;
      END IF;
    END IF;

    -- ------------------------------------------------------------
    -- Regla (d): trigger de subida (double progression)
    -- ------------------------------------------------------------
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

    -- ------------------------------------------------------------
    -- Regla (e): +1 set programado
    -- ------------------------------------------------------------
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
      -- Validar cap semanal por grupo muscular
      v_muscle := v_muscle_lookup->>v_name;
      v_weekly_sets := 0;
      IF v_muscle IS NOT NULL THEN
        SELECT coalesce(sum(eps.current_sets), 0) INTO v_weekly_sets
        FROM public.exercise_progression_state eps
        JOIN public.exercise_catalog ec
          ON ec.name_es = eps.exercise_name
        WHERE eps.user_id = v_uid
          AND ec.muscle_group_primary = v_muscle;
      END IF;
      IF v_weekly_sets + 1 <= (v_rules->>'weekly_cap')::int THEN
        v_new_sets := v_new_sets + 1;
        v_nudge_type := 'add_set';
        v_nudge_msg := 'Esta semana suma una serie. Tu cuerpo esta listo para mas volumen.';
      END IF;
    END IF;

    -- ------------------------------------------------------------
    -- Calcular weeks_on_exercise / weeks_since_deload
    -- ------------------------------------------------------------
    IF v_has_state THEN
      v_new_weeks_on := coalesce(v_new_weeks_on, v_state.weeks_on_exercise);
      v_new_weeks_since_deload := coalesce(v_new_weeks_since_deload,
        v_state.weeks_since_deload);
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

    -- ------------------------------------------------------------
    -- Upsert estado
    -- ------------------------------------------------------------
    INSERT INTO public.exercise_progression_state (
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
$$;

REVOKE ALL ON FUNCTION public.recompute_progression_state(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.recompute_progression_state(text[])
  TO authenticated;
