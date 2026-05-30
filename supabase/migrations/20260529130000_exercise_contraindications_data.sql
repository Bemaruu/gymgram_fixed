-- 20260529130000_exercise_contraindications_data.sql
-- Clasificacion biomecanica conservadora de contraindicaciones por ejercicio.
-- Valores validos del CHECK: lumbar, rodilla, hombro, cervical, muneca, embarazo, hipertension, cardiaco
-- Solo se actualizan ejercicios con AL MENOS una contraindicacion.
-- Los seguros conservan el default (array vacio).
-- Criterio aplicado por IronCoach (2026-05-29) basado en ACSM/NSCA + consenso clinico.

BEGIN;

-- ============ BICEPS ============
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = 'eed5da6d-ce71-4f1b-bd66-543f00fa7b5e'; -- Chin-ups

-- ============ CADENA POSTERIOR ============
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','embarazo','cardiaco']::text[] WHERE id = 'da89d5e6-e048-4081-a396-b08b3d2f9b02'; -- Peso muerto convencional

-- ============ CARDIO ============
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','embarazo']::text[] WHERE id = '7a1e760d-b8cb-4bdf-998c-bedef4feb3ee'; -- Burpees
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','embarazo']::text[] WHERE id = '397f3292-5b03-4d84-a706-efd0bb442df4'; -- High knees
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','embarazo']::text[] WHERE id = '5ff04ea3-bd76-4ecc-b9eb-38e4c5cf8b99'; -- Jumping jacks
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','embarazo']::text[] WHERE id = 'ee3d95d2-421a-443a-b9cf-d293769bdc8c'; -- Correr
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','embarazo']::text[] WHERE id = 'f52d89b3-8503-4279-81d8-fd53ad9d620e'; -- Saltar la cuerda
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','hipertension','embarazo']::text[] WHERE id = 'dc10f055-621d-423d-8125-889618490dc7'; -- Sprints
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','embarazo']::text[] WHERE id = '6c216bf6-682f-483f-9f72-8e6063fc385f'; -- Subir escaleras

-- ============ CORE ============
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','embarazo']::text[] WHERE id = 'cca49370-82e2-48f8-a7d4-3043c3498f38'; -- Bear crawl
UPDATE exercise_catalog SET contraindications = ARRAY['cervical','lumbar','embarazo']::text[] WHERE id = '8c6e9394-97d9-4015-98cc-870d403765ca'; -- Crunch bicicleta
UPDATE exercise_catalog SET contraindications = ARRAY['cervical','lumbar','embarazo']::text[] WHERE id = '47312982-714e-4c52-a0c5-785b4556e40e'; -- Crunch en polea
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','lumbar']::text[] WHERE id = 'bd1fa494-5c2b-4336-909d-994d435d8ed8'; -- Elevacion piernas colgado
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '71e50e77-f8d8-4751-80b4-51b62560b694'; -- Hollow hold
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','rodilla','cardiaco','embarazo']::text[] WHERE id = 'bb8df2cb-29b8-439c-b1f2-fc9403a725de'; -- Mountain climbers
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro','embarazo']::text[] WHERE id = '89471d38-de91-4826-b562-ddf59281f111'; -- Plancha elevacion pierna
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','embarazo']::text[] WHERE id = 'f2e6c554-4717-4d59-9708-cebb81e7aea7'; -- Plancha frontal
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo']::text[] WHERE id = 'f8be591d-5f18-4327-9c3b-2010ae30dded'; -- Plancha lateral
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro','embarazo']::text[] WHERE id = '9162ad8b-9d5e-412e-9514-29533beb2554'; -- Plank shoulder taps
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '0d7d3be9-63c1-4333-8e09-53205dd94932'; -- Reverse crunch
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = 'd4a48111-1007-49de-afd2-4bd1615d09d0'; -- Russian twist
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '8202867f-ada6-45e4-a8a1-14bc55dc3425'; -- Toe touches
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','cervical','embarazo']::text[] WHERE id = 'aee0868b-486c-40c5-b9d7-4bc5d1395c12'; -- V-ups

-- ============ CUADRICEPS ============
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla']::text[] WHERE id = '12dc52b7-571c-4a95-9436-5195b2614af7'; -- Extension cuadriceps
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla']::text[] WHERE id = '150b5d9f-329e-46b7-b0bc-470d418febc9'; -- Hack squat
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','lumbar']::text[] WHERE id = '9f2cf8c2-ccea-432f-94c5-4465448cea93'; -- Prensa 45
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla']::text[] WHERE id = '57cfbaf9-8b88-4670-8cfa-a859679a692c'; -- Sentadilla bulgara
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','embarazo']::text[] WHERE id = '5d7bb73b-8d8d-4d47-954e-839d6195e3d9'; -- Sentadilla con salto
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','lumbar']::text[] WHERE id = '95d01080-88a2-4469-98fb-498ecd508558'; -- Sentadilla Smith
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','rodilla','hipertension','embarazo','cardiaco']::text[] WHERE id = '60c6ebe6-9f32-4c89-af0c-8245175c3b74'; -- Sentadilla libre con barra
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla']::text[] WHERE id = 'e68e41a0-346b-40cc-9532-d1a4eca155d8'; -- Sentadilla pared isometrica
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla']::text[] WHERE id = 'a910c1eb-09a1-4b2d-8925-e4467bf5bfa9'; -- Pistol asistida

-- ============ DEPORTES ============
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','hombro','cardiaco']::text[] WHERE id = '4bbce251-7f8f-4436-93a7-8d7e8dd0cdf3'; -- Artes marciales
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','embarazo']::text[] WHERE id = '5260bfbf-58ad-46da-bbd1-00e675a091da'; -- Basquetbol
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','muneca','cardiaco']::text[] WHERE id = '728c674b-e6ff-4656-803b-b1592ac3534c'; -- Boxeo recreativo
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo']::text[] WHERE id = 'd2272046-855f-4a4d-9321-955e1d02164c'; -- Escalada indoor
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','embarazo']::text[] WHERE id = 'c766db1f-31a3-47f9-9991-f80f91377275'; -- Futbol
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','cardiaco','embarazo']::text[] WHERE id = '5c3d7d2f-5d75-4a4e-bab4-9fc57c2a5933'; -- Patinaje
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','rodilla','cardiaco']::text[] WHERE id = '84432dc7-dd26-4966-964d-a3f3168431b4'; -- Tenis
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla','hombro','embarazo']::text[] WHERE id = 'd5b4d3c7-5718-4484-8043-9fa078070f2f'; -- Voleibol

-- ============ ESPALDA ============
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '9fb198a2-8647-441a-b23c-ad3f9e4764c4'; -- Australian pull-ups
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '45a546cc-f917-49f8-97f7-ffb12e59238c'; -- Dominadas agarre ancho
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','embarazo']::text[] WHERE id = '8eda7daa-18a8-41c5-88d9-7a155b8d4dc5'; -- Remo con barra
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = 'd539c7a4-5c05-4063-b83d-85520fd896bf'; -- Remo mancuerna unilateral
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '471ccf38-99c6-4453-9150-09dc6efedb94'; -- Remo con mochila
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '9e658e10-7c02-46b1-832f-3a958f700c74'; -- Remo con toalla en puerta
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = 'ed1bf80e-8f17-4943-817d-aeb9b9fc27bc'; -- Remo T-bar
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo']::text[] WHERE id = 'aef316cb-4a82-4c33-a877-c1670ff1bb0b'; -- Remo invertido bajo mesa
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','embarazo','cardiaco']::text[] WHERE id = 'ecb68257-dfaf-46f7-b380-44cc74d10201'; -- Remo Pendlay
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '01a7bd8c-80a3-4bbf-b89e-ff67968951db'; -- Remo unilateral mochila

-- ============ FEMORAL ============
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = 'b83d5b5a-84d5-4e0e-8792-78a86ce046f5'; -- Buenos dias con mochila
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla']::text[] WHERE id = '3d555bd1-ba71-4529-aa38-f73d15afd3d1'; -- Nordic curl asistido
UPDATE exercise_catalog SET contraindications = ARRAY['rodilla']::text[] WHERE id = 'fc176ebe-4196-463f-a266-88a8da9615c7'; -- Nordic curl modificado
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '660466e8-f4b9-4e62-a43b-16f75ec50742'; -- Peso muerto con mochila
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','embarazo','cardiaco']::text[] WHERE id = 'be92b312-fbfa-42d5-8870-93a59beba053'; -- PM rumano con barra
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '11ad9fee-bb26-4632-b893-4fb5aea562e3'; -- PM rumano mancuernas
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '2cbab09c-3d9e-4a59-9618-7e1276796e3b'; -- PM unipodal

-- ============ GLUTEOS ============
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','embarazo']::text[] WHERE id = 'a31e0aed-3c7d-499c-ad5b-1cebddbc2762'; -- Hip thrust con barra
UPDATE exercise_catalog SET contraindications = ARRAY['embarazo']::text[] WHERE id = 'ac11f11a-cb58-4840-a15d-9f4186b9d839'; -- Hip thrust peso corporal
UPDATE exercise_catalog SET contraindications = ARRAY['embarazo']::text[] WHERE id = 'a1bc9511-5c66-49f6-86c3-edcaef6aeb53'; -- Hip thrust en sofa
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','embarazo']::text[] WHERE id = '4fbc22c4-260c-4a1c-bf28-a201eeb7e515'; -- Frog pumps
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','embarazo']::text[] WHERE id = 'b5b732ba-dcb2-4443-a154-6b82f3d9e504'; -- Puente gluteos con barra
UPDATE exercise_catalog SET contraindications = ARRAY['embarazo']::text[] WHERE id = '43e888f6-1eea-4ef6-863a-6ff16ac59376'; -- Puente unilateral

-- ============ HOMBROS ============
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '51437135-674a-45b8-987b-499fbbb52d5d'; -- Elev frontales botellas
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '8cb13c72-df75-4fa0-86aa-4ad5736050fb'; -- Elev frontales mancuernas
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '74c3d36e-1f75-45b1-84c7-bb2bc62f0f23'; -- Elev laterales botellas
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = 'b120b83a-25af-4475-8d11-c6996f293241'; -- Elev laterales mancuernas
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro','embarazo']::text[] WHERE id = '35989f5c-79c7-4502-9703-bea3e1a0a9b6'; -- Flexiones pike
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','muneca','cervical','hipertension','cardiaco','embarazo']::text[] WHERE id = '807a61c0-ac05-43c2-9ffa-37d910e3c58c'; -- Handstand hold
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = 'de6708f7-5fc7-4206-b5d8-da1ba8b85383'; -- Press Arnold mancuernas
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '25bcace2-611e-4012-9c02-3f23382e6a60'; -- Press hombros maquina
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','lumbar','hipertension','embarazo','cardiaco']::text[] WHERE id = '255b1ea1-5443-4e76-9ae6-28b2ef3b9678'; -- Press militar con barra
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','lumbar']::text[] WHERE id = '70d4c9b4-6e2a-41ce-a1d3-247d997fd1b9'; -- Press militar mochila
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '04814612-420c-4970-9c97-d5288fd2d9ae'; -- Press overhead botellas
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','muneca','cervical','hipertension','cardiaco','embarazo']::text[] WHERE id = '0e7fdbba-9fd8-4ab2-9561-01ee8c432f85'; -- Wall walks

-- ============ LUMBAR ============
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '84d28922-d9b9-43e8-9191-7c761668b81a'; -- Buenos dias peso corporal
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = '5160c8d4-4564-4a5f-a2b3-486356c64f2f'; -- Cobra hold
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','hipertension','embarazo','cardiaco']::text[] WHERE id = 'b1e65163-b367-492b-8312-7abd8d77e80a'; -- Good mornings con barra
UPDATE exercise_catalog SET contraindications = ARRAY['lumbar','embarazo']::text[] WHERE id = 'aac216b0-72b1-4caf-8ec1-b05839589206'; -- Superman

-- ============ PECHO ============
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '6742f3d8-dcb5-4d99-8ca2-2a6c4b1bc9ba'; -- Aperturas botellas
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '26f3fab2-b5f3-44b5-a9ca-834f818d1278'; -- Pec deck
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = 'a09c3c66-ab6f-4726-937c-8ac42d89753c'; -- Aperturas polea baja
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '85908a00-9ffd-44aa-961e-0be931b6f7bf'; -- Crossover polea alta
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro']::text[] WHERE id = '92e6f043-4d4f-4ea9-b739-dd8abc617de6'; -- Flexiones
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro']::text[] WHERE id = '46dde20d-67a0-4ac9-864c-01e2f2e8d542'; -- Flexiones abiertas
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro']::text[] WHERE id = '7414c4d0-88b3-455c-b2a9-a30b01b4d977'; -- Flexiones archer
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro']::text[] WHERE id = '5c85c5bf-2685-4fcf-b9a8-6493a4ad2791'; -- Flexiones con pausa
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro']::text[] WHERE id = '99889779-7304-49a9-9534-38639531f6bc'; -- Flexiones pies elevados
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','hipertension','embarazo','cardiaco']::text[] WHERE id = 'a2977ded-2a59-4d41-bff4-58b2120e7e50'; -- Press de banca con barra
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo']::text[] WHERE id = '897f9d8d-6940-4d6b-b4a2-3fa834f3a6fe'; -- Press pecho mochila
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo']::text[] WHERE id = '165b8181-6a8d-4497-8ba0-9a11b8f0fd3f'; -- Press pecho maquina
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo','hipertension']::text[] WHERE id = 'f1d15a23-6774-4563-b32d-823c470a2076'; -- Press declinado barra
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','embarazo']::text[] WHERE id = '9b7cec55-27ca-4fa7-b50e-dcc3e7c69c1d'; -- Press inclinado mancuernas

-- ============ TRICEPS ============
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','muneca']::text[] WHERE id = '9cc30e64-83a6-4a3b-b101-96a0eaf42f3e'; -- Dips entre sillas
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro']::text[] WHERE id = '3e3d6a8a-0e16-4bbb-af90-e2a13e3d4120'; -- Flexiones cerradas
UPDATE exercise_catalog SET contraindications = ARRAY['muneca','hombro']::text[] WHERE id = '2c11cf1a-21ac-428e-a0b4-76014386e764'; -- Flexiones diamante
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '671fce75-afb9-4260-a69a-bbf0528dda7f'; -- Fondos asistidos maquina
UPDATE exercise_catalog SET contraindications = ARRAY['hombro','muneca']::text[] WHERE id = '0382944b-c488-4bff-974c-78e40f4ea9ec'; -- Fondos en banco
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = 'a376703d-92fe-425a-a527-8ef25cd7a38c'; -- Fondos paralelas
UPDATE exercise_catalog SET contraindications = ARRAY['hombro']::text[] WHERE id = '6f18acf2-3c06-420f-abad-b07734315460'; -- Press frances EZ

COMMIT;
