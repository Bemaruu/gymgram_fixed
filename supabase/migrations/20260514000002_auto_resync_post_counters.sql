-- Auto-resync de contadores cacheados de posts (likes_count, comments_count).
-- Los triggers fn_increment_likes/fn_decrement_likes mantienen consistencia
-- en tiempo real, pero ante eventos perdidos (likes anteriores al trigger,
-- escrituras manuales, fallos de la función) puede aparecer drift.
-- Este job corre cada 6h como red de seguridad.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.resync_post_counters()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Likes
  UPDATE posts p
  SET likes_count = COALESCE(c.cnt, 0)
  FROM (
    SELECT post_id, COUNT(*) AS cnt
    FROM likes
    GROUP BY post_id
  ) c
  WHERE p.id = c.post_id
    AND p.likes_count <> c.cnt;

  UPDATE posts
  SET likes_count = 0
  WHERE likes_count <> 0
    AND id NOT IN (SELECT DISTINCT post_id FROM likes);

  -- Comments
  UPDATE posts p
  SET comments_count = COALESCE(c.cnt, 0)
  FROM (
    SELECT post_id, COUNT(*) AS cnt
    FROM comments
    GROUP BY post_id
  ) c
  WHERE p.id = c.post_id
    AND p.comments_count <> c.cnt;

  UPDATE posts
  SET comments_count = 0
  WHERE comments_count <> 0
    AND id NOT IN (SELECT DISTINCT post_id FROM comments);
END;
$$;

REVOKE ALL ON FUNCTION public.resync_post_counters() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.resync_post_counters() TO postgres;

-- Programar cada 6 horas. Reemplaza si ya existe (idempotente).
SELECT cron.unschedule('resync_post_counters') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'resync_post_counters'
);
SELECT cron.schedule(
  'resync_post_counters',
  '0 */6 * * *',
  $cron$SELECT public.resync_post_counters();$cron$
);
