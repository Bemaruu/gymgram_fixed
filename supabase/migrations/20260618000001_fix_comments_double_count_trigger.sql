-- Bug: la tabla comments tenía DOS triggers de INSERT/DELETE incrementando
-- comments_count (on_comment_insert/on_comment_delete via fn_*_comments  Y
-- trg_sync_comments_count via sync_comments_count). Cada comentario contaba
-- como 2. Dejamos solo el par fn_increment_comments/fn_decrement_comments
-- (simétrico con likes: on_like_insert/on_like_delete) y eliminamos el
-- trigger+función redundante.
DROP TRIGGER IF EXISTS trg_sync_comments_count ON public.comments;
DROP FUNCTION IF EXISTS public.sync_comments_count();

-- Red de seguridad: también dropear el viejo trigger/función de likes que
-- nunca debió coexistir con fn_*_likes (no está activo hoy, pero idempotente).
DROP TRIGGER IF EXISTS trg_sync_likes_count ON public.likes;
DROP FUNCTION IF EXISTS public.sync_post_likes_count();

-- Resync de drift existente (likes y comments) a partir de las filas reales.
UPDATE public.posts p
SET likes_count = COALESCE((SELECT count(*) FROM public.likes l WHERE l.post_id = p.id), 0),
    comments_count = COALESCE((SELECT count(*) FROM public.comments c WHERE c.post_id = p.id), 0)
WHERE p.likes_count    <> COALESCE((SELECT count(*) FROM public.likes l WHERE l.post_id = p.id), 0)
   OR p.comments_count <> COALESCE((SELECT count(*) FROM public.comments c WHERE c.post_id = p.id), 0);
