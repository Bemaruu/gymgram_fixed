-- ============================================================
-- HARDENING: cerrar EXECUTE de helpers internos de Ranked/Match
-- (auditoría 2026-06-07)
--
-- Estos helpers solo deben invocarse desde otras funciones SECURITY DEFINER
-- (recalculate_user_rank → calculate_*; RPCs de match → _match_*). Esas
-- funciones corren como su owner, así que conservan EXECUTE y NO se rompen.
-- El cliente Flutter nunca los llama directo (solo llama recalculate_user_rank
-- y award_badge/update_badge_progress, que mantienen sus checks de auth.uid()).
--
-- _match_apply_rp además no tenía ningún check de auth y quedaba expuesto a
-- anon/authenticated vía /rest/v1/rpc/_match_apply_rp.
-- ============================================================

REVOKE EXECUTE ON FUNCTION public._match_apply_rp(uuid, integer)            FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public._match_bodyweight(uuid)                   FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.calculate_strength_score(uuid)            FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.calculate_consistency_score(uuid, timestamptz) FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.calculate_community_score(uuid, uuid)     FROM anon, authenticated, public;
