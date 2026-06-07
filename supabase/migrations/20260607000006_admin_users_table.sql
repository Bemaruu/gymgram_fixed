-- ============================================================
-- Admin gating robusto vía tabla (reemplaza el GUC app.admin_uid, que no se
-- podía setear con el rol disponible → estaba vacío y rechazaba a todos).
-- Tabla admin_users + helper is_app_admin(). Se actualizan las 3 funciones
-- admin (get_usage_stats, admin_list_reports, admin_resolve_report) para usarlo.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS sin policies: ninguna sesión cliente puede leer/escribir la tabla.
-- Solo las funciones SECURITY DEFINER (owner postgres) la consultan.
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.admin_users FROM anon, authenticated;

-- Admin inicial (UID del dueño).
INSERT INTO public.admin_users (user_id)
VALUES ('5789cab1-8c57-4971-8986-00237bc663e2')
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.is_app_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (SELECT 1 FROM public.admin_users WHERE user_id = auth.uid())
$$;

REVOKE EXECUTE ON FUNCTION public.is_app_admin() FROM anon, public;
GRANT  EXECUTE ON FUNCTION public.is_app_admin() TO authenticated;

-- ── Re-gate de las funciones admin ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.admin_list_reports(
  p_status text DEFAULT 'pending',
  p_limit  int  DEFAULT 100
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  IF p_status NOT IN ('pending', 'reviewed', 'dismissed', 'all') THEN
    p_status := 'pending';
  END IF;

  SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) INTO v_result
  FROM (
    SELECT
      r.id, r.status, r.reason, r.created_at,
      r.reporter_id, rp.username AS reporter_username,
      r.target_user_id, tp.username AS target_username,
      r.target_message_id, m.text AS message_text, m.is_deleted AS message_deleted
    FROM public.reports r
    LEFT JOIN public.profiles rp ON rp.id = r.reporter_id
    LEFT JOIN public.profiles tp ON tp.id = r.target_user_id
    LEFT JOIN public.messages  m ON m.id  = r.target_message_id
    WHERE (p_status = 'all' OR r.status = p_status)
    ORDER BY r.created_at DESC
    LIMIT greatest(1, least(p_limit, 500))
  ) t;

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id uuid,
  p_action    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;
  IF p_action NOT IN ('reviewed', 'dismissed') THEN
    RAISE EXCEPTION 'Invalid action';
  END IF;
  UPDATE public.reports SET status = p_action WHERE id = p_report_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_usage_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_db_bytes bigint;
  v_db_limit bigint := 500 * 1024 * 1024;
  v_st_bytes bigint;
  v_st_limit bigint := 1 * 1024 * 1024 * 1024;
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  SELECT pg_database_size(current_database()) INTO v_db_bytes;

  SELECT COALESCE(SUM((metadata->>'size')::bigint), 0)
    INTO v_st_bytes FROM storage.objects;

  RETURN json_build_object(
    'db_bytes',            v_db_bytes,
    'db_limit_bytes',      v_db_limit,
    'db_pct',              round((v_db_bytes::numeric / v_db_limit) * 100, 2),
    'storage_bytes',       v_st_bytes,
    'storage_limit_bytes', v_st_limit,
    'storage_pct',         round((v_st_bytes::numeric / v_st_limit) * 100, 2),
    'profiles',            (SELECT COUNT(*) FROM public.profiles),
    'posts',               (SELECT COUNT(*) FROM public.posts),
    'chats',               (SELECT COUNT(*) FROM public.chats),
    'messages',            (SELECT COUNT(*) FROM public.messages),
    'messages_30d',        (SELECT COUNT(*) FROM public.messages WHERE created_at > now() - interval '30 days'),
    'generated_at',        now()
  );
END;
$$;
