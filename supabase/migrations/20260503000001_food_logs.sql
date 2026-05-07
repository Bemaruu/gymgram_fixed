CREATE TABLE public.food_logs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  log_date         DATE NOT NULL,
  meal_type        TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack', 'pre_workout', 'post_workout')),
  food_name        TEXT NOT NULL,
  brand            TEXT,
  off_product_id   TEXT,
  barcode          TEXT,
  image_url        TEXT,
  grams            NUMERIC(7,2) NOT NULL CHECK (grams > 0),
  kcal_per_100g    NUMERIC(7,2),
  protein_per_100g NUMERIC(6,2),
  carbs_per_100g   NUMERIC(6,2),
  fat_per_100g     NUMERIC(6,2),
  fiber_per_100g   NUMERIC(6,2),
  kcal_total       NUMERIC(7,2),
  protein_total    NUMERIC(6,2),
  carbs_total      NUMERIC(6,2),
  fat_total        NUMERIC(6,2),
  fiber_total      NUMERIC(6,2),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_food_logs_user_date ON public.food_logs (user_id, log_date DESC);
CREATE INDEX idx_food_logs_user_date_meal ON public.food_logs (user_id, log_date DESC, meal_type);

ALTER TABLE public.food_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "food_logs: select own" ON public.food_logs FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "food_logs: insert own" ON public.food_logs FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "food_logs: delete own" ON public.food_logs FOR DELETE USING (auth.uid() = user_id);
