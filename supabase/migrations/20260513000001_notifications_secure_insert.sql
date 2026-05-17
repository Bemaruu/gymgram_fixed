-- Cierra el INSERT abierto en notifications y lo reemplaza por RPCs SECURITY DEFINER.
-- Antes: cualquier usuario autenticado podia insertar notificaciones falsas a cualquier otro.
-- Ahora: solo RPCs verificadas pueden insertar, y solo si el evento es real.

DROP POLICY IF EXISTS "notifications: insert system" ON public.notifications;
REVOKE INSERT ON public.notifications FROM authenticated;

-- ── notify_follow ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_follow(p_following_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_following_id = v_me THEN RAISE EXCEPTION 'Invalid'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.follows
    WHERE follower_id = v_me AND following_id = p_following_id
  ) THEN RAISE EXCEPTION 'Follow not found'; END IF;

  INSERT INTO public.notifications (user_id, actor_id, type)
  VALUES (p_following_id, v_me, 'follow')
  ON CONFLICT DO NOTHING;
END;
$$;
GRANT EXECUTE ON FUNCTION public.notify_follow(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_follow(uuid) FROM anon, public;

-- ── notify_like ───────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_like(p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me      uuid := auth.uid();
  v_owner   uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT user_id INTO v_owner FROM public.posts WHERE id = p_post_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'Post not found'; END IF;
  IF v_owner = v_me THEN RETURN; END IF; -- No notificar likes propios

  IF NOT EXISTS (
    SELECT 1 FROM public.likes
    WHERE user_id = v_me AND post_id = p_post_id
  ) THEN RAISE EXCEPTION 'Like not found'; END IF;

  INSERT INTO public.notifications (user_id, actor_id, post_id, type)
  VALUES (v_owner, v_me, p_post_id, 'like')
  ON CONFLICT DO NOTHING;
END;
$$;
GRANT EXECUTE ON FUNCTION public.notify_like(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_like(uuid) FROM anon, public;

-- ── notify_comment ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_comment(p_post_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_owner uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT user_id INTO v_owner FROM public.posts WHERE id = p_post_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'Post not found'; END IF;
  IF v_owner = v_me THEN RETURN; END IF; -- No notificar comentarios propios

  INSERT INTO public.notifications (user_id, actor_id, post_id, type)
  VALUES (v_owner, v_me, p_post_id, 'comment')
  ON CONFLICT DO NOTHING;
END;
$$;
GRANT EXECUTE ON FUNCTION public.notify_comment(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.notify_comment(uuid) FROM anon, public;
