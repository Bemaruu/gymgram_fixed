-- ============================================================
-- GymGram Beta — Schema SQL definitivo
-- Proyecto: gymgram-beta (sa-east-1 / São Paulo)
-- Ejecutado via migración: initial_schema
-- ============================================================

-- TABLAS

CREATE TABLE IF NOT EXISTS profiles (
  id                uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username          text UNIQUE NOT NULL,
  full_name         text,
  avatar_url        text,
  bio               text,
  fitness_goal      text,
  training_location text,
  food_mode         text,
  birth_date        date,
  age               int,
  gender            text,
  weight            numeric,
  height            numeric,
  target_weight     numeric,
  created_at        timestamp DEFAULT now(),
  updated_at        timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_onboarding_data (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  available_days       text[],
  meals_per_day        int,
  allergies            text[],
  food_preferences     text[],
  exercise_preferences text[],
  time_availability    text,
  experience_level     text,
  created_at           timestamp DEFAULT now()
);

-- posts.user_id referencia profiles para joins directos via PostgREST
CREATE TABLE IF NOT EXISTS posts (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid REFERENCES profiles(id) ON DELETE CASCADE,
  media_url      text NOT NULL,
  media_type     text NOT NULL CHECK (media_type IN ('image','video')),
  caption        text,
  likes_count    int DEFAULT 0,
  comments_count int DEFAULT 0,
  created_at     timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS likes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid REFERENCES profiles(id) ON DELETE CASCADE,
  post_id    uuid REFERENCES posts(id) ON DELETE CASCADE,
  created_at timestamp DEFAULT now(),
  UNIQUE(user_id, post_id)
);

CREATE TABLE IF NOT EXISTS comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid REFERENCES profiles(id) ON DELETE CASCADE,
  post_id    uuid REFERENCES posts(id) ON DELETE CASCADE,
  content    text NOT NULL,
  created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS routines (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid REFERENCES profiles(id) ON DELETE CASCADE,
  title             text NOT NULL,
  goal              text,
  training_location text,
  day_of_week       int,
  disclaimer        text DEFAULT 'Recomendación general para beta, no reemplaza asesoría profesional.',
  created_at        timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS routine_exercises (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id   uuid REFERENCES routines(id) ON DELETE CASCADE,
  name         text NOT NULL,
  sets         int,
  reps         text,
  rest_seconds int,
  media_url    text,
  muscle_group text,
  order_index  int DEFAULT 0
);

CREATE TABLE IF NOT EXISTS meal_plans (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid REFERENCES profiles(id) ON DELETE CASCADE,
  title          text NOT NULL,
  food_mode      text,
  target_date    date,
  total_calories int,
  disclaimer     text DEFAULT 'Recomendación general para beta, no reemplaza asesoría profesional.',
  created_at     timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS meal_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_plan_id uuid REFERENCES meal_plans(id) ON DELETE CASCADE,
  meal_type    text NOT NULL,
  name         text NOT NULL,
  ingredients  text[],
  calories     int,
  protein      numeric,
  carbs        numeric,
  fats         numeric,
  completed    boolean DEFAULT false,
  order_index  int DEFAULT 0
);

CREATE TABLE IF NOT EXISTS water_logs (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES profiles(id) ON DELETE CASCADE,
  target_date   date NOT NULL,
  glasses_count int DEFAULT 0,
  created_at    timestamp DEFAULT now(),
  UNIQUE(user_id, target_date)
);

CREATE TABLE IF NOT EXISTS user_badges (
  id             uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id        uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  badge_id       text NOT NULL,
  earned_at      timestamptz DEFAULT now() NOT NULL,
  progress       float8 DEFAULT 0 NOT NULL,
  is_featured    boolean DEFAULT false NOT NULL,
  featured_order integer,
  UNIQUE(user_id, badge_id)
);

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "select_all"  ON public.user_badges FOR SELECT USING (true);
CREATE POLICY "insert_own"  ON public.user_badges FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "update_own"  ON public.user_badges FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "delete_own"  ON public.user_badges FOR DELETE USING (auth.uid() = user_id);

-- STORAGE BUCKETS
-- avatars: público (URLs para el feed)
-- posts:   privado con RLS
-- exercises: privado, solo lectura desde Flutter
