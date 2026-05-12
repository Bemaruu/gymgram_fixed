-- ============================================================
-- Rutinas copiables + Publicaciones guardadas
-- ============================================================

-- 1) routines: columnas nuevas
ALTER TABLE public.routines
  ADD COLUMN IF NOT EXISTS is_public bool NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS copies_count int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS source_routine_id uuid REFERENCES public.routines(id) ON DELETE SET NULL;

-- 2) RLS routines: permitir leer rutinas publicas de cualquier usuario autenticado
DROP POLICY IF EXISTS "routines: select own" ON public.routines;
CREATE POLICY "routines: select public or own"
  ON public.routines FOR SELECT
  TO authenticated
  USING (is_public = true OR user_id = auth.uid());

-- 3) RLS routine_exercises: permitir leer ejercicios cuya rutina sea publica
DROP POLICY IF EXISTS "routine_exercises: select own" ON public.routine_exercises;
CREATE POLICY "routine_exercises: select public or own"
  ON public.routine_exercises FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.routines r
      WHERE r.id = routine_id
        AND (r.is_public = true OR r.user_id = auth.uid())
    )
  );

-- 4) Tabla routine_copies (anti-cheat: 1 copia por user-rutina cuenta solo 1 vez)
CREATE TABLE IF NOT EXISTS public.routine_copies (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  routine_id  uuid NOT NULL REFERENCES public.routines(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  copied_at   timestamp NOT NULL DEFAULT now(),
  UNIQUE (routine_id, user_id)
);

ALTER TABLE public.routine_copies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "routine_copies: select own"
  ON public.routine_copies FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "routine_copies: insert own"
  ON public.routine_copies FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 5) Trigger para mantener copies_count actualizado
CREATE OR REPLACE FUNCTION public.bump_routine_copies_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.routines
     SET copies_count = copies_count + 1
   WHERE id = NEW.routine_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bump_routine_copies ON public.routine_copies;
CREATE TRIGGER trg_bump_routine_copies
AFTER INSERT ON public.routine_copies
FOR EACH ROW
EXECUTE FUNCTION public.bump_routine_copies_count();

-- 6) Tabla saved_posts (publicaciones guardadas por el usuario)
CREATE TABLE IF NOT EXISTS public.saved_posts (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id   uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  user_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  saved_at  timestamp NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);

ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saved_posts: select own"
  ON public.saved_posts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "saved_posts: insert own"
  ON public.saved_posts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "saved_posts: delete own"
  ON public.saved_posts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- 7) Indices utiles
CREATE INDEX IF NOT EXISTS idx_routines_user_id ON public.routines(user_id);
CREATE INDEX IF NOT EXISTS idx_routines_public ON public.routines(is_public) WHERE is_public = true;
CREATE INDEX IF NOT EXISTS idx_routine_copies_user ON public.routine_copies(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_posts_user ON public.saved_posts(user_id);
