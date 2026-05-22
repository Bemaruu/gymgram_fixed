-- Vista pública de perfiles: solo expone columnas seguras para terceros
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT
  id,
  username,
  full_name,
  avatar_url,
  bio,
  fitness_goal,
  training_location,
  subscription_tier,
  created_at
FROM public.profiles;

GRANT SELECT ON public.public_profiles TO authenticated;
