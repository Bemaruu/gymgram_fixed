-- RLS para las 10 tablas del schema inicial que no tenian politicas definidas.
-- Patron: privado por defecto, exponer solo lo necesario para el feed social.

-- ============================================================
-- profiles
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles: select any authenticated"
  ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "profiles: insert own"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles: update own"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "profiles: delete own"
  ON public.profiles FOR DELETE USING (auth.uid() = id);

-- ============================================================
-- user_onboarding_data
-- ============================================================
ALTER TABLE public.user_onboarding_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_onboarding_data: select own"
  ON public.user_onboarding_data FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "user_onboarding_data: insert own"
  ON public.user_onboarding_data FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_onboarding_data: update own"
  ON public.user_onboarding_data FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "user_onboarding_data: delete own"
  ON public.user_onboarding_data FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- posts
-- ============================================================
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "posts: select any authenticated"
  ON public.posts FOR SELECT TO authenticated USING (true);

CREATE POLICY "posts: insert own"
  ON public.posts FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "posts: update own"
  ON public.posts FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "posts: delete own"
  ON public.posts FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- likes
-- ============================================================
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "likes: select any authenticated"
  ON public.likes FOR SELECT TO authenticated USING (true);

CREATE POLICY "likes: insert own"
  ON public.likes FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "likes: delete own"
  ON public.likes FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- comments
-- ============================================================
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "comments: select any authenticated"
  ON public.comments FOR SELECT TO authenticated USING (true);

CREATE POLICY "comments: insert own"
  ON public.comments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "comments: delete own"
  ON public.comments FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- routines
-- ============================================================
ALTER TABLE public.routines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "routines: select own"
  ON public.routines FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "routines: insert own"
  ON public.routines FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "routines: update own"
  ON public.routines FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "routines: delete own"
  ON public.routines FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- routine_exercises  (acceso via routine_id, dueno implicito)
-- ============================================================
ALTER TABLE public.routine_exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "routine_exercises: select own"
  ON public.routine_exercises FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.routines r
      WHERE r.id = routine_id AND r.user_id = auth.uid()
    )
  );

CREATE POLICY "routine_exercises: insert own"
  ON public.routine_exercises FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.routines r
      WHERE r.id = routine_id AND r.user_id = auth.uid()
    )
  );

CREATE POLICY "routine_exercises: update own"
  ON public.routine_exercises FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.routines r
      WHERE r.id = routine_id AND r.user_id = auth.uid()
    )
  );

CREATE POLICY "routine_exercises: delete own"
  ON public.routine_exercises FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.routines r
      WHERE r.id = routine_id AND r.user_id = auth.uid()
    )
  );

-- ============================================================
-- meal_plans
-- ============================================================
ALTER TABLE public.meal_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meal_plans: select own"
  ON public.meal_plans FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "meal_plans: insert own"
  ON public.meal_plans FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "meal_plans: update own"
  ON public.meal_plans FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "meal_plans: delete own"
  ON public.meal_plans FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- meal_items  (acceso via meal_plan_id, dueno implicito)
-- ============================================================
ALTER TABLE public.meal_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meal_items: select own"
  ON public.meal_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.meal_plans mp
      WHERE mp.id = meal_plan_id AND mp.user_id = auth.uid()
    )
  );

CREATE POLICY "meal_items: insert own"
  ON public.meal_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.meal_plans mp
      WHERE mp.id = meal_plan_id AND mp.user_id = auth.uid()
    )
  );

CREATE POLICY "meal_items: update own"
  ON public.meal_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.meal_plans mp
      WHERE mp.id = meal_plan_id AND mp.user_id = auth.uid()
    )
  );

CREATE POLICY "meal_items: delete own"
  ON public.meal_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.meal_plans mp
      WHERE mp.id = meal_plan_id AND mp.user_id = auth.uid()
    )
  );

-- ============================================================
-- water_logs
-- ============================================================
ALTER TABLE public.water_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "water_logs: select own"
  ON public.water_logs FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "water_logs: insert own"
  ON public.water_logs FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "water_logs: update own"
  ON public.water_logs FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "water_logs: delete own"
  ON public.water_logs FOR DELETE USING (auth.uid() = user_id);
