ALTER TABLE public.routines
  ADD COLUMN IF NOT EXISTS is_archived bool NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_routines_archived
  ON public.routines(user_id, day_of_week)
  WHERE is_archived = true;
