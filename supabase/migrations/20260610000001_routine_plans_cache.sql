-- Cache de planes de rutina generados por IA (paralelo a nutrition_plans).
-- Un plan por usuario; cuando cambian days_per_week se regenera.

CREATE TABLE IF NOT EXISTS public.routine_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_json jsonb NOT NULL,
  days_per_week integer NOT NULL,
  session_duration_min integer NOT NULL DEFAULT 60,
  catalog_size integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT routine_plans_user_unique UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS routine_plans_user_idx
  ON public.routine_plans (user_id);

ALTER TABLE public.routine_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "routine_plans_select_own"
  ON public.routine_plans
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "routine_plans_insert_own"
  ON public.routine_plans
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "routine_plans_update_own"
  ON public.routine_plans
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "routine_plans_delete_own"
  ON public.routine_plans
  FOR DELETE
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.tg_routine_plans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER routine_plans_updated_at_trg
  BEFORE UPDATE ON public.routine_plans
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_routine_plans_updated_at();

COMMENT ON TABLE public.routine_plans IS
  'Cache de planes de rutina generados por IA. Un plan por usuario, regenera en cambio de days_per_week.';
