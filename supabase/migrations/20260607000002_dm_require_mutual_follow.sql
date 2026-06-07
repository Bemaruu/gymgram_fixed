-- ============================================================
-- DM HARDENING 4 (auditoría seguridad mensajería 2026-06-07)
-- Gating anti-acoso: solo se puede abrir/enviar DM entre follow mutuo.
-- Mismo criterio que el modo Match (20260601000002_match_mutual_follow).
-- Se valida tanto al crear/abrir el chat como en cada envío, de modo que
-- si dejan de seguirse, el canal queda inutilizable (no solo bloqueo manual).
-- ============================================================

CREATE OR REPLACE FUNCTION public.find_or_create_chat(p_other_user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me      uuid := auth.uid();
  v_chat_id uuid;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_other_user_id IS NULL OR p_other_user_id = v_me THEN
    RAISE EXCEPTION 'Invalid user';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.blocked_users
    WHERE (blocker_id = v_me AND blocked_id = p_other_user_id)
       OR (blocker_id = p_other_user_id AND blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'Blocked';
  END IF;

  -- Follow mutuo obligatorio (anti-acoso).
  IF NOT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = v_me AND following_id = p_other_user_id
      )
     OR NOT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = p_other_user_id AND following_id = v_me
      ) THEN
    RAISE EXCEPTION 'Not mutual followers';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      least(v_me::text, p_other_user_id::text)
      || '|' ||
      greatest(v_me::text, p_other_user_id::text), 0
    )
  );

  SELECT c.id INTO v_chat_id
  FROM public.chats c
  WHERE EXISTS (
          SELECT 1 FROM public.chat_participants cp
          WHERE cp.chat_id = c.id AND cp.user_id = v_me
        )
    AND EXISTS (
          SELECT 1 FROM public.chat_participants cp
          WHERE cp.chat_id = c.id AND cp.user_id = p_other_user_id
        )
    AND (SELECT count(*) FROM public.chat_participants cp WHERE cp.chat_id = c.id) = 2
  LIMIT 1;

  IF v_chat_id IS NULL THEN
    INSERT INTO public.chats DEFAULT VALUES RETURNING id INTO v_chat_id;
    INSERT INTO public.chat_participants (chat_id, user_id) VALUES
      (v_chat_id, v_me),
      (v_chat_id, p_other_user_id);
  END IF;

  RETURN v_chat_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_message(p_chat_id uuid, p_text text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me       uuid := auth.uid();
  v_receiver uuid;
  v_count    int;
  v_global   int;
  v_msg_id   uuid;
  v_clean    text;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  v_clean := btrim(coalesce(p_text, ''));
  IF length(v_clean) = 0 THEN
    RAISE EXCEPTION 'Empty message';
  END IF;
  IF length(v_clean) > 1000 THEN
    RAISE EXCEPTION 'Message too long';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE chat_id = p_chat_id AND user_id = v_me
  ) THEN
    RAISE EXCEPTION 'Not a participant';
  END IF;

  SELECT user_id INTO v_receiver
  FROM public.chat_participants
  WHERE chat_id = p_chat_id AND user_id <> v_me
  LIMIT 1;
  IF v_receiver IS NULL THEN
    RAISE EXCEPTION 'Receiver not found';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.blocked_users
    WHERE (blocker_id = v_me       AND blocked_id = v_receiver)
       OR (blocker_id = v_receiver AND blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'Blocked';
  END IF;

  -- Follow mutuo obligatorio (anti-acoso): si dejaron de seguirse, no se envía.
  IF NOT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = v_me AND following_id = v_receiver
      )
     OR NOT EXISTS (
        SELECT 1 FROM public.follows
        WHERE follower_id = v_receiver AND following_id = v_me
      ) THEN
    RAISE EXCEPTION 'Not mutual followers';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended('rl:'||v_me::text||':'||p_chat_id::text, 0)
  );

  SELECT count(*) INTO v_count
  FROM public.messages
  WHERE sender_id  = v_me
    AND chat_id    = p_chat_id
    AND created_at > now() - interval '30 seconds';
  IF v_count >= 10 THEN
    RAISE EXCEPTION 'Rate limit';
  END IF;

  SELECT count(*) INTO v_global
  FROM public.messages
  WHERE sender_id  = v_me
    AND created_at > now() - interval '60 seconds';
  IF v_global >= 30 THEN
    RAISE EXCEPTION 'Rate limit (global)';
  END IF;

  INSERT INTO public.messages (chat_id, sender_id, receiver_id, text)
  VALUES (p_chat_id, v_me, v_receiver, v_clean)
  RETURNING id INTO v_msg_id;

  RETURN v_msg_id;
END;
$$;
