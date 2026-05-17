-- Crea las tablas follows y notifications con RLS completo.
-- Estas tablas eran usadas por el cliente pero no tenian definicion SQL rastreada,
-- lo que significa que si existian en produccion, podian carecer de RLS.

-- ============================================================
-- FOLLOWS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.follows (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id  uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  following_id uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(follower_id, following_id),
  CHECK(follower_id <> following_id)
);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "follows: select authenticated"
  ON public.follows FOR SELECT TO authenticated USING (true);

CREATE POLICY "follows: insert own"
  ON public.follows FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "follows: delete own"
  ON public.follows FOR DELETE TO authenticated
  USING (auth.uid() = follower_id);

CREATE INDEX IF NOT EXISTS follows_follower_id_idx  ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS follows_following_id_idx ON public.follows(following_id);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  actor_id   uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  post_id    uuid        REFERENCES public.posts(id) ON DELETE CASCADE,
  type       text        NOT NULL CHECK (type IN ('like', 'follow', 'comment')),
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications: select own"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "notifications: update own"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "notifications: insert system"
  ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS notifications_user_id_idx    ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_read_at_idx    ON public.notifications(user_id, read_at)
  WHERE read_at IS NULL;

-- RPC para limpiar notificaciones antiguas (llamada desde home_screen.dart)
CREATE OR REPLACE FUNCTION public.cleanup_old_notifications()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.notifications
  WHERE user_id = auth.uid()
    AND created_at < now() - interval '7 days';
$$;
