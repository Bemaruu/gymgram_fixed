-- Auditoría de calidad del plan de rutina generado (análogo a
-- nutrition_plans.quality_flags). Guarda volumen semanal por grupo muscular,
-- balance empuje/tirón/pierna y total de series, para auditar el nivel de la
-- rutina que recomienda la IA y alimentar futuras métricas/UX.
ALTER TABLE public.routine_plans
  ADD COLUMN IF NOT EXISTS quality_flags jsonb;

COMMENT ON COLUMN public.routine_plans.quality_flags IS
  'Auditoria de calidad del plan generado: volumen semanal por musculo, balance empuje/tiron/pierna, total de series. Analogo a nutrition_plans.quality_flags.';
