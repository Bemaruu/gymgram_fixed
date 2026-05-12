-- Helper function: checks if the current user is a participant in a chat.
-- SECURITY DEFINER so it queries chat_participants WITHOUT triggering its own
-- RLS policy, which prevents infinite recursion.
CREATE OR REPLACE FUNCTION public.is_chat_participant(p_chat_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_participants
    WHERE chat_id = p_chat_id AND user_id = auth.uid()
  )
$$;

GRANT EXECUTE ON FUNCTION public.is_chat_participant(uuid) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.is_chat_participant(uuid) FROM anon, public;

-- Fix chat_participants SELECT policy: replace the self-referential EXISTS
-- (which caused infinite recursion) with the helper function above.
DROP POLICY IF EXISTS "chat_participants: select if in chat and not blocked" ON public.chat_participants;
CREATE POLICY "chat_participants: select if in chat and not blocked"
  ON public.chat_participants FOR SELECT TO authenticated
  USING (
    public.is_chat_participant(chat_participants.chat_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.blocked_users b
      WHERE b.blocker_id = chat_participants.user_id
        AND b.blocked_id = auth.uid()
        AND chat_participants.user_id <> auth.uid()
    )
  );

-- Also update messages and chats policies to use the helper for consistency.
DROP POLICY IF EXISTS "messages: select if participant and not blocked" ON public.messages;
CREATE POLICY "messages: select if participant and not blocked"
  ON public.messages FOR SELECT TO authenticated
  USING (
    public.is_chat_participant(messages.chat_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.chat_participants cp2
      JOIN public.blocked_users b
        ON b.blocker_id = cp2.user_id AND b.blocked_id = auth.uid()
      WHERE cp2.chat_id = messages.chat_id
        AND cp2.user_id <> auth.uid()
    )
  );

DROP POLICY IF EXISTS "chats: select if participant and not blocked" ON public.chats;
CREATE POLICY "chats: select if participant and not blocked"
  ON public.chats FOR SELECT TO authenticated
  USING (
    public.is_chat_participant(chats.id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.chat_participants cp2
      JOIN public.blocked_users b
        ON b.blocker_id = cp2.user_id AND b.blocked_id = auth.uid()
      WHERE cp2.chat_id = chats.id
        AND cp2.user_id <> auth.uid()
    )
  );
