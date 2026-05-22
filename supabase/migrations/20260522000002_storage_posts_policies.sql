-- Politicas de storage para bucket 'posts': solo el propietario puede subir/borrar
-- El primer segmento del path debe ser el uid del usuario

-- Eliminar politicas previas si existen
DROP POLICY IF EXISTS "posts bucket: insert own" ON storage.objects;
DROP POLICY IF EXISTS "posts bucket: update own" ON storage.objects;
DROP POLICY IF EXISTS "posts bucket: delete own" ON storage.objects;

CREATE POLICY "posts bucket: insert own"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'posts'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "posts bucket: update own"
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'posts'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "posts bucket: delete own"
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'posts'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
