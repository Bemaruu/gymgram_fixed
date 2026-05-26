-- ============================================================
-- *_security_definer_function_executable — endurece EXECUTE de funciones
-- SECURITY DEFINER. (2026-05-24, get_advisors)
--
-- Grupo A: funciones que la app SÍ invoca por RPC (tienen guard auth.uid()
--          interno) → se revoca solo a anon y public, se mantiene authenticated.
-- Grupo B: triggers + funciones admin/cron que NUNCA deben llamarse por API
--          → se revoca a anon, public y authenticated. Los triggers siguen
--          ejecutándose (no dependen de EXECUTE) y el cron corre como postgres.
-- Usa regprocedure para cubrir sobrecargas de firma.
-- ============================================================
DO $$
DECLARE fn text; sig text;
BEGIN
  -- Grupo A: revocar anon + public, mantener authenticated
  FOREACH fn IN ARRAY ARRAY[
    'get_ranked_feed','insert_ai_message','recalculate_user_rank',
    'get_user_season_stats','cleanup_old_notifications',
    'calculate_community_score','calculate_consistency_score','calculate_strength_score'
  ] LOOP
    FOR sig IN
      SELECT p.oid::regprocedure::text FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname='public' AND p.proname=fn
    LOOP
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, public;', sig);
    END LOOP;
  END LOOP;

  -- Grupo B: revocar anon + public + authenticated (admin/cron/triggers)
  FOREACH fn IN ARRAY ARRAY[
    'auto_rotate_seasons','close_season','start_next_season',
    'refresh_ranked_leaderboard','seed_season_missions',
    'prevent_subscription_field_changes','set_logs_after_insert',
    'on_workout_log_ranked','trigger_push_on_message',
    'trigger_push_on_notification','bump_recipe_saves_count'
  ] LOOP
    FOR sig IN
      SELECT p.oid::regprocedure::text FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname='public' AND p.proname=fn
    LOOP
      EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, public, authenticated;', sig);
    END LOOP;
  END LOOP;
END $$;
