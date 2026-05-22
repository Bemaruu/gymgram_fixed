-- Corrige award_badge: antes hacia ON CONFLICT DO NOTHING, por lo que una medalla
-- con progreso parcial previo (ej. Hidratado 5/7) NUNCA se marcaba como ganada al
-- llegar al 100%. Ahora, al otorgar, fuerza progress = 1.0 y fija earned_at solo en
-- la transicion (cuando antes el progreso era < 1.0), preservando la fecha original
-- si ya estaba ganada.

CREATE OR REPLACE FUNCTION public.award_badge(p_user_id uuid, p_badge_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF auth.uid() <> p_user_id THEN RAISE EXCEPTION 'Forbidden'; END IF;

  INSERT INTO public.user_badges (user_id, badge_id, earned_at, progress)
  VALUES (p_user_id, p_badge_id, now(), 1.0)
  ON CONFLICT (user_id, badge_id) DO UPDATE
    SET progress  = 1.0,
        earned_at = CASE
          WHEN public.user_badges.progress < 1.0 THEN now()
          ELSE public.user_badges.earned_at
        END;
END;
$$;

GRANT EXECUTE ON FUNCTION public.award_badge(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.award_badge(uuid, text) FROM anon, public;
