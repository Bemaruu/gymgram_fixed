-- Corrección de media_url: nombres verificados contra yuhonas/free-exercise-db
-- Se corrigen nombres de carpeta incorrectos y se agregan los 17 que faltaban

-- BASE URL
-- https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/

-- ── CORRECCIONES (nombres de carpeta incorrectos → corrección) ──────────────

-- Pull-Up no existe; el más cercano que muestra el movimiento
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Band_Assisted_Pull-Up/0.jpg'
  WHERE slug = 'dominadas-agarre-ancho';

-- Standing_Calf_Raise → Standing_Calf_Raises (faltaba la s)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raises/0.jpg'
  WHERE slug = 'elevacion-pantorrillas-maquina';

-- Alternate_Dumbbell_Curl → nombre exacto verificado
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Alternate_Bicep_Curl/0.jpg'
  WHERE slug = 'curl-mancuernas-alternado';

-- Glute_Bridge → Barbell_Glute_Bridge
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Glute_Bridge/0.jpg'
  WHERE slug = 'puente-gluteos-barra';

-- Hip_Thrust no existe; usar Barbell_Hip_Thrust (misma mecánica)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Hip_Thrust/0.jpg'
  WHERE slug = 'hip-thrust-peso-corporal';

-- Overhead_Cable_Tricep_Extension no existe; usar Triceps_Pushdown
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown/0.jpg'
  WHERE slug = 'extension-triceps-sobre-cabeza-polea';

-- Triceps_Pushdown_-_Rope_Attachment no verificado; usar Triceps_Pushdown
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown/0.jpg'
  WHERE slug = 'extension-triceps-polea-cuerda';

-- Dips_-_Tricep_Version no existe; usar Bench_Dips
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Dips/0.jpg'
  WHERE slug = 'fondos-paralelas';

-- Rear_Delt_Fly no existe; nombre exacto verificado en el repo
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Dumbbell_Rear_Delt_Raise_With_Head_On_Bench/0.jpg'
  WHERE slug = 'pajaros-mancuernas';

-- Sumo_Squat no existe; usar Sumo_Deadlift (postura similar)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Sumo_Deadlift/0.jpg'
  WHERE slug = 'sentadilla-sumo-mancuerna';

-- Single-Leg_Calf_Raise no existe; usar Donkey_Calf_Raises
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Donkey_Calf_Raises/0.jpg'
  WHERE slug = 'pantorrillas-pie-unipodal';

-- Dumbbell_Romanian_Deadlift no existe; usar Romanian_Deadlift (misma mecánica)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/0.jpg'
  WHERE slug = 'peso-muerto-rumano-mancuernas';

-- Cable_Curl no existe con ese nombre; usar EZ-Bar_Curl (confirmado)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/EZ-Bar_Curl/0.jpg'
  WHERE slug = 'curl-polea-baja';

-- Donkey_Kicks no existe → Glute_Kickback (movimiento similar de glúteo)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Glute_Kickback/0.jpg'
  WHERE slug = 'kickback-cuadrupedia';

-- Ejercicios sin equivalente visual aceptable → null (mejor el ícono que una imagen incorrecta)
UPDATE public.exercise_catalog SET media_url = NULL WHERE slug IN (
  'kickbacks-triceps-mancuerna',  -- Dumbbell_Tricep_Kickback no existe
  'fire-hydrant',                  -- Fire_Hydrant no existe
  'clamshell',                     -- Clam no existe
  'abductor-maquina',              -- Hip_Abductor no existe
  'sentadilla-bulgara',            -- Bulgarian_Split_Squat no existe
  'sentadilla-salto',              -- Jump_Squat no existe
  'peso-muerto-unipodal',          -- Single-Leg_Deadlift no existe
  'crunch-bicicleta',              -- Bicycle_Crunch no existe
  'plancha-lateral',               -- Side_Plank no existe
  'flexiones-diamante',            -- Close-Grip_Push-Up no existe
  'flexiones-pike'                 -- Pike_Push-up no existe
);

-- ── NUEVOS MAPEOS (eran NULL) ────────────────────────────────────────────────

-- Pec deck → Butterfly (closest verified)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Butterfly/0.jpg'
  WHERE slug = 'aperturas-pec-deck';

-- Aperturas polea baja → Low_Cable_Crossover
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Low_Cable_Crossover/0.jpg'
  WHERE slug = 'aperturas-polea-baja';

-- Curl concentrado con botella → misma mecánica que Concentration_Curls
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Concentration_Curls/0.jpg'
  WHERE slug = 'curl-concentrado-botella';

-- Curl bíceps con mochila → misma mecánica que Barbell_Curl
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/0.jpg'
  WHERE slug = 'curl-biceps-mochila';

-- Elevaciones laterales con botellas → mismo movimiento
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/0.jpg'
  WHERE slug = 'elevaciones-laterales-botellas';

-- Extensión tríceps con botella → Lying_Triceps_Press (extensión overhead)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Triceps_Press/0.jpg'
  WHERE slug = 'extension-triceps-botella';

-- Fondos asistidos en máquina → Bench_Dips (más cercano disponible)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Dips/0.jpg'
  WHERE slug = 'fondos-asistidos-maquina';

-- Frog pumps → Barbell_Glute_Bridge (activación glútea similar)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Glute_Bridge/0.jpg'
  WHERE slug = 'frog-pumps';

-- Kickback en polea baja → Glute_Kickback (verificado en repo)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Glute_Kickback/0.jpg'
  WHERE slug = 'kickback-polea-baja';

-- Nordic curl modificado → Lying_Leg_Curls (femoral acostado similar)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Leg_Curls/0.jpg'
  WHERE slug = 'nordic-curl-modificado';

-- Pantorrillas en prensa → Donkey_Calf_Raises
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Donkey_Calf_Raises/0.jpg'
  WHERE slug = 'pantorrillas-prensa';

-- Press de hombros en máquina → Barbell_Shoulder_Press (más cercano)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Shoulder_Press/0.jpg'
  WHERE slug = 'press-hombros-maquina';

-- Press de pecho en máquina → Smith_Machine_Bench_Press (más cercano)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Smith_Machine_Bench_Press/0.jpg'
  WHERE slug = 'press-pecho-maquina';

-- Press overhead con botellas → Barbell_Shoulder_Press (mismo movimiento)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Shoulder_Press/0.jpg'
  WHERE slug = 'press-overhead-botellas';

-- Remo en máquina Hammer → Bent_Over_Two-Dumbbell_Row
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Two-Dumbbell_Row/0.jpg'
  WHERE slug = 'remo-maquina-hammer';

-- Remo en T-bar → Bent_Over_Two-Arm_Long_Bar_Row (verificado en repo)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Two-Arm_Long_Bar_Row/0.jpg'
  WHERE slug = 'remo-t-bar';

-- Remo Pendlay → Bent_Over_Barbell_Row (misma mecánica)
UPDATE public.exercise_catalog
  SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/0.jpg'
  WHERE slug = 'remo-pendlay';
