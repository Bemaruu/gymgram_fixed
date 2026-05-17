-- Extiende el onboarding con campos necesarios para IA simulada y futura IA real.
-- Aditivo: no rompe registros existentes ni RLS vigente.

-- 1) user_onboarding_data: nuevas columnas
ALTER TABLE public.user_onboarding_data
  ADD COLUMN IF NOT EXISTS training_level text,
  ADD COLUMN IF NOT EXISTS experience_path text,
  ADD COLUMN IF NOT EXISTS equipment_available text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS session_duration_minutes int,
  ADD COLUMN IF NOT EXISTS routine_split_preference text,
  ADD COLUMN IF NOT EXISTS injuries text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS injury_notes text,
  ADD COLUMN IF NOT EXISTS cooking_time_preference text,
  ADD COLUMN IF NOT EXISTS disliked_foods text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS coaching_style text,
  ADD COLUMN IF NOT EXISTS notifications_enabled boolean,
  ADD COLUMN IF NOT EXISTS privacy_consent_at timestamptz,
  ADD COLUMN IF NOT EXISTS terms_consent_at timestamptz;

-- Constraints suaves (CHECK con NULL permitido para mantener compat con datos viejos)
ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_training_level_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_training_level_chk
  CHECK (training_level IS NULL OR training_level IN
    ('beginner','intermediate_lt_1y','intermediate_1y_3y','advanced_gt_3y'));

ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_experience_path_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_experience_path_chk
  CHECK (experience_path IS NULL OR experience_path IN
    ('create_ai_routine','analyze_existing_routine'));

ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_routine_split_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_routine_split_chk
  CHECK (routine_split_preference IS NULL OR routine_split_preference IN
    ('full_body','upper_lower','push_pull_legs','bro_split','no_preference'));

ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_cooking_time_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_cooking_time_chk
  CHECK (cooking_time_preference IS NULL OR cooking_time_preference IN
    ('no_time','quick_lt_15m','medium_15_30m','enjoy_cooking'));

ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_coaching_style_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_coaching_style_chk
  CHECK (coaching_style IS NULL OR coaching_style IN
    ('gentle','balanced','strict','no_notifications'));

ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_session_duration_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_session_duration_chk
  CHECK (session_duration_minutes IS NULL OR (session_duration_minutes BETWEEN 10 AND 180));

-- Texto libre acotado (anti-abuso). Cualquier valor existente que exceda se mantiene
-- gracias a NOT VALID para evitar fallar la migración; nuevos inserts sí se validan.
ALTER TABLE public.user_onboarding_data
  DROP CONSTRAINT IF EXISTS user_onboarding_data_injury_notes_len_chk;
ALTER TABLE public.user_onboarding_data
  ADD CONSTRAINT user_onboarding_data_injury_notes_len_chk
  CHECK (injury_notes IS NULL OR char_length(injury_notes) <= 200) NOT VALID;

-- 2a) routine_exercises: notas opcionales por ejercicio (rutina importada)
ALTER TABLE public.routine_exercises
  ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.routine_exercises
  DROP CONSTRAINT IF EXISTS routine_exercises_notes_len_chk;
ALTER TABLE public.routine_exercises
  ADD CONSTRAINT routine_exercises_notes_len_chk
  CHECK (notes IS NULL OR char_length(notes) <= 200) NOT VALID;

-- 2) routines: análisis IA + origen explícito
ALTER TABLE public.routines
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'manual',
  ADD COLUMN IF NOT EXISTS routine_analysis jsonb;

ALTER TABLE public.routines
  DROP CONSTRAINT IF EXISTS routines_source_chk;
ALTER TABLE public.routines
  ADD CONSTRAINT routines_source_chk
  CHECK (source IN ('ai_generated','user_imported','community_copied','manual'));

CREATE INDEX IF NOT EXISTS idx_routines_source ON public.routines(source);
