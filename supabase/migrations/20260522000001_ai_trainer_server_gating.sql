-- RPC que verifica tier Premium server-side antes de insertar mensaje del usuario
CREATE OR REPLACE FUNCTION public.insert_ai_message(
  p_content text,
  p_message_type text DEFAULT 'chat'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me   uuid := auth.uid();
  v_tier text;
  v_count int;
  v_id   uuid;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  SELECT subscription_tier INTO v_tier FROM public.profiles WHERE id = v_me;
  IF coalesce(v_tier, 'free') <> 'premium' THEN
    RAISE EXCEPTION 'Premium required';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.ai_trainer_messages
  WHERE user_id = v_me
    AND role = 'user'
    AND created_at >= date_trunc('day', now() AT TIME ZONE 'UTC');
  IF v_count >= 10 THEN
    RAISE EXCEPTION 'Daily limit reached';
  END IF;

  INSERT INTO public.ai_trainer_messages (user_id, role, content, message_type)
  VALUES (v_me, 'user', p_content, p_message_type)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.insert_ai_message(text, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.insert_ai_message(text, text) FROM anon;
