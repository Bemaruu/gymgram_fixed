-- Agrega media_url al catálogo de ejercicios
-- Fuente: yuhonas/free-exercise-db (Unlicense — dominio público, sin restricciones)
-- URL base: https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/

ALTER TABLE public.exercise_catalog ADD COLUMN IF NOT EXISTS media_url text;

-- PECHO
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press/0.jpg'            WHERE slug = 'press-banca-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Incline_Bench_Press/0.jpg'    WHERE slug = 'press-inclinado-mancuernas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Decline_Bench_Press/0.jpg'      WHERE slug = 'press-declinado-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crossover/0.jpg'                  WHERE slug = 'crossover-polea-alta';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Push_Up/0.jpg'                          WHERE slug = 'flexiones';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Decline_Push-Up/0.jpg'                  WHERE slug = 'flexiones-pies-elevados';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Close-Grip_Push-Up/0.jpg'               WHERE slug = 'flexiones-diamante';

-- ESPALDA
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pull-Up/0.jpg'                         WHERE slug = 'dominadas-agarre-ancho';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/0.jpg'           WHERE slug = 'jalon-pecho-agarre-ancho';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Close-Grip_Front_Lat_Pulldown/0.jpg'    WHERE slug = 'jalon-agarre-neutro';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/0.jpg'            WHERE slug = 'remo-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/One-Arm_Dumbbell_Row/0.jpg'             WHERE slug = 'remo-mancuerna-unilateral';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Inverted_Row/0.jpg'                     WHERE slug = 'australian-pull-ups';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Superman/0.jpg'                         WHERE slug = 'superman-brazos-extendidos';

-- HOMBROS
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Shoulder_Press/0.jpg'           WHERE slug = 'press-militar-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Arnold_Dumbbell_Press/0.jpg'            WHERE slug = 'press-arnold-mancuernas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/0.jpg'               WHERE slug = 'elevaciones-laterales-mancuernas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Front_Raise/0.jpg'             WHERE slug = 'elevaciones-frontales-mancuernas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Rear_Delt_Fly/0.jpg'                    WHERE slug = 'pajaros-mancuernas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Pike_Push-up/0.jpg'                     WHERE slug = 'flexiones-pike';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/0.jpg'                        WHERE slug = 'face-pulls-polea';

-- BÍCEPS
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/0.jpg'                     WHERE slug = 'curl-barra-recta';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/EZ-Bar_Curl/0.jpg'                      WHERE slug = 'curl-barra-ez';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Alternate_Dumbbell_Curl/0.jpg'          WHERE slug = 'curl-mancuernas-alternado';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hammer_Curls/0.jpg'                     WHERE slug = 'curl-martillo-mancuernas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Concentration_Curls/0.jpg'              WHERE slug = 'curl-concentrado';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Curl/0.jpg'                       WHERE slug = 'curl-polea-baja';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Zottman_Curl/0.jpg'                     WHERE slug = 'curl-zottman';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Chin-up/0.jpg'                          WHERE slug = 'chin-ups';

-- TRÍCEPS
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Triceps_Press/0.jpg'              WHERE slug = 'press-frances-ez';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown_-_Rope_Attachment/0.jpg' WHERE slug = 'extension-triceps-polea-cuerda';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Overhead_Cable_Tricep_Extension/0.jpg'  WHERE slug = 'extension-triceps-sobre-cabeza-polea';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Tricep_Version/0.jpg'            WHERE slug = 'fondos-paralelas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Tricep_Kickback/0.jpg'         WHERE slug = 'kickbacks-triceps-mancuerna';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Dips/0.jpg'                       WHERE slug = 'dips-entre-sillas';

-- CUÁDRICEPS
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/0.jpg'               WHERE slug = 'sentadilla-libre-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Smith_Machine_Squat/0.jpg'              WHERE slug = 'sentadilla-smith';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/0.jpg'                        WHERE slug = 'prensa-piernas-45';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hack_Squat/0.jpg'                       WHERE slug = 'hack-squat';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Extensions/0.jpg'                   WHERE slug = 'extension-cuadriceps';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bulgarian_Split_Squat/0.jpg'            WHERE slug = 'sentadilla-bulgara';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/0.jpg'                  WHERE slug = 'zancadas-caminando';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Goblet_Squat/0.jpg'                     WHERE slug = 'goblet-squat';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Jump_Squat/0.jpg'                       WHERE slug = 'sentadilla-salto';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Step_Ups/0.jpg'                 WHERE slug = 'step-ups-banco';

-- FEMORAL
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/0.jpg'                WHERE slug = 'peso-muerto-rumano-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Romanian_Deadlift/0.jpg'       WHERE slug = 'peso-muerto-rumano-mancuernas';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Lying_Leg_Curls/0.jpg'                  WHERE slug = 'curl-femoral-acostado';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Leg_Curl/0.jpg'                  WHERE slug = 'curl-femoral-sentado';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Good_Morning/0.jpg'                     WHERE slug = 'good-mornings-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Deadlift/0.jpg'                 WHERE slug = 'peso-muerto-convencional';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Single-Leg_Deadlift/0.jpg'              WHERE slug = 'peso-muerto-unipodal';

-- GLÚTEOS
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Hip_Thrust/0.jpg'               WHERE slug = 'hip-thrust-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Glute_Bridge/0.jpg'                     WHERE slug = 'puente-gluteos-barra';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hip_Abductor/0.jpg'                     WHERE slug = 'abductor-maquina';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Sumo_Squat/0.jpg'                       WHERE slug = 'sentadilla-sumo-mancuerna';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hip_Thrust/0.jpg'                       WHERE slug = 'hip-thrust-peso-corporal';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Donkey_Kicks/0.jpg'                     WHERE slug = 'kickback-cuadrupedia';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Fire_Hydrant/0.jpg'                     WHERE slug = 'fire-hydrant';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Clam/0.jpg'                             WHERE slug = 'clamshell';

-- PANTORRILLAS
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raise/0.jpg'              WHERE slug = 'elevacion-pantorrillas-maquina';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Calf_Raise/0.jpg'                WHERE slug = 'elevacion-pantorrillas-sentado';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Single-Leg_Calf_Raise/0.jpg'            WHERE slug = 'pantorrillas-pie-unipodal';

-- CORE
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Plank/0.jpg'                            WHERE slug = 'plancha-frontal';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Plank/0.jpg'                       WHERE slug = 'plancha-lateral';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Crunch/0.jpg'                     WHERE slug = 'crunch-polea';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Hanging_Leg_Raise/0.jpg'                WHERE slug = 'elevacion-piernas-colgado';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bicycle_Crunch/0.jpg'                   WHERE slug = 'crunch-bicicleta';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Mountain_Climbers/0.jpg'                WHERE slug = 'mountain-climbers';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dead_Bug/0.jpg'                         WHERE slug = 'dead-bug';
UPDATE public.exercise_catalog SET media_url = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Russian_Twist/0.jpg'                    WHERE slug = 'russian-twist';
