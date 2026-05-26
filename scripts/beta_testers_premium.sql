-- ===========================================================================
-- BETA TESTERS — Asignar Premium manual hasta fin de Beta
-- ===========================================================================
-- Uso:
--   1. Reemplaza la lista de emails de abajo con tus testers reales.
--   2. Ajusta la fecha de expiración (default: 2026-08-31 = 3 meses Beta).
--   3. Ejecuta en Supabase Dashboard > SQL Editor (modo service role).
--
-- Esto NO toca RevenueCat — es un override manual del tier en la DB.
-- Cuando termine la Beta y se active RevenueCat, el webhook sobrescribirá
-- este tier al recibir compras reales (o quedará en 'free' al expirar).
-- ===========================================================================

-- ▼ EDITA AQUÍ: lista de emails de testers ▼
WITH beta_testers (email) AS (
  VALUES
    ('tester1@example.com'),
    ('tester2@example.com'),
    ('tester3@example.com')
    -- Añade más con coma:
    -- , ('tester4@example.com')
)
UPDATE profiles p
SET
  subscription_tier = 'premium',
  subscription_expires_at = '2026-08-31 23:59:59+00'::timestamptz
FROM auth.users u
JOIN beta_testers bt ON LOWER(u.email) = LOWER(bt.email)
WHERE p.id = u.id
RETURNING p.id, u.email, p.subscription_tier, p.subscription_expires_at;

-- ===========================================================================
-- VERIFICACIÓN — corre esto después para confirmar
-- ===========================================================================
-- SELECT u.email, p.subscription_tier, p.subscription_expires_at
-- FROM profiles p
-- JOIN auth.users u ON u.id = p.id
-- WHERE p.subscription_tier = 'premium'
-- ORDER BY p.subscription_expires_at DESC;

-- ===========================================================================
-- ROLLBACK — si necesitas revertir a free
-- ===========================================================================
-- UPDATE profiles SET subscription_tier='free', subscription_expires_at=NULL
-- WHERE id IN (
--   SELECT u.id FROM auth.users u
--   WHERE LOWER(u.email) IN ('tester1@example.com', 'tester2@example.com')
-- );
