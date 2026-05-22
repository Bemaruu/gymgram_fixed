-- ============================================================
-- Rankable exercises: marcar ejercicios populares como rankeables
-- y registrar su movement_pattern canonico en exercise_catalog.
-- Solo los ejercicios marcados aqui mostraran SetLoggerSheet en
-- la UI; el resto sigue siendo checkbox simple.
--
-- Tambien expande el CHECK de movement_pattern para soportar
-- biceps_curl y triceps_extension en set_logs / user_strength_records,
-- y refina calculate_strength_score para que los aislados de brazo
-- pesen al 40% (un curl de 30kg no equivale a un press de 100kg).
--
-- Idempotente. NO destruye datos.
-- ============================================================

-- ============================================================
-- 1) Flag counts_for_ranked + movement_pattern en exercise_catalog
-- ============================================================
ALTER TABLE public.exercise_catalog
  ADD COLUMN IF NOT EXISTS counts_for_ranked boolean NOT NULL DEFAULT false;

ALTER TABLE public.exercise_catalog
  ADD COLUMN IF NOT EXISTS movement_pattern text;

-- CHECK del movement_pattern del catalogo: idempotente
ALTER TABLE public.exercise_catalog
  DROP CONSTRAINT IF EXISTS exercise_catalog_movement_pattern_check;
ALTER TABLE public.exercise_catalog
  ADD CONSTRAINT exercise_catalog_movement_pattern_check
  CHECK (movement_pattern IS NULL OR movement_pattern IN
    ('push_horizontal','push_vertical','pull_horizontal','pull_vertical',
     'squat','hinge','biceps_curl','triceps_extension','other'));

CREATE INDEX IF NOT EXISTS idx_exercise_catalog_rankable
  ON public.exercise_catalog(counts_for_ranked)
  WHERE counts_for_ranked = true;

-- ============================================================
-- 2) Marcar ejercicios rankeables (solo los que existen en el seed)
-- ============================================================
-- PUSH HORIZONTAL (pecho)
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'push_horizontal'
 WHERE slug IN (
   'press-banca-barra',
   'press-inclinado-mancuernas',
   'press-declinado-barra',
   'press-pecho-maquina'
 );

-- PUSH VERTICAL (hombros)
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'push_vertical'
 WHERE slug IN (
   'press-militar-barra',
   'press-arnold-mancuernas',
   'press-hombros-maquina'
 );

-- SQUAT (cuadriceps dominantes)
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'squat'
 WHERE slug IN (
   'sentadilla-libre-barra',
   'sentadilla-smith',
   'hack-squat',
   'prensa-piernas-45',
   'sentadilla-bulgara',
   'goblet-squat'
 );

-- HINGE (cadena posterior)
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'hinge'
 WHERE slug IN (
   'peso-muerto-convencional',
   'peso-muerto-rumano-barra',
   'peso-muerto-rumano-mancuernas',
   'hip-thrust-barra',
   'good-mornings-barra'
 );

-- PULL VERTICAL (dominadas + jalones)
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'pull_vertical'
 WHERE slug IN (
   'dominadas-agarre-ancho',
   'chin-ups',
   'jalon-pecho-agarre-ancho',
   'jalon-agarre-neutro'
 );

-- PULL HORIZONTAL (remos)
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'pull_horizontal'
 WHERE slug IN (
   'remo-barra',
   'remo-mancuerna-unilateral',
   'remo-maquina-hammer',
   'remo-t-bar',
   'remo-pendlay'
 );

-- BICEPS CURL
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'biceps_curl'
 WHERE slug IN (
   'curl-barra-recta',
   'curl-barra-ez',
   'curl-mancuernas-alternado',
   'curl-martillo-mancuernas',
   'curl-concentrado',
   'curl-polea-baja'
 );

-- TRICEPS EXTENSION
UPDATE public.exercise_catalog
   SET counts_for_ranked = true, movement_pattern = 'triceps_extension'
 WHERE slug IN (
   'press-frances-ez',
   'extension-triceps-polea-cuerda',
   'extension-triceps-sobre-cabeza-polea',
   'fondos-paralelas'
 );

-- ============================================================
-- 3) Expandir CHECK constraints para incluir biceps_curl + triceps_extension
-- ============================================================
ALTER TABLE public.set_logs
  DROP CONSTRAINT IF EXISTS set_logs_movement_pattern_check;
ALTER TABLE public.set_logs
  ADD CONSTRAINT set_logs_movement_pattern_check
  CHECK (movement_pattern IN
    ('push_horizontal','push_vertical','pull_horizontal','pull_vertical',
     'squat','hinge','biceps_curl','triceps_extension','other'));

ALTER TABLE public.user_strength_records
  DROP CONSTRAINT IF EXISTS user_strength_records_movement_pattern_check;
ALTER TABLE public.user_strength_records
  ADD CONSTRAINT user_strength_records_movement_pattern_check
  CHECK (movement_pattern IN
    ('push_horizontal','push_vertical','pull_horizontal','pull_vertical',
     'squat','hinge','biceps_curl','triceps_extension','other'));

-- ============================================================
-- 4) Refinar calculate_strength_score: aislados de brazo cuentan al 40%
-- ============================================================
CREATE OR REPLACE FUNCTION public.calculate_strength_score(p_user_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender_coef numeric := 1.0;
  v_gender      text;
  v_score       numeric := 0;
BEGIN
  SELECT lower(coalesce(gender, '')) INTO v_gender
    FROM public.profiles WHERE id = p_user_id;

  IF v_gender IN ('female', 'mujer', 'f', 'nonbinary', 'no_binario', 'non_binary', 'nb', 'other') THEN
    v_gender_coef := 1.35;
  ELSE
    v_gender_coef := 1.0;
  END IF;

  -- Para cada movement_pattern del usuario tomamos el mejor e1rm/bodyweight.
  -- Aislados de brazo (biceps_curl, triceps_extension) y "other" pesan 0.4x,
  -- compuestos pesan 1.0x.
  WITH best_per_pattern AS (
    SELECT
      movement_pattern,
      MAX(
        (best_e1rm_kg /
          NULLIF(COALESCE(bodyweight_at_pr_kg,
                          (SELECT weight_kg FROM public.profiles WHERE id = p_user_id)
                         ), 0)
        ) * 100
      ) AS ratio
    FROM public.user_strength_records
    WHERE user_id = p_user_id
      AND best_e1rm_kg IS NOT NULL
    GROUP BY movement_pattern
  ),
  weighted AS (
    SELECT
      CASE
        WHEN movement_pattern IN ('biceps_curl','triceps_extension','other')
          THEN ratio * 0.4
        ELSE ratio
      END AS weighted_ratio
    FROM best_per_pattern
  )
  SELECT COALESCE(SUM(weighted_ratio), 0) INTO v_score FROM weighted;

  RETURN COALESCE(ROUND(v_score * v_gender_coef)::int, 0);
END;
$$;
