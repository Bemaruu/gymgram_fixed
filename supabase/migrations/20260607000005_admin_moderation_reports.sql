-- ============================================================
-- MODERACIÓN: RPCs admin para revisar y resolver reportes
-- (auditoría 2026-06-07). Mismo gate que get_usage_stats:
-- auth.uid() debe coincidir con current_setting('app.admin_uid').
--
-- Para habilitar el panel (una sola vez, por humano):
--   ALTER DATABASE postgres SET app.admin_uid = '<UID_DEL_ADMIN>';
-- y compilar la app con --dart-define=ADMIN_UID=<UID_DEL_ADMIN>.
-- ============================================================

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
  v_admin  text;
  v_result json;
BEGIN
  v_admin := current_setting('app.admin_uid', true);
  IF v_admin IS NULL OR v_admin = '' OR auth.uid()::text <> v_admin THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  IF p_status NOT IN ('pending', 'reviewed', 'dismissed', 'all') THEN
    p_status := 'pending';
  END IF;

  SELECT coalesce(json_agg(row_to_json(t)), '[]'::json) INTO v_result
  FROM (
    SELECT
      r.id,
      r.status,
      r.reason,
      r.created_at,
      r.reporter_id,
      rp.username AS reporter_username,
      r.target_user_id,
      tp.username AS target_username,
      r.target_message_id,
      m.text       AS message_text,
      m.is_deleted AS message_deleted
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

GRANT EXECUTE ON FUNCTION public.admin_list_reports(text, int) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_list_reports(text, int) FROM anon, public;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id uuid,
  p_action    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin text;
BEGIN
  v_admin := current_setting('app.admin_uid', true);
  IF v_admin IS NULL OR v_admin = '' OR auth.uid()::text <> v_admin THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  IF p_action NOT IN ('reviewed', 'dismissed') THEN
    RAISE EXCEPTION 'Invalid action';
  END IF;

  UPDATE public.reports SET status = p_action WHERE id = p_report_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text) FROM anon, public;
