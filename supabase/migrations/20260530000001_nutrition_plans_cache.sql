-- Plan nutricional semanal cacheado por usuario.
-- Una fila por (user_id, week_index). El plan completo (7 dias) va en plan_json.
CREATE TABLE IF NOT EXISTS public.nutrition_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week_index integer NOT NULL,
  plan_json jsonb NOT NULL,
  daily_avg jsonb,
  weekly_totals jsonb,
  meals_per_day integer,
  catalog_size integer,
  eating_disorder_safe_mode boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT nutrition_plans_user_week_uniq UNIQUE (user_id, week_index)
);

CREATE INDEX IF NOT EXISTS idx_nutrition_plans_user_week
  ON public.nutrition_plans (user_id, week_index DESC);

ALTER TABLE public.nutrition_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nutrition_plans_select_own" ON public.nutrition_plans
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "nutrition_plans_insert_own" ON public.nutrition_plans
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "nutrition_plans_update_own" ON public.nutrition_plans
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "nutrition_plans_delete_own" ON public.nutrition_plans
  FOR DELETE USING (auth.uid() = user_id);
