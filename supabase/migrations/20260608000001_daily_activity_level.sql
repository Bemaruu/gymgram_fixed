-- Captura el nivel de actividad diaria/laboral (NEAT) del usuario en onboarding.
-- Hasta ahora el cálculo nutricional asumía 'moderate' para todos y solo
-- ajustaba por días de entrenamiento. Este campo alimenta el factor de
-- actividad real (sedentary..very_active) en NutritionCalculator.
-- Aditivo: NULL permitido para no romper registros existentes.

ALTER TABLE public.user_onboarding_data
  ADD COLUMN IF NOT EXISTS daily_activity_level text;

ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_daily_activity_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_daily_activity_chk
  CHECK (daily_activity_level IS NULL OR daily_activity_level IN
    ('sedentary','light','moderate','active','very_active'));
