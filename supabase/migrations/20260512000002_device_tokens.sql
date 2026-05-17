-- Mueve el FCM token de profiles a una tabla dedicada device_tokens con RLS propio.
-- En profiles, fcm_token era visible para cualquier usuario autenticado porque
-- la politica SELECT de profiles permite leer filas ajenas.
-- device_tokens tiene RLS "solo el dueno puede ver/modificar su propio token".

-- ============================================================
-- DEVICE TOKENS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.device_tokens (
  user_id    uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token  text        NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens: own only"
  ON public.device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Migrar tokens existentes en profiles a device_tokens (evita perder tokens activos)
INSERT INTO public.device_tokens (user_id, fcm_token, updated_at)
SELECT id, fcm_token, now()
FROM public.profiles
WHERE fcm_token IS NOT NULL
ON CONFLICT (user_id) DO UPDATE SET fcm_token = EXCLUDED.fcm_token, updated_at = now();

-- Eliminar la columna fcm_token de profiles (ya no debe ser accesible publicamente)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS fcm_token;
