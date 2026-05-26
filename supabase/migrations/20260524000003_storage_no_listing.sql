-- ============================================================
-- public_bucket_allows_listing — buckets públicos (avatars, posts) no necesitan
-- política SELECT amplia sobre storage.objects: el acceso por getPublicUrl se
-- sirve por CDN sin pasar por RLS. La app NO usa storage.list() en ningún flujo,
-- así que eliminar estas políticas impide enumerar archivos sin afectar la carga
-- de media del feed/avatares. (2026-05-24)
-- ============================================================
DROP POLICY IF EXISTS "avatars_read_public"  ON storage.objects;
DROP POLICY IF EXISTS "posts_obj_read_auth"   ON storage.objects;
