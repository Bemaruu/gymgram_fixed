-- Amplía el CHECK de notifications.type para incluir mensajes del coach IA.
ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (type IN ('like', 'follow', 'comment', 'coach_message'));
