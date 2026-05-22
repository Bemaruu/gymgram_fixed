-- Pruebas por foto para medallas que requieren confirmacion (Conquistador/cerro,
-- Runner/5K, Renacido/cambio fisico). La verificacion la hace la edge function
-- verify-medal-photo con GPT-4o vision; si aprueba, otorga la medalla con service role.

-- ============================================================
-- 1) Tabla medal_submissions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.medal_submissions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  badge_id    text NOT NULL,
  image_path  text NOT NULL,            -- path en el bucket privado medal-proofs
  status      text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','approved','rejected')),
  ai_verdict  boolean,                  -- true = aprobada por IA
  ai_reason   text,                     -- explicacion corta del veredicto
  created_at  timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_medal_submissions_user
  ON public.medal_submissions(user_id, created_at DESC);

ALTER TABLE public.medal_submissions ENABLE ROW LEVEL SECURITY;

-- El usuario ve y crea sus propias solicitudes. El cambio de status/veredicto lo
-- hace solo la edge function (service role bypassa RLS).
DROP POLICY IF EXISTS "medal_submissions: select own" ON public.medal_submissions;
CREATE POLICY "medal_submissions: select own"
  ON public.medal_submissions FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "medal_submissions: insert own" ON public.medal_submissions;
CREATE POLICY "medal_submissions: insert own"
  ON public.medal_submissions FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid() AND status = 'pending');

-- ============================================================
-- 2) Bucket privado para las fotos de prueba
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('medal-proofs', 'medal-proofs', false)
ON CONFLICT (id) DO NOTHING;

-- El usuario sube y lee solo sus propios archivos: medal-proofs/{uid}/...
DROP POLICY IF EXISTS "medal-proofs: insert own" ON storage.objects;
CREATE POLICY "medal-proofs: insert own"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'medal-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "medal-proofs: select own" ON storage.objects;
CREATE POLICY "medal-proofs: select own"
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'medal-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
