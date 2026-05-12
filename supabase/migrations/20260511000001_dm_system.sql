-- ============================================================
-- DM SYSTEM (Beta)
-- Mensajería 1:1 de texto. Sin multimedia. Sin grupos por ahora.
-- Toda mutación pasa por RPC para forzar rate-limit + anti-bloqueo.
-- ============================================================

-- ============================================================
-- 1) TABLAS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.chats (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  last_message    text,
  last_message_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chats_last_message_at
  ON public.chats (last_message_at DESC);

CREATE TABLE IF NOT EXISTS public.chat_participants (
  chat_id       uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  unread_count  int  NOT NULL DEFAULT 0,
  last_read_at  timestamptz,
  joined_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (chat_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_participants_user
  ON public.chat_participants (user_id, chat_id);

CREATE TABLE IF NOT EXISTS public.messages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id     uuid NOT NULL REFERENCES public.chats(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  text        text NOT NULL,
  status      text NOT NULL DEFAULT 'sent' CHECK (status IN ('sent','delivered','read')),
  read_at     timestamptz,
  is_deleted  boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_messages_chat_created
  ON public.messages (chat_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_sender_created
  ON public.messages (sender_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.blocked_users (
  blocker_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_blocked_users_blocked
  ON public.blocked_users (blocked_id);

CREATE TABLE IF NOT EXISTS public.reports (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  target_message_id  uuid REFERENCES public.messages(id) ON DELETE SET NULL,
  reason             text NOT NULL,
  status             text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed')),
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reports_status
  ON public.reports (status, created_at DESC);

-- ============================================================
-- 2) RLS
-- Patrón: lectura solo a participantes; toda mutación de mensajes via RPC.
-- ============================================================

ALTER TABLE public.chats              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_participants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports            ENABLE ROW LEVEL SECURITY;

-- chats: SELECT solo si soy participante. INSERT/UPDATE/DELETE via RPC (SECURITY DEFINER).
CREATE POLICY "chats: select if participant"
  ON public.chats FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants cp
      WHERE cp.chat_id = chats.id AND cp.user_id = auth.uid()
    )
  );

-- chat_participants: ver mi fila o filas del mismo chat. UPDATE solo de mi fila (last_read_at).
CREATE POLICY "chat_participants: select if in chat"
  ON public.chat_participants FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.chat_participants cp
      WHERE cp.chat_id = chat_participants.chat_id AND cp.user_id = auth.uid()
    )
  );

CREATE POLICY "chat_participants: update own row"
  ON public.chat_participants FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- messages: solo SELECT (resto via RPC).
CREATE POLICY "messages: select if participant"
  ON public.messages FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.chat_participants cp
      WHERE cp.chat_id = messages.chat_id AND cp.user_id = auth.uid()
    )
  );

-- blocked_users: solo el bloqueador gestiona su lista.
CREATE POLICY "blocked_users: select own"
  ON public.blocked_users FOR SELECT TO authenticated
  USING (blocker_id = auth.uid());

CREATE POLICY "blocked_users: insert own"
  ON public.blocked_users FOR INSERT TO authenticated
  WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "blocked_users: delete own"
  ON public.blocked_users FOR DELETE TO authenticated
  USING (blocker_id = auth.uid());

-- reports: insert propio, lectura propia.
CREATE POLICY "reports: insert own"
  ON public.reports FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "reports: select own"
  ON public.reports FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());

-- ============================================================
-- 3) TRIGGERS
-- ============================================================

-- Al insertar mensaje: actualizar last_message del chat + incrementar unread del receptor.
CREATE OR REPLACE FUNCTION public.fn_after_message_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.chats
     SET last_message    = CASE WHEN NEW.is_deleted THEN NULL ELSE NEW.text END,
         last_message_at = NEW.created_at,
         updated_at      = now()
   WHERE id = NEW.chat_id;

  UPDATE public.chat_participants
     SET unread_count = unread_count + 1
   WHERE chat_id = NEW.chat_id
     AND user_id = NEW.receiver_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_after_message_insert ON public.messages;
CREATE TRIGGER trg_after_message_insert
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.fn_after_message_insert();

-- ============================================================
-- 4) RPCs
-- ============================================================

-- find_or_create_chat(other_user_id): retorna chat_id 1:1, creándolo si no existe.
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

  -- Buscar chat 1:1 existente entre v_me y p_other_user_id.
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

GRANT EXECUTE ON FUNCTION public.find_or_create_chat(uuid) TO authenticated;

-- send_message: única vía de inserción. Aplica sanitización + rate-limit + anti-bloqueo.
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

  -- Verificar membresía.
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE chat_id = p_chat_id AND user_id = v_me
  ) THEN
    RAISE EXCEPTION 'Not a participant';
  END IF;

  -- Receptor (en 1:1 es el otro).
  SELECT user_id INTO v_receiver
  FROM public.chat_participants
  WHERE chat_id = p_chat_id AND user_id <> v_me
  LIMIT 1;

  IF v_receiver IS NULL THEN
    RAISE EXCEPTION 'Receiver not found';
  END IF;

  -- Bloqueo bidireccional.
  IF EXISTS (
    SELECT 1 FROM public.blocked_users
    WHERE (blocker_id = v_me       AND blocked_id = v_receiver)
       OR (blocker_id = v_receiver AND blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'Blocked';
  END IF;

  -- Rate-limit: máx 10 mensajes en los últimos 30s en este chat.
  SELECT count(*) INTO v_count
  FROM public.messages
  WHERE sender_id  = v_me
    AND chat_id    = p_chat_id
    AND created_at > now() - interval '30 seconds';
  IF v_count >= 10 THEN
    RAISE EXCEPTION 'Rate limit';
  END IF;

  INSERT INTO public.messages (chat_id, sender_id, receiver_id, text)
  VALUES (p_chat_id, v_me, v_receiver, v_clean)
  RETURNING id INTO v_msg_id;

  RETURN v_msg_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_message(uuid, text) TO authenticated;

-- mark_chat_read: marca mensajes pendientes como leídos y resetea unread.
CREATE OR REPLACE FUNCTION public.mark_chat_read(p_chat_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN RETURN; END IF;

  UPDATE public.messages
     SET read_at = now(),
         status  = 'read'
   WHERE chat_id = p_chat_id
     AND receiver_id = v_me
     AND read_at IS NULL;

  UPDATE public.chat_participants
     SET unread_count = 0,
         last_read_at = now()
   WHERE chat_id = p_chat_id
     AND user_id = v_me;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_chat_read(uuid) TO authenticated;

-- soft_delete_message: el remitente puede borrar suavemente su mensaje.
CREATE OR REPLACE FUNCTION public.soft_delete_message(p_message_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN RETURN; END IF;

  UPDATE public.messages
     SET is_deleted = true,
         text       = ''
   WHERE id = p_message_id
     AND sender_id = v_me;
END;
$$;

GRANT EXECUTE ON FUNCTION public.soft_delete_message(uuid) TO authenticated;

-- Defensa en profundidad: revocamos EXECUTE de anon en todas las RPCs.
-- (auth.uid() retorna NULL para anon y ya rechaza, pero no exponemos el endpoint.)
REVOKE EXECUTE ON FUNCTION public.find_or_create_chat(uuid)  FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.send_message(uuid, text)   FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.mark_chat_read(uuid)       FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.soft_delete_message(uuid)  FROM anon, public;

-- ============================================================
-- 5) REALTIME
-- ============================================================

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chats;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_participants;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
