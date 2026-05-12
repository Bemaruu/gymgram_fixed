-- Distinguir rutina semanal personal (1 por dia) vs rutinas comunitarias (sin dia)
ALTER TABLE public.routines
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'personal'
    CHECK (kind IN ('personal','community'));

-- Permitir day_of_week NULL para rutinas comunitarias
ALTER TABLE public.routines
  ALTER COLUMN day_of_week DROP NOT NULL;

-- Index para filtrar por kind rapido
CREATE INDEX IF NOT EXISTS idx_routines_kind ON public.routines(kind);
