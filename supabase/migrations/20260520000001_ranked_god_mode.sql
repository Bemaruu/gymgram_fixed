-- ============================================================
-- Ranked GOD MODE - Fase 1
-- Tablas, RLS, funciones SECURITY DEFINER y trigger sobre workout_logs.
-- Idempotente: IF NOT EXISTS + DROP POLICY IF EXISTS.
-- NO modifica tablas existentes (workout_logs, routines, profiles)
-- excepto por agregar un trigger AFTER INSERT en workout_logs.
-- ============================================================

-- ============================================================
-- 1) ranked_seasons
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ranked_seasons (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  slug         text NOT NULL UNIQUE,
  theme_label  text,
  start_date   date NOT NULL,
  end_date     date NOT NULL,
  is_active    boolean NOT NULL DEFAULT false,
  total_weeks  int NOT NULL DEFAULT 12,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ranked_seasons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ranked_seasons: select all" ON public.ranked_seasons;
CREATE POLICY "ranked_seasons: select all"
  ON public.ranked_seasons FOR SELECT
  TO authenticated
  USING (true);

-- Temporada inicial: Genesis (solo si no existe)
INSERT INTO public.ranked_seasons (name, slug, theme_label, start_date, end_date, is_active, total_weeks)
SELECT 'Temporada 1 Génesis', 'genesis', 'Génesis', current_date, current_date + interval '12 weeks', true, 12
WHERE NOT EXISTS (SELECT 1 FROM public.ranked_seasons WHERE slug = 'genesis');

-- ============================================================
-- 2) user_strength_records
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_strength_records (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exercise_id           uuid REFERENCES public.exercise_catalog(id) ON DELETE SET NULL,
  movement_pattern      text NOT NULL CHECK (movement_pattern IN
                          ('push_horizontal','push_vertical','pull_horizontal','pull_vertical','squat','hinge','other')),
  best_e1rm_kg          numeric(7,2),
  best_weight_kg        numeric(7,2),
  best_reps             int CHECK (best_reps BETWEEN 1 AND 30),
  bodyweight_at_pr_kg   numeric(6,2),
  achieved_at           timestamptz NOT NULL DEFAULT now(),
  source_log_id         uuid,
  UNIQUE (user_id, exercise_id)
);

CREATE INDEX IF NOT EXISTS idx_user_strength_records_user
  ON public.user_strength_records(user_id);

ALTER TABLE public.user_strength_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_strength_records: select own" ON public.user_strength_records;
CREATE POLICY "user_strength_records: select own"
  ON public.user_strength_records FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "user_strength_records: insert own" ON public.user_strength_records;
CREATE POLICY "user_strength_records: insert own"
  ON public.user_strength_records FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "user_strength_records: update own" ON public.user_strength_records;
CREATE POLICY "user_strength_records: update own"
  ON public.user_strength_records FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 3) user_ranked_profile
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_ranked_profile (
  user_id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  current_season_id  uuid REFERENCES public.ranked_seasons(id) ON DELETE SET NULL,
  current_tier       text NOT NULL DEFAULT 'hierro'
                     CHECK (current_tier IN ('hierro','bronce','plata','oro','platino','diamante','inmortal')),
  current_division   smallint DEFAULT 3
                     CHECK (current_division IS NULL OR current_division BETWEEN 1 AND 3),
  current_rp         int NOT NULL DEFAULT 0,
  strength_score     int NOT NULL DEFAULT 0,
  consistency_score  int NOT NULL DEFAULT 0,
  community_score    int NOT NULL DEFAULT 0,
  challenge_score    int NOT NULL DEFAULT 0,
  last_recalc_at     timestamptz,
  last_activity_at   timestamptz,
  peak_history       jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_ranked_profile ENABLE ROW LEVEL SECURITY;

-- SELECT publico: para mostrar rangos ajenos en perfiles
DROP POLICY IF EXISTS "user_ranked_profile: select all" ON public.user_ranked_profile;
CREATE POLICY "user_ranked_profile: select all"
  ON public.user_ranked_profile FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "user_ranked_profile: insert own" ON public.user_ranked_profile;
CREATE POLICY "user_ranked_profile: insert own"
  ON public.user_ranked_profile FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "user_ranked_profile: update own" ON public.user_ranked_profile;
CREATE POLICY "user_ranked_profile: update own"
  ON public.user_ranked_profile FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 4) rp_transactions (append-only)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.rp_transactions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  season_id      uuid REFERENCES public.ranked_seasons(id) ON DELETE SET NULL,
  week_number    smallint,
  delta          int NOT NULL,
  source         text NOT NULL CHECK (source IN
                   ('strength_pr','workout_complete','streak','copy_received',
                    'completion_by_other','tier_up_inspired','mission','decay',
                    'climb_week_bonus','manual')),
  source_ref_id  uuid,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rp_transactions_user_season_week
  ON public.rp_transactions(user_id, season_id, week_number);

ALTER TABLE public.rp_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rp_transactions: select own" ON public.rp_transactions;
CREATE POLICY "rp_transactions: select own"
  ON public.rp_transactions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- INSERT bloqueado al cliente: solo SECURITY DEFINER funcs o service_role.
-- No creamos policy de INSERT a propósito -> con RLS habilitado y sin policy, no se permite.

-- ============================================================
-- 5) weekly_missions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.weekly_missions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id     uuid NOT NULL REFERENCES public.ranked_seasons(id) ON DELETE CASCADE,
  week_number   smallint NOT NULL,
  key           text NOT NULL,
  title         text NOT NULL,
  description   text,
  target_value  int NOT NULL DEFAULT 1,
  rp_reward     int NOT NULL DEFAULT 50,
  category      text NOT NULL CHECK (category IN ('strength','consistency','community','challenge')),
  difficulty    text NOT NULL CHECK (difficulty IN ('easy','medium','hard')),
  UNIQUE (season_id, week_number, key)
);

ALTER TABLE public.weekly_missions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "weekly_missions: select all" ON public.weekly_missions;
CREATE POLICY "weekly_missions: select all"
  ON public.weekly_missions FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================
-- 6) user_mission_progress
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_mission_progress (
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mission_id      uuid NOT NULL REFERENCES public.weekly_missions(id) ON DELETE CASCADE,
  progress_value  int NOT NULL DEFAULT 0,
  completed_at    timestamptz,
  PRIMARY KEY (user_id, mission_id)
);

ALTER TABLE public.user_mission_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_mission_progress: select own" ON public.user_mission_progress;
CREATE POLICY "user_mission_progress: select own"
  ON public.user_mission_progress FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "user_mission_progress: insert own" ON public.user_mission_progress;
CREATE POLICY "user_mission_progress: insert own"
  ON public.user_mission_progress FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "user_mission_progress: update own" ON public.user_mission_progress;
CREATE POLICY "user_mission_progress: update own"
  ON public.user_mission_progress FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 7) routine_impact_stats
-- ============================================================
CREATE TABLE IF NOT EXISTS public.routine_impact_stats (
  routine_id                          uuid PRIMARY KEY REFERENCES public.routines(id) ON DELETE CASCADE,
  total_copies                        int NOT NULL DEFAULT 0,
  total_workouts_completed_via_copy   int NOT NULL DEFAULT 0,
  total_users_tier_upgraded           int NOT NULL DEFAULT 0,
  last_updated                        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.routine_impact_stats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "routine_impact_stats: select all" ON public.routine_impact_stats;
CREATE POLICY "routine_impact_stats: select all"
  ON public.routine_impact_stats FOR SELECT
  TO authenticated
  USING (true);
-- INSERT/UPDATE solo SECURITY DEFINER funcs o service_role -> sin policies.

-- ============================================================
-- 8) season_rewards
-- ============================================================
CREATE TABLE IF NOT EXISTS public.season_rewards (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  season_id       uuid NOT NULL REFERENCES public.ranked_seasons(id) ON DELETE CASCADE,
  final_tier      text,
  final_division  smallint,
  final_rp        int,
  medal_key       text,
  frame_key       text,
  banner_until    timestamptz,
  inmortal_rank   int,
  awarded_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, season_id)
);

ALTER TABLE public.season_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "season_rewards: select all" ON public.season_rewards;
CREATE POLICY "season_rewards: select all"
  ON public.season_rewards FOR SELECT
  TO authenticated
  USING (true);
-- INSERT/UPDATE solo SECURITY DEFINER funcs / service_role.

-- ============================================================
-- 9) Funciones de scoring (stubs con lógica básica + TODO refinar)
-- ============================================================

-- 9.a Strength score: suma de (e1rm / bodyweight * 100) por PR del user.
-- TODO(ranked-fase-2): refinar por movement_pattern (mejor PR por patrón),
-- aplicar coeficiente de género (1.0 hombre, 1.35 mujer) y curva de saturación.
CREATE OR REPLACE FUNCTION public.calculate_strength_score(p_user_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_score int;
BEGIN
  SELECT COALESCE(SUM((best_e1rm_kg / NULLIF(bodyweight_at_pr_kg, 0)) * 100)::int, 0)
    INTO v_score
    FROM public.user_strength_records
   WHERE user_id = p_user_id
     AND best_e1rm_kg IS NOT NULL
     AND bodyweight_at_pr_kg IS NOT NULL;
  RETURN COALESCE(v_score, 0);
END;
$$;

-- 9.b Consistency score: workouts en últimos 28 días * 15 + bonus racha.
-- TODO(ranked-fase-2): añadir bonus por racha real (días consecutivos).
CREATE OR REPLACE FUNCTION public.calculate_consistency_score(p_user_id uuid, p_since timestamptz)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_score int;
BEGIN
  SELECT COALESCE(COUNT(*) * 15, 0)::int
    INTO v_score
    FROM public.workout_logs
   WHERE user_id = p_user_id
     AND logged_at >= p_since::date;
  RETURN COALESCE(v_score, 0);
END;
$$;

-- 9.c Community score: copias recibidas en la temporada * 50 + completions vía copy * 10.
-- TODO(ranked-fase-2): filtrar por season (usando copied_at vs season window).
CREATE OR REPLACE FUNCTION public.calculate_community_score(p_user_id uuid, p_season_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_copies int := 0;
  v_completions int := 0;
  v_season_start date;
BEGIN
  SELECT start_date INTO v_season_start
    FROM public.ranked_seasons
   WHERE id = p_season_id;

  IF v_season_start IS NULL THEN
    v_season_start := current_date - interval '90 days';
  END IF;

  -- copias recibidas: routine_copies de rutinas cuyo dueño es p_user_id
  SELECT COALESCE(COUNT(*), 0)::int
    INTO v_copies
    FROM public.routine_copies rc
    JOIN public.routines r ON r.id = rc.routine_id
   WHERE r.user_id = p_user_id
     AND rc.copied_at >= v_season_start;

  -- completions vía copy
  SELECT COALESCE(SUM(total_workouts_completed_via_copy), 0)::int
    INTO v_completions
    FROM public.routine_impact_stats ris
    JOIN public.routines r ON r.id = ris.routine_id
   WHERE r.user_id = p_user_id;

  RETURN (v_copies * 50) + (v_completions * 10);
END;
$$;

-- 9.d Recalcular el rango completo del usuario.
-- TODO(ranked-fase-2): challenge_score real desde user_mission_progress.
CREATE OR REPLACE FUNCTION public.recalculate_user_rank(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_season_id      uuid;
  v_strength       int := 0;
  v_consistency    int := 0;
  v_community      int := 0;
  v_challenge      int := 0;
  v_rp             int := 0;
  v_tier           text := 'hierro';
  v_division       smallint := 3;
  v_tier_lo        int := 0;
  v_tier_hi        int := 400;
  v_tier_range     int := 400;
BEGIN
  SELECT id INTO v_season_id
    FROM public.ranked_seasons
   WHERE is_active = true
   ORDER BY start_date DESC
   LIMIT 1;

  v_strength    := public.calculate_strength_score(p_user_id);
  v_consistency := public.calculate_consistency_score(p_user_id, (now() - interval '28 days'));
  v_community   := public.calculate_community_score(p_user_id, v_season_id);
  -- challenge_score: TODO. Por ahora 0 o suma simple de misiones completadas * rp_reward.
  SELECT COALESCE(SUM(m.rp_reward), 0)::int
    INTO v_challenge
    FROM public.user_mission_progress ump
    JOIN public.weekly_missions m ON m.id = ump.mission_id
   WHERE ump.user_id = p_user_id
     AND ump.completed_at IS NOT NULL;

  v_rp := ROUND(v_strength * 0.4 + v_consistency * 0.35 + v_community * 0.15 + v_challenge * 0.10)::int;

  -- Umbrales por tier (RP)
  -- hierro 0-400, bronce 400-1000, plata 1000-1800, oro 1800-2800,
  -- platino 2800-4000, diamante 4000-6000, inmortal 6000+.
  IF v_rp >= 6000 THEN
    v_tier := 'inmortal'; v_tier_lo := 6000; v_tier_hi := 6000; v_division := NULL;
  ELSIF v_rp >= 4000 THEN
    v_tier := 'diamante'; v_tier_lo := 4000; v_tier_hi := 6000;
  ELSIF v_rp >= 2800 THEN
    v_tier := 'platino'; v_tier_lo := 2800; v_tier_hi := 4000;
  ELSIF v_rp >= 1800 THEN
    v_tier := 'oro'; v_tier_lo := 1800; v_tier_hi := 2800;
  ELSIF v_rp >= 1000 THEN
    v_tier := 'plata'; v_tier_lo := 1000; v_tier_hi := 1800;
  ELSIF v_rp >= 400 THEN
    v_tier := 'bronce'; v_tier_lo := 400; v_tier_hi := 1000;
  ELSE
    v_tier := 'hierro'; v_tier_lo := 0; v_tier_hi := 400;
  END IF;

  -- Divisiones III/II/I (3=III pisos bajos, 1=I tope), salvo inmortal (NULL).
  IF v_tier = 'inmortal' THEN
    v_division := NULL;
  ELSE
    v_tier_range := GREATEST(v_tier_hi - v_tier_lo, 1);
    -- Tercio inferior -> III (3), medio -> II (2), superior -> I (1).
    IF (v_rp - v_tier_lo) >= (v_tier_range * 2 / 3) THEN
      v_division := 1;
    ELSIF (v_rp - v_tier_lo) >= (v_tier_range / 3) THEN
      v_division := 2;
    ELSE
      v_division := 3;
    END IF;
  END IF;

  INSERT INTO public.user_ranked_profile (
    user_id, current_season_id, current_tier, current_division,
    current_rp, strength_score, consistency_score, community_score, challenge_score,
    last_recalc_at, last_activity_at, updated_at
  ) VALUES (
    p_user_id, v_season_id, v_tier, v_division,
    v_rp, v_strength, v_consistency, v_community, v_challenge,
    now(), now(), now()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET current_season_id  = EXCLUDED.current_season_id,
        current_tier       = EXCLUDED.current_tier,
        current_division   = EXCLUDED.current_division,
        current_rp         = EXCLUDED.current_rp,
        strength_score     = EXCLUDED.strength_score,
        consistency_score  = EXCLUDED.consistency_score,
        community_score    = EXCLUDED.community_score,
        challenge_score    = EXCLUDED.challenge_score,
        last_recalc_at     = now(),
        last_activity_at   = now(),
        updated_at         = now();
END;
$$;

-- Permitir que el cliente autenticado invoque recalculate_user_rank para SÍ MISMO.
-- Las funciones SECURITY DEFINER ya pueden insertar en tablas restringidas.
REVOKE ALL ON FUNCTION public.recalculate_user_rank(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.recalculate_user_rank(uuid) TO authenticated;

-- ============================================================
-- 10) Trigger AFTER INSERT en workout_logs
--   - recalcula ranked profile del usuario
--   - si la rutina ejecutada tiene source_routine_id, premia al creador original
--   Envuelto en EXCEPTION para no romper inserts en workout_logs si algo falla.
-- ============================================================
CREATE OR REPLACE FUNCTION public.on_workout_log_ranked()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_source_routine uuid;
  v_original_owner uuid;
  v_season_id      uuid;
BEGIN
  BEGIN
    -- 1) recalcular rango del user que entrenó
    PERFORM public.recalculate_user_rank(NEW.user_id);

    -- 2) si la rutina ejecutada es copia, premiar al creador original
    IF NEW.routine_id IS NOT NULL THEN
      SELECT source_routine_id INTO v_source_routine
        FROM public.routines
       WHERE id = NEW.routine_id;

      IF v_source_routine IS NOT NULL THEN
        SELECT user_id INTO v_original_owner
          FROM public.routines
         WHERE id = v_source_routine;

        IF v_original_owner IS NOT NULL AND v_original_owner <> NEW.user_id THEN
          -- bump impact stats
          INSERT INTO public.routine_impact_stats (routine_id, total_workouts_completed_via_copy, last_updated)
          VALUES (v_source_routine, 1, now())
          ON CONFLICT (routine_id) DO UPDATE
            SET total_workouts_completed_via_copy = public.routine_impact_stats.total_workouts_completed_via_copy + 1,
                last_updated = now();

          -- registrar transaccion RP para el creador original
          SELECT id INTO v_season_id
            FROM public.ranked_seasons
           WHERE is_active = true
           ORDER BY start_date DESC
           LIMIT 1;

          INSERT INTO public.rp_transactions (user_id, season_id, delta, source, source_ref_id)
          VALUES (v_original_owner, v_season_id, 10, 'completion_by_other', v_source_routine);
        END IF;
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    -- No bloquear el insert original si ranked falla.
    NULL;
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_workout_log_ranked ON public.workout_logs;
CREATE TRIGGER trg_on_workout_log_ranked
AFTER INSERT ON public.workout_logs
FOR EACH ROW
EXECUTE FUNCTION public.on_workout_log_ranked();

-- ============================================================
-- 11) Seed: misiones semana 1 de Génesis
-- ============================================================
INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
SELECT s.id, 1, 'w1_three_workouts', 'Enciende la chispa', 'Completa 3 entrenamientos esta semana.', 3, 60, 'consistency', 'easy'
  FROM public.ranked_seasons s
 WHERE s.slug = 'genesis'
ON CONFLICT (season_id, week_number, key) DO NOTHING;

INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
SELECT s.id, 1, 'w1_first_pr', 'Marca tu primer PR', 'Registra al menos 1 récord personal de fuerza.', 1, 80, 'strength', 'medium'
  FROM public.ranked_seasons s
 WHERE s.slug = 'genesis'
ON CONFLICT (season_id, week_number, key) DO NOTHING;

INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
SELECT s.id, 1, 'w1_share_routine', 'Inspira a la tribu', 'Publica una rutina pública para que la copien.', 1, 70, 'community', 'medium'
  FROM public.ranked_seasons s
 WHERE s.slug = 'genesis'
ON CONFLICT (season_id, week_number, key) DO NOTHING;

INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
SELECT s.id, 1, 'w1_streak_5', 'Llama constante', 'Mantén una racha de 5 días activos.', 5, 90, 'consistency', 'medium'
  FROM public.ranked_seasons s
 WHERE s.slug = 'genesis'
ON CONFLICT (season_id, week_number, key) DO NOTHING;

INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
SELECT s.id, 1, 'w1_copy_received', 'Tu huella vale', 'Consigue que 1 persona copie una rutina tuya.', 1, 100, 'community', 'hard'
  FROM public.ranked_seasons s
 WHERE s.slug = 'genesis'
ON CONFLICT (season_id, week_number, key) DO NOTHING;

INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
SELECT s.id, 1, 'w1_challenge_pr2', 'Doble desafío', 'Registra 2 PRs en distintos patrones de movimiento.', 2, 120, 'challenge', 'hard'
  FROM public.ranked_seasons s
 WHERE s.slug = 'genesis'
ON CONFLICT (season_id, week_number, key) DO NOTHING;
