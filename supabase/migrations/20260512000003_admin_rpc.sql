-- RPC get_usage_stats: solo accesible por el UID configurado como admin.
-- El UID de admin se pasa como setting de app en Supabase Dashboard:
--   Dashboard > Settings > Config > app.admin_uid = '<uuid>'
-- El cliente adicionalmente valida el UID con ADMIN_UID build arg (doble capa).

CREATE OR REPLACE FUNCTION public.get_usage_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_uid text;
  v_db_bytes   bigint;
  v_db_limit   bigint  := 500 * 1024 * 1024;   -- 500 MB free plan
  v_st_bytes   bigint;
  v_st_limit   bigint  := 1 * 1024 * 1024 * 1024; -- 1 GB free plan
BEGIN
  -- Validacion server-side: solo el admin configurado puede llamar esta funcion
  v_admin_uid := current_setting('app.admin_uid', true);
  IF v_admin_uid IS NULL OR v_admin_uid = '' OR auth.uid()::text <> v_admin_uid THEN
    RAISE EXCEPTION 'Forbidden';
  END IF;

  -- Tamaño de la base de datos (aproximado via pg_database_size)
  SELECT pg_database_size(current_database()) INTO v_db_bytes;

  -- Tamaño de storage (suma de objetos en los buckets de Supabase)
  SELECT COALESCE(SUM(metadata->>'size')::bigint, 0)
  INTO v_st_bytes
  FROM storage.objects;

  RETURN json_build_object(
    'db_bytes',          v_db_bytes,
    'db_limit_bytes',    v_db_limit,
    'db_pct',            round((v_db_bytes::numeric / v_db_limit) * 100, 2),
    'storage_bytes',     v_st_bytes,
    'storage_limit_bytes', v_st_limit,
    'storage_pct',       round((v_st_bytes::numeric / v_st_limit) * 100, 2),
    'profiles',          (SELECT COUNT(*) FROM public.profiles),
    'posts',             (SELECT COUNT(*) FROM public.posts),
    'chats',             (SELECT COUNT(*) FROM public.chats),
    'messages',          (SELECT COUNT(*) FROM public.messages),
    'messages_30d',      (SELECT COUNT(*) FROM public.messages WHERE created_at > now() - interval '30 days'),
    'generated_at',      now()
  );
END;
$$;
