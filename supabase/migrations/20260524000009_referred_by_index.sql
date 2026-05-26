-- Índice de cobertura para la FK profiles.referred_by (la consulta
-- my_referral_count() filtra por referred_by = auth.uid()). (2026-05-24)
CREATE INDEX IF NOT EXISTS idx_fk_profiles_referred_by
  ON public.profiles(referred_by);
