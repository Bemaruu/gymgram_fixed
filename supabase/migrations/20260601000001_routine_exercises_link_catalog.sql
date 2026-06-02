-- Enlaza routine_exercises con exercise_catalog para que rutinas importadas
-- por el usuario puedan asociarse a un ejercicio canónico (ranked, fotos, IA).
-- Si no hay match (is_custom=true), el name texto libre se preserva.
ALTER TABLE public.routine_exercises
  ADD COLUMN IF NOT EXISTS exercise_id uuid REFERENCES public.exercise_catalog(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_custom boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_routine_exercises_exercise_id
  ON public.routine_exercises (exercise_id)
  WHERE exercise_id IS NOT NULL;
