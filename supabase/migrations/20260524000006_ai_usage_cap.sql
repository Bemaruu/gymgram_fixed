-- ============================================================
-- Tope duro de costo IA: registra cada invocación de IA por usuario para poder
-- aplicar un cap mensual server-side (blast radius). Antes solo existían cuotas
-- de cambios (cliente) y el límite diario de chat; generate-routine y
-- generate-nutrition-plan no tenían tope server-side. (2026-05-24)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.ai_usage_events (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fn         text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_events_user_month
  ON public.ai_usage_events(user_id, created_at);

ALTER TABLE public.ai_usage_events ENABLE ROW LEVEL SECURITY;

-- El dueño puede leer su uso. NADIE inserta desde el cliente: solo el service
-- role (edge functions) registra eventos, así el contador no es manipulable.
-- (select auth.uid()) se evalúa 1 vez por query (optimización auth_rls_initplan).
DROP POLICY IF EXISTS "ai_usage_events: select own" ON public.ai_usage_events;
CREATE POLICY "ai_usage_events: select own"
  ON public.ai_usage_events FOR SELECT
  USING ((select auth.uid()) = user_id);
