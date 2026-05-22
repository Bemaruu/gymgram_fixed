-- Algoritmo de ranking del feed de GymGram
--
-- Score por post = engagement × time_decay × social_boost
--   engagement   = likes×1 + comments×3 + saves×5 + 1 (base para posts nuevos sin interacciones)
--   time_decay   = e^(-0.693 × horas / 24)  →  half-life de 24 h (pierde 50% cada día)
--   social_boost = 2.0 si el viewer sigue al autor, 1.0 si no

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
  WITH saves AS (
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
  LEFT   JOIN saves    s ON s.post_id        = p.id
  LEFT   JOIN followed f ON f.following_id   = p.user_id
  ORDER  BY (
    (p.likes_count * 1.0 + p.comments_count * 3.0 + COALESCE(s.saves_count, 0) * 5.0 + 1.0)
    * EXP(-0.693 * EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 86400.0)
    * CASE WHEN f.following_id IS NOT NULL THEN 2.0 ELSE 1.0 END
  ) DESC
  LIMIT  p_limit
  OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION public.get_ranked_feed(uuid, int, int) TO authenticated;
