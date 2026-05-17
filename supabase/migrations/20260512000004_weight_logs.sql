-- Tabla para registros de peso corporal del usuario.
-- Necesaria para la medalla "Evolución Visible" (5 registros).

CREATE TABLE IF NOT EXISTS public.weight_logs (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  weight_kg  numeric(5,2) NOT NULL CHECK (weight_kg > 0 AND weight_kg < 500),
  logged_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.weight_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "weight_logs: select own"
  ON public.weight_logs FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "weight_logs: insert own"
  ON public.weight_logs FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "weight_logs: delete own"
  ON public.weight_logs FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS weight_logs_user_id_idx ON public.weight_logs(user_id, logged_at DESC);
