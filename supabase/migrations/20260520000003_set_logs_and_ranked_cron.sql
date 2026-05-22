-- ============================================================
-- Ranked GOD MODE - Fase 3
-- set_logs (tabla detallada de series), stats exactas por temporada,
-- cron pg_cron para leaderboard y rotacion de temporadas,
-- seed_season_missions helper.
-- Idempotente. NO destruye datos.
-- ============================================================

-- ============================================================
-- 1) Tabla set_logs
-- ============================================================
CREATE TABLE IF NOT EXISTS public.set_logs (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workout_log_id   uuid REFERENCES public.workout_logs(id) ON DELETE CASCADE,
  exercise_id      uuid,
  exercise_name    text NOT NULL,
  movement_pattern text CHECK (movement_pattern IN
                     ('push_horizontal','push_vertical','pull_horizontal','pull_vertical','squat','hinge','other')),
  weight_kg        numeric(7,2) NOT NULL,
  reps             int NOT NULL CHECK (reps BETWEEN 1 AND 100),
  set_index        smallint NOT NULL,
  notes            text,
  logged_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_set_logs_user_date
  ON public.set_logs(user_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_set_logs_workout
  ON public.set_logs(workout_log_id);
CREATE INDEX IF NOT EXISTS idx_set_logs_pattern
  ON public.set_logs(user_id, movement_pattern);

ALTER TABLE public.set_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "set_logs: select own" ON public.set_logs;
CREATE POLICY "set_logs: select own"
  ON public.set_logs FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "set_logs: insert own" ON public.set_logs;
CREATE POLICY "set_logs: insert own"
  ON public.set_logs FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "set_logs: update own" ON public.set_logs;
CREATE POLICY "set_logs: update own"
  ON public.set_logs FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "set_logs: delete own" ON public.set_logs;
CREATE POLICY "set_logs: delete own"
  ON public.set_logs FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ============================================================
-- 2) Trigger AFTER INSERT en set_logs: actualizar user_strength_records
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_logs_after_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_e1rm     numeric;
  v_bw       numeric;
  v_pattern  text;
BEGIN
  -- Sanity: solo aplica con reps razonables y peso plausible.
  IF NEW.reps IS NULL OR NEW.reps < 1 OR NEW.reps > 30 THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(weight_kg, 70) INTO v_bw
    FROM public.profiles WHERE id = NEW.user_id;
  IF v_bw IS NULL THEN v_bw := 70; END IF;

  -- Peso fuera de rango razonable (>3x bodyweight) se ignora para PR
  IF NEW.weight_kg > 3 * v_bw THEN
    RETURN NEW;
  END IF;

  v_e1rm := NEW.weight_kg * (1 + NEW.reps::numeric / 30);
  v_pattern := COALESCE(NEW.movement_pattern, 'other');

  BEGIN
    IF NEW.exercise_id IS NOT NULL THEN
      INSERT INTO public.user_strength_records (
        user_id, exercise_id, movement_pattern,
        best_e1rm_kg, best_weight_kg, best_reps,
        bodyweight_at_pr_kg, achieved_at, source_log_id
      ) VALUES (
        NEW.user_id, NEW.exercise_id, v_pattern,
        v_e1rm, NEW.weight_kg, NEW.reps,
        v_bw, NEW.logged_at, NEW.workout_log_id
      )
      ON CONFLICT (user_id, exercise_id) DO UPDATE
        SET best_e1rm_kg        = GREATEST(public.user_strength_records.best_e1rm_kg, EXCLUDED.best_e1rm_kg),
            best_weight_kg      = CASE WHEN EXCLUDED.best_e1rm_kg > public.user_strength_records.best_e1rm_kg
                                       THEN EXCLUDED.best_weight_kg
                                       ELSE public.user_strength_records.best_weight_kg END,
            best_reps           = CASE WHEN EXCLUDED.best_e1rm_kg > public.user_strength_records.best_e1rm_kg
                                       THEN EXCLUDED.best_reps
                                       ELSE public.user_strength_records.best_reps END,
            bodyweight_at_pr_kg = CASE WHEN EXCLUDED.best_e1rm_kg > public.user_strength_records.best_e1rm_kg
                                       THEN EXCLUDED.bodyweight_at_pr_kg
                                       ELSE public.user_strength_records.bodyweight_at_pr_kg END,
            achieved_at         = CASE WHEN EXCLUDED.best_e1rm_kg > public.user_strength_records.best_e1rm_kg
                                       THEN EXCLUDED.achieved_at
                                       ELSE public.user_strength_records.achieved_at END,
            movement_pattern    = COALESCE(public.user_strength_records.movement_pattern, EXCLUDED.movement_pattern);
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- Si falla por catalogo o constraints, no rompemos el insert principal.
    NULL;
  END;

  BEGIN
    PERFORM public.recalculate_user_rank(NEW.user_id);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_logs_after_insert ON public.set_logs;
CREATE TRIGGER trg_set_logs_after_insert
  AFTER INSERT ON public.set_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_logs_after_insert();

-- ============================================================
-- 3) get_user_season_stats: volumen exacto, racha mas larga, PRs, dias
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_season_stats(
  p_user_id  uuid,
  p_season_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_start         date;
  v_end           date;
  v_total_volume  numeric := 0;
  v_longest       int := 0;
  v_prs           int := 0;
  v_days          int := 0;
BEGIN
  -- Solo el propio user o service_role puede consultar sus stats
  IF p_user_id IS DISTINCT FROM auth.uid()
     AND COALESCE(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'no autorizado';
  END IF;

  SELECT start_date, end_date INTO v_start, v_end
    FROM public.ranked_seasons WHERE id = p_season_id;
  IF v_start IS NULL THEN
    RETURN jsonb_build_object(
      'total_volume_kg', 0,
      'longest_streak', 0,
      'prs_count', 0,
      'days_trained', 0
    );
  END IF;

  -- Volumen total: SUM(weight_kg * reps) en set_logs durante la temporada.
  SELECT COALESCE(SUM(weight_kg * reps), 0)::numeric INTO v_total_volume
    FROM public.set_logs
   WHERE user_id = p_user_id
     AND logged_at::date BETWEEN v_start AND v_end;

  -- Dias entrenados distintos en workout_logs
  SELECT COUNT(DISTINCT logged_at) INTO v_days
    FROM public.workout_logs
   WHERE user_id = p_user_id
     AND logged_at BETWEEN v_start AND v_end;

  -- Racha mas larga consecutiva en workout_logs.
  -- Tecnica: por cada fecha distinct, fecha - row_number(); el grupo con
  -- mismo offset = bloque consecutivo. Tomar el bloque mas largo.
  WITH distinct_days AS (
    SELECT DISTINCT logged_at AS d
      FROM public.workout_logs
     WHERE user_id = p_user_id
       AND logged_at BETWEEN v_start AND v_end
  ),
  grouped AS (
    SELECT d, d - (ROW_NUMBER() OVER (ORDER BY d))::int AS grp
      FROM distinct_days
  )
  SELECT COALESCE(MAX(c), 0) INTO v_longest
    FROM (SELECT COUNT(*) AS c FROM grouped GROUP BY grp) t;

  -- PRs: numero de exercise_id distintos donde el user tiene PR registrado
  -- con achieved_at dentro de la temporada.
  SELECT COUNT(DISTINCT exercise_id) INTO v_prs
    FROM public.user_strength_records
   WHERE user_id = p_user_id
     AND achieved_at::date BETWEEN v_start AND v_end;

  RETURN jsonb_build_object(
    'total_volume_kg', v_total_volume,
    'longest_streak', v_longest,
    'prs_count', v_prs,
    'days_trained', v_days
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_user_season_stats(uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_user_season_stats(uuid, uuid) TO authenticated;

-- ============================================================
-- 4) seed_season_missions(p_season_id): inserta 4 misiones x 12 semanas
-- ============================================================
CREATE OR REPLACE FUNCTION public.seed_season_missions(p_season_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  w int;
BEGIN
  IF p_season_id IS NULL THEN RETURN; END IF;

  FOR w IN 1..12 LOOP
    -- consistency
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (p_season_id, w, 'w' || w || '_workouts',
            'Acumula fuerza',
            'Completa ' || (3 + (w % 3)) || ' entrenamientos esta semana.',
            (3 + (w % 3)), 60 + (w * 5), 'consistency', 'easy')
    ON CONFLICT (season_id, week_number, key) DO NOTHING;

    -- strength
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (p_season_id, w, 'w' || w || '_pr',
            'Rompe el techo',
            'Registra al menos 1 PR de fuerza esta semana.',
            1, 80 + (w * 4), 'strength',
            CASE WHEN w < 6 THEN 'medium' ELSE 'hard' END)
    ON CONFLICT (season_id, week_number, key) DO NOTHING;

    -- community
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (p_season_id, w, 'w' || w || '_community',
            CASE WHEN w % 2 = 0 THEN 'Inspira a la tribu' ELSE 'Tu huella crece' END,
            CASE WHEN w % 2 = 0
                 THEN 'Publica una rutina nueva esta semana.'
                 ELSE 'Consigue ' || (1 + (w / 4)) || ' copias en tus rutinas.'
            END,
            CASE WHEN w % 2 = 0 THEN 1 ELSE (1 + (w / 4)) END,
            70 + (w * 6),
            'community',
            CASE WHEN w < 7 THEN 'medium' ELSE 'hard' END)
    ON CONFLICT (season_id, week_number, key) DO NOTHING;

    -- challenge
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (p_season_id, w, 'w' || w || '_challenge',
            CASE WHEN w % 2 = 0 THEN 'Multi patron' ELSE 'Racha imparable' END,
            CASE WHEN w % 2 = 0
                 THEN 'Registra 2 PRs en distintos patrones de movimiento.'
                 ELSE 'Mantén una racha de ' || (5 + w) || ' dias activos.'
            END,
            CASE WHEN w % 2 = 0 THEN 2 ELSE (5 + w) END,
            100 + (w * 10),
            'challenge',
            'hard')
    ON CONFLICT (season_id, week_number, key) DO NOTHING;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.seed_season_missions(uuid) FROM public;

-- ============================================================
-- 5) Reemplazar start_next_season para que tambien siembre misiones
-- ============================================================
CREATE OR REPLACE FUNCTION public.start_next_season(
  p_name  text,
  p_slug  text,
  p_theme text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role     text;
  v_is_admin boolean := false;
  v_id       uuid;
BEGIN
  v_role := COALESCE(auth.role(), '');
  BEGIN
    EXECUTE 'SELECT COALESCE(is_admin, false) FROM public.profiles WHERE id = $1'
       INTO v_is_admin USING auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_is_admin := false;
  END;

  IF v_role <> 'service_role' AND NOT v_is_admin THEN
    RAISE EXCEPTION 'no autorizado';
  END IF;

  INSERT INTO public.ranked_seasons (name, slug, theme_label, start_date, end_date, is_active, total_weeks)
  VALUES (p_name, p_slug, p_theme, current_date, current_date + interval '12 weeks', true, 12)
  RETURNING id INTO v_id;

  PERFORM public.seed_season_missions(v_id);

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.start_next_season(text, text, text) FROM public;

-- ============================================================
-- 6) auto_rotate_seasons: cron diario que cierra y abre temporada si vencio
-- ============================================================
CREATE OR REPLACE FUNCTION public.auto_rotate_seasons()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_active     record;
  v_count      int;
  v_theme      text;
  v_name       text;
  v_slug       text;
  v_themes     text[] := ARRAY['Ascenso','Forja','Cumbre','Eclipse','Vanguardia'];
  v_new_id     uuid;
BEGIN
  SELECT id, end_date, slug INTO v_active
    FROM public.ranked_seasons
   WHERE is_active = true
   ORDER BY start_date DESC
   LIMIT 1;

  IF v_active.id IS NULL THEN
    RETURN;
  END IF;

  IF current_date < v_active.end_date THEN
    RETURN;
  END IF;

  -- Cerrar
  PERFORM public.close_season(v_active.id);

  -- Calcular nombre/slug/theme rotativo
  SELECT COUNT(*) INTO v_count FROM public.ranked_seasons WHERE is_active = false;
  v_theme := v_themes[(v_count % array_length(v_themes, 1)) + 1];
  v_name  := 'Temporada ' || (v_count + 1) || ' ' || v_theme;
  v_slug  := lower(regexp_replace(v_theme, '[^a-zA-Z0-9]+', '-', 'g'))
             || '-' || to_char(current_date, 'YYYYMMDD');

  -- Asegurar slug unico
  IF EXISTS (SELECT 1 FROM public.ranked_seasons WHERE slug = v_slug) THEN
    v_slug := v_slug || '-' || floor(random() * 10000)::text;
  END IF;

  INSERT INTO public.ranked_seasons (name, slug, theme_label, start_date, end_date, is_active, total_weeks)
  VALUES (v_name, v_slug, v_theme, current_date, current_date + interval '12 weeks', true, 12)
  RETURNING id INTO v_new_id;

  PERFORM public.seed_season_missions(v_new_id);
END;
$$;

REVOKE ALL ON FUNCTION public.auto_rotate_seasons() FROM public;

-- ============================================================
-- 7) Cron jobs (pg_cron). Idempotente: unschedule si ya existe.
-- ============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      PERFORM cron.unschedule('refresh-ranked-leaderboard');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
    PERFORM cron.schedule(
      'refresh-ranked-leaderboard',
      '*/15 * * * *',
      $cron$SELECT public.refresh_ranked_leaderboard();$cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available, skipping leaderboard refresh schedule';
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      PERFORM cron.unschedule('auto-rotate-ranked-seasons');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
    PERFORM cron.schedule(
      'auto-rotate-ranked-seasons',
      '0 4 * * *',
      $cron$SELECT public.auto_rotate_seasons();$cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available, skipping season rotation schedule';
END $$;
