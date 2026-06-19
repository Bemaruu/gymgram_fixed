-- Métricas deterministas del mes (entrenamiento/nutrición/adherencia) para
-- renderizar tarjetas en la pantalla de reporte, además del texto de la IA.
-- Aplicada via MCP. Backup del DDL.
ALTER TABLE public.ai_monthly_summaries
  ADD COLUMN IF NOT EXISTS stats jsonb;

COMMENT ON COLUMN public.ai_monthly_summaries.stats IS
  'Métricas calculadas server-side del mes (sesiones, volumen, kcal/macros promedio, adherencia vs metas). Render de tarjetas; el texto IA va en content.';
