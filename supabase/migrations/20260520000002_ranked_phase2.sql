-- ============================================================
-- Ranked GOD MODE - Fase 2
-- Refina scoring, agrega close_season/start_next_season,
-- materialized view de leaderboard, mas misiones de Genesis.
-- Idempotente. NO destruye datos. NO toca esquema fuera de lo necesario.
-- ============================================================

-- ============================================================
-- 0) Defensive: workout_logs si no existe ya
-- ============================================================
CREATE TABLE IF NOT EXISTS public.workout_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  routine_id  uuid REFERENCES public.routines(id) ON DELETE SET NULL,
  logged_at   date NOT NULL DEFAULT current_date,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_workout_logs_user_date
  ON public.workout_logs(user_id, logged_at DESC);

ALTER TABLE public.workout_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "workout_logs: select own" ON public.workout_logs;
CREATE POLICY "workout_logs: select own"
  ON public.workout_logs FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "workout_logs: insert own" ON public.workout_logs;
CREATE POLICY "workout_logs: insert own"
  ON public.workout_logs FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 0.b) Defensive: profiles.gender y profiles.weight_kg
-- ============================================================
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS gender    text,
  ADD COLUMN IF NOT EXISTS weight_kg numeric(5,2);

-- ============================================================
-- 1) Refinar calculate_strength_score
--    - Mejor e1rm por movement_pattern (1 por patron)
--    - Divide por bodyweight del PR (o profiles.weight_kg fallback)
--    - Coeficiente de genero: hombre=1.0, mujer/no-binario=1.35, default=1.0
--    - Sin PRs -> 0
-- ============================================================
CREATE OR REPLACE FUNCTION public.calculate_strength_score(p_user_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender_coef numeric := 1.0;
  v_gender      text;
  v_score       numeric := 0;
BEGIN
  SELECT lower(coalesce(gender, '')) INTO v_gender
    FROM public.profiles WHERE id = p_user_id;

  IF v_gender IN ('female', 'mujer', 'f', 'nonbinary', 'no_binario', 'non_binary', 'nb', 'other') THEN
    v_gender_coef := 1.35;
  ELSE
    v_gender_coef := 1.0;
  END IF;

  -- Para cada movement_pattern del usuario tomamos el mejor e1rm/bodyweight
  WITH best_per_pattern AS (
    SELECT
      movement_pattern,
      MAX(
        (best_e1rm_kg /
          NULLIF(COALESCE(bodyweight_at_pr_kg,
                          (SELECT weight_kg FROM public.profiles WHERE id = p_user_id)
                         ), 0)
        ) * 100
      ) AS ratio
    FROM public.user_strength_records
    WHERE user_id = p_user_id
      AND best_e1rm_kg IS NOT NULL
    GROUP BY movement_pattern
  )
  SELECT COALESCE(SUM(ratio), 0) INTO v_score FROM best_per_pattern;

  RETURN COALESCE(ROUND(v_score * v_gender_coef)::int, 0);
END;
$$;

-- ============================================================
-- 2) recalculate_user_rank con validacion de auth.uid()
-- ============================================================
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
  -- Solo el propio user o service_role puede recalcular su rango
  IF p_user_id IS DISTINCT FROM auth.uid()
     AND COALESCE(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'no autorizado';
  END IF;

  SELECT id INTO v_season_id
    FROM public.ranked_seasons
   WHERE is_active = true
   ORDER BY start_date DESC
   LIMIT 1;

  v_strength    := public.calculate_strength_score(p_user_id);
  v_consistency := public.calculate_consistency_score(p_user_id, (now() - interval '28 days'));
  v_community   := public.calculate_community_score(p_user_id, v_season_id);

  SELECT COALESCE(SUM(m.rp_reward), 0)::int
    INTO v_challenge
    FROM public.user_mission_progress ump
    JOIN public.weekly_missions m ON m.id = ump.mission_id
   WHERE ump.user_id = p_user_id
     AND ump.completed_at IS NOT NULL;

  v_rp := ROUND(v_strength * 0.4 + v_consistency * 0.35 + v_community * 0.15 + v_challenge * 0.10)::int;

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

  IF v_tier = 'inmortal' THEN
    v_division := NULL;
  ELSE
    v_tier_range := GREATEST(v_tier_hi - v_tier_lo, 1);
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

REVOKE ALL ON FUNCTION public.recalculate_user_rank(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.recalculate_user_rank(uuid) TO authenticated;

-- ============================================================
-- 3) close_season(p_season_id) - SECURITY DEFINER, service_role o admin
-- ============================================================
CREATE OR REPLACE FUNCTION public.close_season(p_season_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role        text;
  v_is_admin    boolean := false;
  v_season_slug text;
  r             record;
  v_new_tier    text;
  v_new_div     smallint;
  v_post_cap    int := 1800; -- tope post-reset: tope superior de oro III (~1800)
  v_post_rp     int;
  v_rank_idx    int := 0;
BEGIN
  v_role := COALESCE(auth.role(), '');
  -- Admin check defensivo: profiles.is_admin si existe
  BEGIN
    EXECUTE 'SELECT COALESCE(is_admin, false) FROM public.profiles WHERE id = $1'
       INTO v_is_admin USING auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_is_admin := false;
  END;

  IF v_role <> 'service_role' AND NOT v_is_admin THEN
    RAISE EXCEPTION 'no autorizado';
  END IF;

  SELECT slug INTO v_season_slug FROM public.ranked_seasons WHERE id = p_season_id;
  IF v_season_slug IS NULL THEN
    RAISE EXCEPTION 'season no existe';
  END IF;

  -- Iterar usuarios con perfil ranked en esta temporada, ordenados por RP desc
  FOR r IN
    SELECT urp.user_id, urp.current_tier, urp.current_division, urp.current_rp,
           urp.peak_history
      FROM public.user_ranked_profile urp
     WHERE urp.current_season_id = p_season_id
     ORDER BY urp.current_rp DESC
  LOOP
    v_rank_idx := v_rank_idx + 1;

    -- Premio: registrar season_rewards
    INSERT INTO public.season_rewards (
      user_id, season_id, final_tier, final_division, final_rp,
      medal_key, frame_key, banner_until, inmortal_rank, awarded_at
    ) VALUES (
      r.user_id,
      p_season_id,
      r.current_tier,
      r.current_division,
      r.current_rp,
      'season_' || v_season_slug || '_tier_' || r.current_tier,
      'frame_' || v_season_slug || '_' || r.current_tier,
      (current_date + interval '14 days'),
      CASE WHEN r.current_tier = 'inmortal' AND v_rank_idx <= 500 THEN v_rank_idx ELSE NULL END,
      now()
    )
    ON CONFLICT (user_id, season_id) DO UPDATE SET
      final_tier     = EXCLUDED.final_tier,
      final_division = EXCLUDED.final_division,
      final_rp       = EXCLUDED.final_rp,
      medal_key      = EXCLUDED.medal_key,
      frame_key      = EXCLUDED.frame_key,
      banner_until   = EXCLUDED.banner_until,
      inmortal_rank  = EXCLUDED.inmortal_rank;

    -- Push a peak_history en user_ranked_profile
    UPDATE public.user_ranked_profile
       SET peak_history = COALESCE(peak_history, '[]'::jsonb) || jsonb_build_array(
             jsonb_build_object(
               'season_id', p_season_id,
               'season_slug', v_season_slug,
               'tier', r.current_tier,
               'division', r.current_division,
               'rp', r.current_rp,
               'closed_at', now()
             )
           )
     WHERE user_id = r.user_id;

    -- Soft reset: bajar 1 tier completo. hierro queda en hierro III.
    -- Tope post-reset: oro I (~1800 RP).
    v_new_tier := CASE r.current_tier
      WHEN 'inmortal' THEN 'diamante'
      WHEN 'diamante' THEN 'platino'
      WHEN 'platino'  THEN 'oro'
      WHEN 'oro'      THEN 'plata'
      WHEN 'plata'    THEN 'bronce'
      WHEN 'bronce'   THEN 'hierro'
      ELSE 'hierro'
    END;

    -- RP correspondiente al piso del nuevo tier
    v_post_rp := CASE v_new_tier
      WHEN 'diamante' THEN 4000
      WHEN 'platino'  THEN 2800
      WHEN 'oro'      THEN 1800
      WHEN 'plata'    THEN 1000
      WHEN 'bronce'   THEN 400
      ELSE 0
    END;

    -- Aplicar tope post-reset (no se permite arrancar arriba de oro I)
    IF v_post_rp > v_post_cap THEN
      v_new_tier := 'oro';
      v_post_rp  := v_post_cap;
    END IF;

    -- Division post-reset (III por defecto, salvo inmortal->NULL nunca pasa aqui)
    v_new_div := 3;

    -- Reset scores: consistency, community, challenge a 0. Strength se conserva.
    UPDATE public.user_ranked_profile
       SET current_tier      = v_new_tier,
           current_division  = v_new_div,
           current_rp        = v_post_rp,
           consistency_score = 0,
           community_score   = 0,
           challenge_score   = 0,
           current_season_id = NULL,
           updated_at        = now()
     WHERE user_id = r.user_id;
  END LOOP;

  -- Cerrar la temporada
  UPDATE public.ranked_seasons
     SET is_active = false
   WHERE id = p_season_id;
END;
$$;

REVOKE ALL ON FUNCTION public.close_season(uuid) FROM public;
-- No GRANT a authenticated: solo service_role/admin.

-- ============================================================
-- 4) start_next_season(p_name, p_slug, p_theme) -> uuid
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

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.start_next_season(text, text, text) FROM public;

-- ============================================================
-- 5) Materialized view: ranked_leaderboard_view
-- ============================================================
DROP MATERIALIZED VIEW IF EXISTS public.ranked_leaderboard_view;

CREATE MATERIALIZED VIEW public.ranked_leaderboard_view AS
SELECT
  urp.user_id,
  p.username,
  p.avatar_url,
  urp.current_tier,
  urp.current_division,
  urp.current_rp,
  ROW_NUMBER() OVER (ORDER BY urp.current_rp DESC) AS global_rank,
  s.id AS season_id
FROM public.user_ranked_profile urp
JOIN public.profiles p ON p.id = urp.user_id
JOIN public.ranked_seasons s ON s.id = urp.current_season_id AND s.is_active = true
WHERE urp.current_rp > 0;

CREATE UNIQUE INDEX IF NOT EXISTS idx_leaderboard_user ON public.ranked_leaderboard_view(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboard_rank ON public.ranked_leaderboard_view(global_rank);

GRANT SELECT ON public.ranked_leaderboard_view TO authenticated;

CREATE OR REPLACE FUNCTION public.refresh_ranked_leaderboard()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.ranked_leaderboard_view;
EXCEPTION WHEN OTHERS THEN
  -- Fallback no-concurrent si no hay datos suficientes para CONCURRENT.
  REFRESH MATERIALIZED VIEW public.ranked_leaderboard_view;
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_ranked_leaderboard() FROM public;
GRANT EXECUTE ON FUNCTION public.refresh_ranked_leaderboard() TO authenticated;

-- ============================================================
-- 6) Misiones semanas 2 a 12 de Genesis
--    Mezcla balanceada de strength/consistency/community/challenge.
-- ============================================================
DO $$
DECLARE
  v_season_id uuid;
  w int;
BEGIN
  SELECT id INTO v_season_id FROM public.ranked_seasons WHERE slug = 'genesis' LIMIT 1;
  IF v_season_id IS NULL THEN RETURN; END IF;

  FOR w IN 2..12 LOOP
    -- consistency: entrenar X veces
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (v_season_id, w, 'w' || w || '_workouts',
            'Acumula fuerza',
            'Completa ' || (3 + (w % 3)) || ' entrenamientos esta semana.',
            (3 + (w % 3)), 60 + (w * 5), 'consistency', 'easy')
    ON CONFLICT (season_id, week_number, key) DO NOTHING;

    -- strength: PR
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (v_season_id, w, 'w' || w || '_pr',
            'Rompe el techo',
            'Registra al menos 1 PR de fuerza esta semana.',
            1, 80 + (w * 4), 'strength',
            CASE WHEN w < 6 THEN 'medium' ELSE 'hard' END)
    ON CONFLICT (season_id, week_number, key) DO NOTHING;

    -- community: copia recibida o rutina publicada
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (v_season_id, w, 'w' || w || '_community',
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

    -- challenge: multi-PR / racha
    INSERT INTO public.weekly_missions (season_id, week_number, key, title, description, target_value, rp_reward, category, difficulty)
    VALUES (v_season_id, w, 'w' || w || '_challenge',
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
END $$;
