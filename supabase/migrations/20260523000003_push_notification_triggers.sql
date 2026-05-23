-- Push notification triggers
-- Conecta la tabla notifications (like/follow/comment/coach_message)
-- y la tabla messages (DM) con la Edge Function send-push-notification.
-- Usa los vault secrets 'project_url' y 'service_role_key' que ya existen
-- para el cron mensual. Si el vault no está configurado, el trigger se omite
-- silenciosamente para no bloquear la operación.

-- ── Trigger en notifications ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_push_on_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_username text;
  v_title          text;
  v_body           text;
  v_url            text;
  v_key            text;
BEGIN
  SELECT username INTO v_actor_username
  FROM public.profiles WHERE id = NEW.actor_id;

  CASE NEW.type
    WHEN 'like' THEN
      v_title := 'Nuevo like';
      v_body  := coalesce('@' || v_actor_username, 'Alguien')
                 || ' le dio like a tu publicación';
    WHEN 'follow' THEN
      v_title := 'Nuevo seguidor';
      v_body  := coalesce('@' || v_actor_username, 'Alguien')
                 || ' empezó a seguirte';
    WHEN 'comment' THEN
      v_title := 'Nuevo comentario';
      v_body  := coalesce('@' || v_actor_username, 'Alguien')
                 || ' comentó en tu publicación';
    WHEN 'coach_message' THEN
      v_title := 'Tu entrenador IA';
      v_body  := 'Tienes un nuevo mensaje de tu coach';
    ELSE
      RETURN NEW;
  END CASE;

  SELECT decrypted_secret INTO v_url
  FROM vault.decrypted_secrets WHERE name = 'project_url';
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'service_role_key';

  IF v_url IS NULL OR v_key IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object(
      'user_id', NEW.user_id::text,
      'title',   v_title,
      'body',    v_body
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_on_notification ON public.notifications;
CREATE TRIGGER trg_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.trigger_push_on_notification();

-- ── Trigger en messages (DMs) ─────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.trigger_push_on_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_username text;
  v_preview         text;
  v_url             text;
  v_key             text;
BEGIN
  SELECT username INTO v_sender_username
  FROM public.profiles WHERE id = NEW.sender_id;

  v_preview := CASE WHEN length(NEW.text) > 80
               THEN left(NEW.text, 77) || '...'
               ELSE NEW.text END;

  SELECT decrypted_secret INTO v_url
  FROM vault.decrypted_secrets WHERE name = 'project_url';
  SELECT decrypted_secret INTO v_key
  FROM vault.decrypted_secrets WHERE name = 'service_role_key';

  IF v_url IS NULL OR v_key IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url     := v_url || '/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body    := jsonb_build_object(
      'user_id', NEW.receiver_id::text,
      'title',   'Mensaje de @' || coalesce(v_sender_username, 'usuario'),
      'body',    v_preview
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_on_message ON public.messages;
CREATE TRIGGER trg_push_on_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.trigger_push_on_message();
