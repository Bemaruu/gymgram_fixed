-- ============================================================
-- Hardening de seguridad — resuelve hallazgos de get_advisors (2026-05-24)
-- Solo fixes NO destructivos y verificados contra el flujo de la app.
-- ============================================================

-- 1) ERROR security_definer_view: la vista public.public_profiles corría con los
--    permisos de su creador. Con security_invoker respeta el RLS del usuario que
--    consulta. (Postgres 15+ / Supabase).
ALTER VIEW IF EXISTS public.public_profiles SET (security_invoker = on);

-- 2) rls_policy_always_true: política huérfana "System can insert notifications"
--    (creada vía dashboard, NO rastreada en migraciones) con WITH CHECK (true).
--    Los inserts legítimos van por RPCs SECURITY DEFINER (notify_follow/like/
--    comment) y por service_role (coach_message), que saltan RLS. Eliminarla
--    cierra el bypass sin romper ningún flujo.
DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;

-- 3) materialized_view_in_api: la matview del leaderboard no debe ser visible
--    para usuarios anónimos (la app siempre consulta autenticada).
REVOKE SELECT ON public.ranked_leaderboard_view FROM anon;

-- 4) function_search_path_mutable: fija search_path en las funciones señaladas
--    para evitar secuestro de search_path. Robusto a sobrecargas (usa regprocedure).
DO $$
DECLARE
  fn text;
  sig text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'sync_comments_count',
    'fn_increment_comments',
    'fn_decrement_comments',
    'fn_increment_likes',
    'fn_decrement_likes',
    'handle_updated_at'
  ] LOOP
    FOR sig IN
      SELECT p.oid::regprocedure::text
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = fn
    LOOP
      EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp;', sig);
    END LOOP;
  END LOOP;
END $$;

-- ============================================================
-- PENDIENTE / requiere acción manual (no se automatiza por riesgo):
--  - auth_leaked_password_protection: activar en Dashboard → Auth → Passwords
--    (requiere plan Pro). HaveIBeenPwned check.
--  - extension_in_public (pg_trgm): mover a schema `extensions` puede romper
--    índices/búsquedas dependientes. Migrar con cuidado en ventana de mantención.
--  - public_bucket_allows_listing (avatars, posts): revisar políticas SELECT de
--    storage.objects para no permitir listar todo el bucket. No se toca aquí
--    porque podría romper la carga de media del feed; validar en staging.
--  - *_security_definer_function_executable: las RPCs SECURITY DEFINER tienen
--    guard interno auth.uid(); es by-design. Revisar caso a caso si alguna no
--    debería ser callable por anon (REVOKE EXECUTE ... FROM anon).
-- ============================================================
