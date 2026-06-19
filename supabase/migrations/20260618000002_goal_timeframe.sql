-- Plazo del objetivo físico (timeframe). El usuario elige en cuánto tiempo
-- quiere lograr su objetivo (3 / 6 / 12 meses). Esto modula la agresividad del
-- déficit/superávit calórico y la proteína DENTRO de las bandas validadas con
-- la nutricionista (déficit 300-500 kcal, superávit 300-450, proteína 1.8-2.2
-- g/kg). Cuando goal_target_date vence, el plan entra automáticamente en
-- mantenimiento hasta que el usuario fije un nuevo objetivo + plazo.
--
-- Respaldo de los plazos:
--   - 3 meses (~12 semanas): bloque mínimo estándar en la literatura para ver
--     un cambio de composición corporal real; ritmo más exigente pero seguro.
--   - 6 meses: ritmo moderado y sostenible.
--   - 12 meses: ritmo gradual; máxima retención muscular en déficit / mínima
--     ganancia de grasa en superávit (lean bulk).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS goal_timeframe_months smallint
    CHECK (goal_timeframe_months IS NULL OR goal_timeframe_months IN (3, 6, 12)),
  ADD COLUMN IF NOT EXISTS goal_started_at date,
  ADD COLUMN IF NOT EXISTS goal_target_date date;

COMMENT ON COLUMN public.profiles.goal_timeframe_months IS
  'Plazo elegido para el objetivo físico: 3, 6 o 12 meses. NULL = sin plazo (legacy / objetivos no físicos).';
COMMENT ON COLUMN public.profiles.goal_started_at IS
  'Fecha (local) en que el usuario fijó el objetivo + plazo actual.';
COMMENT ON COLUMN public.profiles.goal_target_date IS
  'goal_started_at + goal_timeframe_months. Al pasar esta fecha el plan pasa a mantenimiento.';
