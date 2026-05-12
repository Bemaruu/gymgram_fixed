-- ============================================================
-- DM SECURITY HARDENING (post-audit FortKnox)
-- 1) Advisory lock en find_or_create_chat (anti chats duplicados)
-- 2) Advisory lock + cap global en send_message (rate-limit atómico)
-- 3) reports: CHECK length + dedupe + RPC create_report con rate-limit
-- 4) RLS SELECT extendido con NOT EXISTS blocked_users
-- 5) Column-level UPDATE en chat_participants (solo last_read_at)
-- 6) soft_delete_message recalcula chats.last_message
-- 7) Revocar EXECUTE de fn_after_message_insert (trigger interno)
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- 1) find_or_create_chat con advisory lock
-- ──────────────────────────────────────────────────────────────
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

-- ──────────────────────────────────────────────────────────────
-- 2) send_message con advisory lock + cap global por sender
-- ──────────────────────────────────────────────────────────────
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

-- ──────────────────────────────────────────────────────────────
-- 3) reports: CHECK length, dedupe parcial, RPC con rate-limit
-- ──────────────────────────────────────────────────────────────
DO $$ BEGIN
  ALTER TABLE public.reports
    ADD CONSTRAINT reports_reason_len CHECK (char_length(reason) BETWEEN 1 AND 1000);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_reports_dedupe
  ON public.reports (
    reporter_id,
    target_user_id,
    coalesce(target_message_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  WHERE status = 'pending';

DROP POLICY IF EXISTS "reports: insert own" ON public.reports;

CREATE OR REPLACE FUNCTION public.create_report(
  p_target_user_id   uuid,
  p_target_message_id uuid,
  p_reason           text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me    uuid := auth.uid();
  v_count int;
  v_id    uuid;
  v_clean text;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_target_user_id IS NULL OR p_target_user_id = v_me THEN
    RAISE EXCEPTION 'Invalid target';
  END IF;
  v_clean := btrim(coalesce(p_reason, ''));
  IF length(v_clean) = 0 THEN
    RAISE EXCEPTION 'Empty reason';
  END IF;
  IF length(v_clean) > 1000 THEN
    RAISE EXCEPTION 'Reason too long';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('rep:'||v_me::text, 0));

  SELECT count(*) INTO v_count
  FROM public.reports
  WHERE reporter_id = v_me
    AND created_at  > now() - interval '1 hour';
  IF v_count >= 5 THEN
    RAISE EXCEPTION 'Rate limit';
  END IF;

  INSERT INTO public.reports (reporter_id, target_user_id, target_message_id, reason)
  VALUES (v_me, p_target_user_id, p_target_message_id, v_clean)
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_id;

  -- Dedupe: si ya existia un reporte pending, devolver su id (H1).
  IF v_id IS NULL THEN
    SELECT id INTO v_id FROM public.reports
     WHERE reporter_id = v_me
       AND target_user_id = p_target_user_id
       AND coalesce(target_message_id, '00000000-0000-0000-0000-000000000000'::uuid)
         = coalesce(p_target_message_id, '00000000-0000-0000-0000-000000000000'::uuid)
       AND status = 'pending'
     LIMIT 1;
  END IF;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_report(uuid, uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.create_report(uuid, uuid, text) FROM anon, public;

-- ──────────────────────────────────────────────────────────────
-- 4) RLS SELECT extendido: bloqueado no ve mensajes/chats/participantes
-- ──────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "messages: select if participant" ON public.messages;
CREATE POLICY "messages: select if participant and not blocked"
  ON public.messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants cp
      WHERE cp.chat_id = messages.chat_id AND cp.user_id = auth.uid()
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.chat_participants cp2
      JOIN public.blocked_users b
        ON b.blocker_id = cp2.user_id AND b.blocked_id = auth.uid()
      WHERE cp2.chat_id = messages.chat_id
        AND cp2.user_id <> auth.uid()
    )
  );

DROP POLICY IF EXISTS "chats: select if participant" ON public.chats;
CREATE POLICY "chats: select if participant and not blocked"
  ON public.chats FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants cp
      WHERE cp.chat_id = chats.id AND cp.user_id = auth.uid()
    )
    AND NOT EXISTS (
      SELECT 1
      FROM public.chat_participants cp2
      JOIN public.blocked_users b
        ON b.blocker_id = cp2.user_id AND b.blocked_id = auth.uid()
      WHERE cp2.chat_id = chats.id
        AND cp2.user_id <> auth.uid()
    )
  );

DROP POLICY IF EXISTS "chat_participants: select if in chat" ON public.chat_participants;
CREATE POLICY "chat_participants: select if in chat and not blocked"
  ON public.chat_participants FOR SELECT TO authenticated
  USING (
    (
      user_id = auth.uid()
      OR EXISTS (
        SELECT 1 FROM public.chat_participants cp
        WHERE cp.chat_id = chat_participants.chat_id AND cp.user_id = auth.uid()
      )
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.blocked_users b
      WHERE b.blocker_id = chat_participants.user_id
        AND b.blocked_id = auth.uid()
        AND chat_participants.user_id <> auth.uid()
    )
  );

-- ──────────────────────────────────────────────────────────────
-- 5) Column-level UPDATE en chat_participants: solo last_read_at
-- ──────────────────────────────────────────────────────────────
REVOKE UPDATE ON public.chat_participants FROM authenticated;
GRANT  UPDATE (last_read_at) ON public.chat_participants TO authenticated;

-- ──────────────────────────────────────────────────────────────
-- 6) soft_delete_message recalcula chats.last_message
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.soft_delete_message(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me      uuid := auth.uid();
  v_chat_id uuid;
  v_last_text  text;
  v_last_at    timestamptz;
BEGIN
  IF v_me IS NULL THEN RETURN; END IF;

  SELECT chat_id INTO v_chat_id FROM public.messages WHERE id = p_message_id;
  IF v_chat_id IS NULL THEN RETURN; END IF;

  UPDATE public.messages
     SET is_deleted = true,
         text       = ''
   WHERE id = p_message_id
     AND sender_id = v_me;

  IF NOT FOUND THEN RETURN; END IF;

  SELECT text, created_at INTO v_last_text, v_last_at
  FROM public.messages
  WHERE chat_id = v_chat_id AND is_deleted = false
  ORDER BY created_at DESC
  LIMIT 1;

  UPDATE public.chats
     SET last_message    = v_last_text,
         last_message_at = v_last_at,
         updated_at      = now()
   WHERE id = v_chat_id;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 7) Revocar EXECUTE de trigger function interna
-- ──────────────────────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.fn_after_message_insert() FROM anon, public, authenticated;
