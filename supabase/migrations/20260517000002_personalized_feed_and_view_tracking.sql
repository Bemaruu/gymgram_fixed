-- ============================================================
-- Mejora 1: Algoritmo de feed personalizado
-- Agrega boosts de afinidad de perfil al score de ranking:
--   × 2.0  si el viewer sigue al autor (ya existia)
--   × 1.4  si autor y viewer comparten el mismo fitness_goal
--   × 1.2  si autor y viewer comparten el mismo training_location
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_ranked_feed(
  p_user_id uuid,
  p_limit   int DEFAULT 30,
  p_offset  int DEFAULT 0
)
RETURNS TABLE (
  id             uuid,
  user_id        uuid,
  media_url      text,
  media_type     text,
  caption        text,
  likes_count    int,
  comments_count int,
  created_at     timestamptz,
  profiles       jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH viewer AS (
    SELECT fitness_goal, training_location
    FROM   profiles
    WHERE  id = p_user_id
  ),
  saves AS (
    SELECT post_id, COUNT(*)::int AS saves_count
    FROM   saved_posts
    GROUP  BY post_id
  ),
  followed AS (
    SELECT following_id
    FROM   follows
    WHERE  follower_id = p_user_id
  )
  SELECT
    p.id,
    p.user_id,
    p.media_url,
    p.media_type,
    p.caption,
    p.likes_count,
    p.comments_count,
    p.created_at,
    jsonb_build_object('username', pr.username, 'avatar_url', pr.avatar_url) AS profiles
  FROM   posts p
  JOIN   profiles pr ON pr.id = p.user_id
  LEFT   JOIN saves    s  ON s.post_id        = p.id
  LEFT   JOIN followed f  ON f.following_id   = p.user_id
  CROSS  JOIN viewer   v
  ORDER  BY (
    -- Engagement ponderado + 1 de base para posts nuevos sin interacciones
    (p.likes_count * 1.0 + p.comments_count * 3.0 + COALESCE(s.saves_count, 0) * 5.0 + 1.0)
    -- Decaimiento temporal: half-life de 24 horas
    * EXP(-0.693 * EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 86400.0)
    -- Boost social: x2 si el viewer sigue al autor
    * CASE WHEN f.following_id IS NOT NULL THEN 2.0 ELSE 1.0 END
    -- Boost de afinidad: mismo objetivo fitness
    * CASE WHEN pr.fitness_goal IS NOT NULL
                AND pr.fitness_goal = v.fitness_goal THEN 1.4 ELSE 1.0 END
    -- Boost de afinidad: misma ubicacion de entrenamiento
    * CASE WHEN pr.training_location IS NOT NULL
                AND pr.training_location = v.training_location THEN 1.2 ELSE 1.0 END
  ) DESC
  LIMIT  p_limit
  OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_ranked_feed(uuid, int, int) TO authenticated;


-- ============================================================
-- Mejora 2: Tabla post_views — tracking de duración de vista
-- Registra cuánto tiempo un usuario estuvo en cada post antes
-- de hacer swipe. Es la señal más honesta de interés real.
-- Se usa para la próxima iteración del algoritmo (Nivel 2).
-- ============================================================

CREATE TABLE IF NOT EXISTS public.post_views (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    uuid        NOT NULL REFERENCES public.posts(id)    ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  view_ms    int         NOT NULL CHECK (view_ms >= 0),
  viewed_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.post_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "post_views: insert own"
  ON public.post_views FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "post_views: select own"
  ON public.post_views FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_post_views_user    ON public.post_views(user_id, viewed_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_views_post    ON public.post_views(post_id);
