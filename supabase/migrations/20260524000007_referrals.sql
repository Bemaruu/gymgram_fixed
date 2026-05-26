-- ============================================================
-- Sistema de referidos (viralidad). Cada perfil tiene un referral_code único;
-- un usuario nuevo puede canjear el código de otro (referred_by). (2026-05-24)
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referral_code text UNIQUE;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS referred_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Generador de código de 6 chars (alfabeto sin caracteres ambiguos 0/O/1/I/L).
CREATE OR REPLACE FUNCTION public.gen_referral_code()
RETURNS text LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  alphabet text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  code text;
  i int;
BEGIN
  LOOP
    code := '';
    FOR i IN 1..6 LOOP
      code := code || substr(alphabet, 1 + floor(random()*length(alphabet))::int, 1);
    END LOOP;
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = code);
  END LOOP;
  RETURN code;
END $$;
REVOKE EXECUTE ON FUNCTION public.gen_referral_code() FROM anon, public, authenticated;

-- Backfill de perfiles existentes.
UPDATE public.profiles SET referral_code = public.gen_referral_code()
WHERE referral_code IS NULL;

-- Trigger: asigna código a cada perfil nuevo.
CREATE OR REPLACE FUNCTION public.set_referral_code()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.referral_code IS NULL THEN
    NEW.referral_code := public.gen_referral_code();
  END IF;
  RETURN NEW;
END $$;
REVOKE EXECUTE ON FUNCTION public.set_referral_code() FROM anon, public, authenticated;

DROP TRIGGER IF EXISTS trg_set_referral_code ON public.profiles;
CREATE TRIGGER trg_set_referral_code
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_referral_code();

-- Canje de código. Solo cuentas nuevas (<14 días), una sola vez, no propio.
CREATE OR REPLACE FUNCTION public.redeem_referral(p_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me uuid := auth.uid();
  v_referrer uuid;
  v_created timestamptz;
BEGIN
  IF v_me IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_me AND referred_by IS NOT NULL) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'already_redeemed');
  END IF;

  SELECT created_at INTO v_created FROM public.profiles WHERE id = v_me;
  IF v_created < now() - interval '14 days' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'account_too_old');
  END IF;

  SELECT id INTO v_referrer FROM public.profiles
  WHERE upper(referral_code) = upper(trim(p_code));
  IF v_referrer IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_code');
  END IF;
  IF v_referrer = v_me THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'self');
  END IF;

  UPDATE public.profiles SET referred_by = v_referrer WHERE id = v_me;
  RETURN jsonb_build_object('ok', true);
END $$;
REVOKE EXECUTE ON FUNCTION public.redeem_referral(text) FROM anon, public;
GRANT EXECUTE ON FUNCTION public.redeem_referral(text) TO authenticated;

-- Cuántos usuarios he referido.
CREATE OR REPLACE FUNCTION public.my_referral_count()
RETURNS int LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp STABLE AS $$
  SELECT count(*)::int FROM public.profiles WHERE referred_by = auth.uid();
$$;
REVOKE EXECUTE ON FUNCTION public.my_referral_count() FROM anon, public;
GRANT EXECUTE ON FUNCTION public.my_referral_count() TO authenticated;
