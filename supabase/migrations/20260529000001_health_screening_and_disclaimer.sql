-- Health screening (PAR-Q+ / SCOFF) y disclaimer de primera rutina/dieta.
-- Agrega columnas mínimas a profiles para que la IA y los reportes humanos
-- puedan adaptarse cuando el usuario reporta condiciones médicas o riesgo
-- alimentario detectado durante el onboarding.

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS disclaimer_accepted_at timestamptz,
  ADD COLUMN IF NOT EXISTS requires_medical_clearance boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS eating_disorder_risk boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS parq_answers jsonb,
  ADD COLUMN IF NOT EXISTS scoff_score smallint;

COMMENT ON COLUMN profiles.disclaimer_accepted_at IS
  'Timestamp en que el usuario aceptó el disclaimer de IA en rutina/alimentación. NULL = aún no aceptado.';
COMMENT ON COLUMN profiles.requires_medical_clearance IS
  'TRUE si el usuario respondió ≥1 Sí en PAR-Q+. Bandera para que la IA modere recomendaciones.';
COMMENT ON COLUMN profiles.eating_disorder_risk IS
  'TRUE si el usuario respondió ≥2 Sí en SCOFF. NUNCA mostrar al usuario, sólo informa a IA y nutri humano.';
COMMENT ON COLUMN profiles.parq_answers IS
  'JSON con las respuestas individuales del PAR-Q+ (keys = pregunta, value = bool).';
COMMENT ON COLUMN profiles.scoff_score IS
  'Score SCOFF (0..5). Sólo se guarda si el usuario pasó por el flujo. NUNCA mostrar al usuario.';
