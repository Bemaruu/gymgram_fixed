-- 20260607000006_exercise_contraindications_enrichment.sql
-- Enriquecimiento del catalogo con respaldo profesional CITADO (IronCoach 2026-06-07).
-- Fuentes: ACOG (embarazo), AAOS/OrthoInfo (rodilla/hombro), ACSM + AHA/Circulation
-- (hipertension/cardiaco/Valsalva), S. McGill / U. Waterloo (lumbar/core),
-- Physiopedia (cervical), NSCA (progresion por nivel). Ver doc
-- docs/respaldo_clinico_ejercicios.md para citas completas y URLs.
--
-- Vocabulario controlado cerrado (sin tildes): lumbar, rodilla, hombro, cervical,
-- muneca, embarazo, hipertension, cardiaco. NO se introducen valores nuevos.
-- UPDATE por slug (idempotente, no depende de UUID generado).

BEGIN;

-- ============================================================================
-- PARTE A) CORRECCIONES de contraindicaciones (falsos negativos de seguridad)
-- ============================================================================

-- Carga axial pesada + maniobra de Valsalva -> picos extremos de TA.
-- Faltaba 'cardiaco' (ACSM Hypertension; AHA Circulation, Resistance Exercise in CVD).
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','cardiaco','embarazo']::text[]
  WHERE slug = 'hip-thrust-barra';
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','cardiaco','embarazo']::text[]
  WHERE slug = 'puente-gluteos-barra';
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','cardiaco','embarazo']::text[]
  WHERE slug = 'remo-barra';
-- Mismo mecanismo: faltaban 'hipertension' y 'cardiaco'.
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','cardiaco','embarazo']::text[]
  WHERE slug = 'remo-t-bar';

-- Flexion lumbar dinamica repetida (mecanismo n.1 de hernia discal, McGill).
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','lumbar','embarazo']::text[]
  WHERE slug = 'elevacion-piernas-colgado'; -- faltaba 'embarazo'
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','cervical','embarazo']::text[]
  WHERE slug = 'toe-touches'; -- faltaba 'cervical' (tiron de cuello)

-- Impacto / pivotes / trauma (ACOG embarazo; AAOS muneca por agarre/impacto).
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','hombro','cardiaco','embarazo']::text[]
  WHERE slug = 'artes-marciales'; -- faltaba 'embarazo'
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','muneca','embarazo']::text[]
  WHERE slug = 'escalada-indoor'; -- faltaba 'muneca' (carga de agarre)
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','muneca','cardiaco','embarazo']::text[]
  WHERE slug = 'boxeo-recreativo'; -- faltaba 'embarazo'

-- Brazos sobre cabeza con carga: conservador en embarazo por bracing/Valsalva.
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo']::text[]
  WHERE slug = 'crossover-polea-alta'; -- faltaba 'embarazo'

-- Isometria sostenida prolongada eleva la TA (ACSM). Wall sit -> agregar 'hipertension'.
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','hipertension']::text[]
  WHERE slug = 'sentadilla-pared-isometrica'; -- faltaba 'hipertension'

-- ============================================================================
-- PARTE B) EJERCICIOS NUEVOS de rehabilitacion / poblacion lesionada
-- Contraindicaciones MINIMAS a proposito: estos son las alternativas SEGURAS,
-- por eso permanecen disponibles para la zona que rehabilitan (la edge
-- generate-routine solo excluye lo etiquetado, asi que sin etiqueta = ofrecible
-- al usuario lesionado).
-- ============================================================================

INSERT INTO exercise_catalog
  (name_es, slug, muscle_group_primary, muscle_group_secondary, location, equipment,
   exercise_type, difficulty, tips, contraindications, counts_for_ranked,
   is_match_eligible, is_active)
VALUES
  -- LUMBAR / CORE (McGill Big 3 + movilidad segura)
  ('Curl-up de McGill', 'curl-up-mcgill', 'Core', '{}', 'both', ARRAY['cuerpo','toalla'],
   'estabilizacion', 'principiante',
   'Manos bajo la zona lumbar, una rodilla flexionada; eleva solo cabeza y hombros sin aplanar la espalda. Columna neutra.',
   ARRAY['embarazo']::text[], false, false, true),
  ('Plancha de antebrazos', 'plancha-antebrazos', 'Core', '{}', 'both', ARRAY['cuerpo','colchoneta'],
   'estabilizacion', 'principiante',
   'Sobre antebrazos para descargar las munecas; columna neutra y gluteos activos. Alternativa a la plancha en manos.',
   ARRAY['embarazo']::text[], false, false, true),
  ('Inclinacion pelvica supina', 'pelvic-tilt', 'Core', '{}', 'both', ARRAY['cuerpo','colchoneta'],
   'estabilizacion', 'principiante',
   'Bascula suave de la pelvis presionando la lumbar contra el suelo; movilidad lumbar segura y de bajo riesgo.',
   ARRAY[]::text[], false, false, true),
  ('Cat-camel (movilidad de columna)', 'cat-camel', 'Lumbar', '{}', 'both', ARRAY['cuerpo','colchoneta'],
   'estabilizacion', 'principiante',
   'En cuadrupedia alterna flexion y extension suave de la columna. Movilidad (no fuerza); reduce rigidez. McGill lo usa de calentamiento.',
   ARRAY[]::text[], false, false, true),

  -- RODILLA (AAOS Knee Conditioning)
  ('Isometrico de cuadriceps (quad set)', 'quad-set-isometrico', 'Cuádriceps', '{}', 'both', ARRAY['cuerpo'],
   'estabilizacion', 'principiante',
   'Pierna estirada, aprieta el cuadriceps contra el suelo 5 segundos. Sin dolor articular. Base de rehab de rodilla.',
   ARRAY[]::text[], false, false, true),
  ('Extension terminal de rodilla con banda', 'terminal-knee-extension-banda', 'Cuádriceps', '{}', 'both', ARRAY['banda elastica'],
   'aislamiento', 'principiante',
   'Banda detras de la rodilla; extiende los ultimos grados de forma controlada. Refuerza el VMO sin rango profundo.',
   ARRAY[]::text[], false, false, true),
  ('Elevacion de pierna recta', 'straight-leg-raise', 'Cuádriceps', '{}', 'both', ARRAY['cuerpo','colchoneta'],
   'aislamiento', 'principiante',
   'Rodilla extendida, eleva 15-20 cm manteniendo la lumbar apoyada. Fortalece cuadriceps sin cargar la articulacion.',
   ARRAY['lumbar']::text[], false, false, true),
  ('Step-down controlado', 'step-down-controlado', 'Cuádriceps', '{}', 'both', ARRAY['escalón'],
   'compuesto', 'intermedio',
   'Baja lento desde un escalon bajo con la rodilla alineada sobre el pie, sin colapso en valgo. Control excentrico.',
   ARRAY[]::text[], false, false, true),

  -- HOMBRO (AAOS Rotator Cuff)
  ('Rotacion externa de hombro con banda', 'rotacion-externa-banda', 'Hombros', '{}', 'both', ARRAY['banda elastica'],
   'aislamiento', 'principiante',
   'Codo pegado al costado a 90 grados; rota el antebrazo hacia afuera. Trabaja infraespinoso y redondo menor.',
   ARRAY[]::text[], false, false, true),
  ('Pendulares de Codman', 'pendulares-codman', 'Hombros', '{}', 'both', ARRAY['cuerpo'],
   'estabilizacion', 'principiante',
   'Inclinado apoyando un brazo, deja colgar el otro y haz circulos pequenos por gravedad, sin contraer. Fase temprana.',
   ARRAY[]::text[], false, false, true),
  ('Wall slides (deslizamiento en pared)', 'wall-slides', 'Hombros', '{}', 'both', ARRAY['pared'],
   'estabilizacion', 'principiante',
   'Antebrazos en la pared; desliza hacia arriba dentro del rango sin dolor. Mejora el ritmo escapulohumeral.',
   ARRAY[]::text[], false, false, true),
  ('Scaption con mancuernas', 'scaption-mancuernas', 'Hombros', '{}', 'both', ARRAY['mancuernas'],
   'aislamiento', 'principiante',
   'Pulgares arriba, eleva en el plano escapular (30 grados) hasta la altura del hombro. Fase avanzada de rehab; rango sin dolor.',
   ARRAY['hombro']::text[], false, false, true),

  -- CERVICAL (Physiopedia / flexores cervicales profundos)
  ('Retraccion cervical (chin tucks)', 'chin-tucks-cervical', 'Cuello', '{}', 'both', ARRAY['cuerpo'],
   'estabilizacion', 'principiante',
   'Retrae el menton en horizontal sin extender el cuello. Activa los flexores cervicales profundos.',
   ARRAY[]::text[], false, false, true),
  ('Isometrico cervical multidireccional', 'isometrico-cervical', 'Cuello', '{}', 'both', ARRAY['cuerpo'],
   'estabilizacion', 'principiante',
   'Empuja la cabeza contra tu mano sin que haya movimiento, 10 segundos por direccion. Fortalece sin rango.',
   ARRAY[]::text[], false, false, true),

  -- FEMORAL / patron seguro
  ('Bisagra de cadera con baston', 'hip-hinge-baston', 'Femoral', '{}', 'both', ARRAY['baston'],
   'estabilizacion', 'principiante',
   'Baston tocando cabeza, dorsal y sacro; lleva la cadera atras manteniendo el contacto (neutro). Ensena el patron antes de cargar.',
   ARRAY[]::text[], false, false, true),

  -- PECHO (muneca neutra)
  ('Flexion con apoyo neutro de muneca', 'flexion-mango-neutro', 'Pecho', '{}', 'both', ARRAY['soportes para flexiones','mancuernas'],
   'compuesto', 'principiante',
   'Usa soportes o mancuernas para mantener la muneca neutra; evita la extension dolorosa. Alternativa a la flexion clasica.',
   ARRAY['hombro','embarazo']::text[], false, false, true),

  -- CARDIO bajo impacto
  ('Aquagym / caminata acuatica', 'aquagym', 'Cardio', '{}', 'gym', ARRAY['piscina'],
   'cardio', 'principiante',
   'Cardio sin impacto; la flotacion descarga rodilla y columna. Seguro en embarazo e hipertension leve controlada.',
   ARRAY[]::text[], false, false, true),
  ('Eliptica', 'eliptica', 'Cardio', '{}', 'gym', ARRAY['eliptica'],
   'cardio', 'principiante',
   'Cardio de bajo impacto; alternativa a correr para cuidar la rodilla. Progresa la intensidad de forma gradual.',
   ARRAY[]::text[], false, false, true)
ON CONFLICT (slug) DO NOTHING;

COMMIT;
