-- Fix crítico: _match_apply_rp llamaba recalculate_user_rank(rival_uid) y fallaba
-- con 'no autorizado' porque la función exige p_user_id = auth.uid().
-- Resultado: las partidas nunca terminaban (rollback) — "algo salió mal" cuando
-- alguien estaba por ganar, ni siquiera permitía abandonar (forfeit_match igual).
--
-- Solución: añadir bypass mediante session var local a la transacción. Solo
-- las RPC SECURITY DEFINER del match (que ya validan participación) la activan.

-- 1) Actualizar recalculate_user_rank para respetar el bypass.
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
  IF p_user_id IS DISTINCT FROM auth.uid()
     AND COALESCE(auth.role(), '') <> 'service_role'
     AND COALESCE(current_setting('gymgram.allow_recalc_any', true), '') <> 'yes' THEN
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
         last_recalc_at     = EXCLUDED.last_recalc_at,
         last_activity_at   = EXCLUDED.last_activity_at,
         updated_at         = EXCLUDED.updated_at;
END;
$$;

-- 2) Actualizar _match_apply_rp para activar el bypass local antes de recalcular.
CREATE OR REPLACE FUNCTION public._match_apply_rp(p_user_id uuid, p_delta int)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_ranked_profile (user_id, challenge_score)
  VALUES (p_user_id, GREATEST(0, p_delta))
  ON CONFLICT (user_id) DO UPDATE
    SET challenge_score = GREATEST(0, COALESCE(user_ranked_profile.challenge_score, 0) + p_delta);

  PERFORM set_config('gymgram.allow_recalc_any', 'yes', true);
  PERFORM recalculate_user_rank(p_user_id);
END;
$$;
