-- Enriquecimiento del catalogo para casa, cardio y deportes.
-- Idempotente: actualiza por slug si el ejercicio ya existe.

insert into public.exercise_catalog
  (name_es, slug, muscle_group_primary, muscle_group_secondary, location, equipment, exercise_type, difficulty, tips)
values
-- PECHO EN CASA
('Flexiones inclinadas', 'flexiones-inclinadas', 'Pecho', '{"Tríceps","Hombros"}', 'home', '{"silla","mesa firme","banco"}', 'compuesto', 'principiante', 'Ejercicio de empuje para casa. Recomendado para principiantes o usuarios que aun no dominan flexiones completas. Mantener abdomen activo, cuerpo en linea y manos apoyadas en una superficie estable.'),
('Flexiones abiertas', 'flexiones-abiertas', 'Pecho', '{"Hombros","Tríceps"}', 'home', '{"cuerpo"}', 'compuesto', 'intermedio', 'Variante de flexion para enfatizar pecho. Requiere controlar una flexion normal. Evitar abrir demasiado los codos y mantener el tronco firme.'),
('Flexiones con pausa', 'flexiones-con-pausa', 'Pecho', '{"Tríceps","Core"}', 'home', '{"cuerpo"}', 'compuesto', 'intermedio', 'Flexion con pausa de 1 a 2 segundos abajo para aumentar control y tension. Util para usuarios con buena tecnica basica.'),
('Flexiones archer', 'flexiones-archer', 'Pecho', '{"Tríceps","Hombros","Core"}', 'home', '{"cuerpo"}', 'compuesto', 'avanzado', 'Variante unilateral asistida. Exige fuerza alta de pecho, hombro y core. Recomendar solo si el usuario domina flexiones estrictas.'),
('Press de pecho con mochila', 'press-pecho-mochila', 'Pecho', '{"Tríceps","Hombros"}', 'home', '{"mochila cargada","piso o colchoneta"}', 'compuesto', 'principiante', 'Alternativa casera al press. Acostado en el piso, empujar una mochila cargada de forma controlada. Ajustar peso con libros o botellas.'),
('Aperturas de pecho con botellas', 'aperturas-pecho-botellas', 'Pecho', '{"Hombros"}', 'home', '{"2 botellas","piso o colchoneta"}', 'aislamiento', 'principiante', 'Aislamiento de pecho de baja carga. Hacer rango corto y controlado, con codos levemente flexionados. No usar si molesta el hombro.'),

-- ESPALDA EN CASA
('Remo con mochila', 'remo-con-mochila', 'Espalda', '{"Bíceps","Lumbar"}', 'home', '{"mochila cargada"}', 'compuesto', 'principiante', 'Ejercicio de traccion para casa. Inclinar el torso, espalda neutra y tirar la mochila hacia el abdomen. Ajustar peso segun nivel.'),
('Remo unilateral con mochila', 'remo-unilateral-mochila', 'Espalda', '{"Bíceps","Core"}', 'home', '{"mochila cargada","silla o apoyo"}', 'compuesto', 'principiante', 'Remo de un brazo para dorsales y espalda media. Apoyar una mano en silla firme, tirar el codo hacia atras sin rotar el tronco.'),
('Remo invertido bajo mesa', 'remo-invertido-mesa', 'Espalda', '{"Bíceps","Core"}', 'home', '{"mesa firme"}', 'compuesto', 'intermedio', 'Traccion horizontal con el cuerpo. Solo recomendar con mesa muy firme y estable. Mientras mas horizontal el cuerpo, mas dificil.'),
('Remo con toalla en puerta', 'remo-toalla-puerta', 'Espalda', '{"Bíceps"}', 'home', '{"toalla","puerta firme"}', 'compuesto', 'intermedio', 'Remo casero usando una toalla asegurada en una puerta firme. Verificar seguridad del anclaje antes de recomendar. Mantener codos pegados.'),
('Pullover con mochila', 'pullover-mochila', 'Espalda', '{"Pecho","Core"}', 'home', '{"mochila cargada","piso o colchoneta"}', 'aislamiento', 'principiante', 'Trabajo de dorsales con baja carga. Acostado, llevar mochila desde sobre el pecho hacia atras con brazos semirrendidos y control.'),
('Y raises en el piso', 'y-raises-piso', 'Espalda', '{"Hombros","Lumbar"}', 'home', '{"cuerpo","colchoneta"}', 'aislamiento', 'principiante', 'Fortalece espalda alta y control escapular. Boca abajo, levantar brazos en forma de Y sin encoger cuello.'),
('Reverse snow angels', 'reverse-snow-angels', 'Espalda', '{"Hombros","Lumbar"}', 'home', '{"cuerpo","colchoneta"}', 'estabilizacion', 'principiante', 'Movilidad y resistencia de espalda alta. Boca abajo, mover brazos amplio y controlado sin dolor lumbar.'),
('Scapular push-ups', 'scapular-push-ups', 'Espalda', '{"Pecho","Hombros"}', 'home', '{"cuerpo"}', 'estabilizacion', 'principiante', 'Ejercicio de control escapular. En posicion de plancha, separar y juntar escapulas sin doblar codos. Util para hombros sanos.'),

-- HOMBROS EN CASA
('Press militar con mochila', 'press-militar-mochila', 'Hombros', '{"Tríceps","Core"}', 'home', '{"mochila cargada"}', 'compuesto', 'principiante', 'Empuje vertical casero. Mantener abdomen activo y no arquear la espalda. Ajustar carga de la mochila.'),
('Elevaciones frontales con botellas', 'elevaciones-frontales-botellas', 'Hombros', '{}', 'home', '{"botellas"}', 'aislamiento', 'principiante', 'Aislamiento del deltoide anterior con carga ligera. Subir hasta altura de hombros y bajar controlado.'),
('Pajaros con botellas', 'pajaros-botellas', 'Hombros', '{"Espalda"}', 'home', '{"botellas"}', 'aislamiento', 'principiante', 'Trabajo de deltoide posterior. Inclinar torso, espalda neutra y abrir brazos sin impulso.'),
('Wall walks', 'wall-walks', 'Hombros', '{"Core","Tríceps"}', 'home', '{"pared","cuerpo"}', 'compuesto', 'avanzado', 'Ejercicio avanzado de hombros y core. Caminar con pies por la pared hasta posicion invertida controlada. No recomendar a principiantes.'),
('Handstand hold asistido', 'handstand-hold-asistido', 'Hombros', '{"Core","Tríceps"}', 'home', '{"pared"}', 'estabilizacion', 'avanzado', 'Mantencion invertida asistida en pared. Requiere fuerza, movilidad de hombro y control corporal. Evitar si hay mareos o dolor de muneca.'),

-- BRAZOS EN CASA
('Curl martillo con mochila', 'curl-martillo-mochila', 'Bíceps', '{"Antebrazo"}', 'home', '{"mochila cargada"}', 'aislamiento', 'principiante', 'Curl neutro usando las asas de una mochila. Mantener codos cerca del cuerpo y controlar la bajada.'),
('Curl isometrico con toalla', 'curl-isometrico-toalla', 'Bíceps', '{"Antebrazo"}', 'home', '{"toalla"}', 'estabilizacion', 'principiante', 'Trabajo isometrico de biceps. Pisar la toalla y tirar sin mover, manteniendo tension 15 a 30 segundos.'),
('Curl con banda elastica', 'curl-banda-elastica', 'Bíceps', '{"Antebrazo"}', 'home', '{"banda elastica"}', 'aislamiento', 'principiante', 'Biceps con resistencia progresiva. Pisar la banda, codos fijos y evitar balanceo. Ideal si el usuario tiene banda.'),
('Curl inverso con botellas', 'curl-inverso-botellas', 'Bíceps', '{"Antebrazo"}', 'home', '{"botellas"}', 'aislamiento', 'principiante', 'Enfatiza antebrazo y braquial. Usar agarre prono, carga ligera y controlada.'),
('Extension triceps con mochila', 'extension-triceps-mochila', 'Tríceps', '{}', 'home', '{"mochila cargada"}', 'aislamiento', 'principiante', 'Extension sobre cabeza con mochila. Mantener codos apuntando al frente y abdomen firme.'),
('Extension triceps con banda', 'extension-triceps-banda', 'Tríceps', '{}', 'home', '{"banda elastica"}', 'aislamiento', 'principiante', 'Aislamiento de triceps con banda anclada de forma segura. Extender codos sin mover hombros.'),
('Flexiones cerradas', 'flexiones-cerradas', 'Tríceps', '{"Pecho","Hombros"}', 'home', '{"cuerpo"}', 'compuesto', 'intermedio', 'Variante de flexion con manos mas juntas para enfatizar triceps. Requiere buena tecnica de flexion.'),
('Fondos en banco', 'fondos-en-banco', 'Tríceps', '{"Pecho","Hombros"}', 'home', '{"banco o silla firme"}', 'compuesto', 'principiante', 'Fondos con apoyo atras. Usar silla firme, bajar controlado y evitar molestias en hombros.'),

-- PIERNAS EN CASA
('Sentadilla a silla', 'sentadilla-a-silla', 'Cuádriceps', '{"Glúteos","Core"}', 'home', '{"silla"}', 'compuesto', 'principiante', 'Sentadilla asistida para principiantes. Tocar la silla con control sin dejarse caer. Buena para aprender patron de sentadilla.'),
('Sentadilla pared isometrica', 'sentadilla-pared-isometrica', 'Cuádriceps', '{"Glúteos"}', 'home', '{"pared"}', 'estabilizacion', 'principiante', 'Mantencion contra pared. Rodillas cerca de 90 grados segun tolerancia. Util para resistencia de piernas sin impacto.'),
('Zancadas reversas', 'zancadas-reversas', 'Cuádriceps', '{"Glúteos","Femoral"}', 'home', '{"cuerpo o mochila"}', 'compuesto', 'principiante', 'Alternativa controlada a zancadas frontales. Paso hacia atras, tronco estable y rodilla delantera alineada.'),
('Zancadas laterales', 'zancadas-laterales', 'Cuádriceps', '{"Glúteos","Aductores"}', 'home', '{"cuerpo"}', 'compuesto', 'intermedio', 'Trabajo frontal y lateral de pierna. Desplazar cadera hacia un lado manteniendo el pie completo apoyado.'),
('Sentadilla pistol asistida', 'sentadilla-pistol-asistida', 'Cuádriceps', '{"Glúteos","Core"}', 'home', '{"silla","marco de puerta o apoyo"}', 'compuesto', 'avanzado', 'Sentadilla unilateral asistida. Requiere fuerza y movilidad. Usar apoyo para controlar bajada y subida.'),
('Step-up a silla baja', 'step-up-silla-baja', 'Cuádriceps', '{"Glúteos"}', 'home', '{"silla baja o escalon firme"}', 'compuesto', 'principiante', 'Subida a apoyo estable. Empujar con la pierna que sube y evitar impulsarse con la pierna trasera.'),
('Split squat', 'split-squat', 'Cuádriceps', '{"Glúteos"}', 'home', '{"cuerpo o mochila"}', 'compuesto', 'principiante', 'Trabajo unilateral sin desplazamiento. Mantener pies separados, tronco estable y bajar vertical.'),
('Sentadilla sumo peso corporal', 'sentadilla-sumo-peso-corporal', 'Cuádriceps', '{"Glúteos","Aductores"}', 'home', '{"cuerpo"}', 'compuesto', 'principiante', 'Sentadilla con postura amplia. Enfatiza aductores y gluteos. Rodillas siguen direccion de los pies.'),
('Curl femoral con toalla', 'curl-femoral-toalla', 'Femoral', '{"Glúteos","Core"}', 'home', '{"toalla","piso liso"}', 'aislamiento', 'intermedio', 'Curl femoral deslizando talones sobre toalla. Mantener cadera elevada y controlar extension de rodillas.'),
('Buenos dias con mochila', 'buenos-dias-mochila', 'Femoral', '{"Glúteos","Lumbar"}', 'home', '{"mochila cargada"}', 'compuesto', 'principiante', 'Bisagra de cadera para cadena posterior. Espalda neutra, rodillas suaves y sentir tension en femorales.'),
('Puente femoral con talones elevados', 'puente-femoral-talones-elevados', 'Femoral', '{"Glúteos"}', 'home', '{"silla o banco bajo"}', 'compuesto', 'intermedio', 'Puente con talones en apoyo para enfatizar femorales. Subir cadera sin arquear la espalda.'),
('Peso muerto con mochila', 'peso-muerto-mochila', 'Femoral', '{"Glúteos","Lumbar"}', 'home', '{"mochila cargada"}', 'compuesto', 'principiante', 'Bisagra de cadera con carga casera. Mantener mochila cerca del cuerpo y columna neutra.'),
('Nordic curl asistido', 'nordic-curl-asistido', 'Femoral', '{"Glúteos"}', 'home', '{"sofa o apoyo para pies","colchoneta"}', 'compuesto', 'avanzado', 'Ejercicio avanzado de femorales. Sujetar pies bajo apoyo firme y bajar controlado ayudandose con manos.'),
('Hamstring walkouts', 'hamstring-walkouts', 'Femoral', '{"Glúteos","Core"}', 'home', '{"cuerpo","colchoneta"}', 'compuesto', 'intermedio', 'Desde puente de gluteos, caminar talones hacia afuera y volver. Mantener cadera alta.'),

-- GLUTEOS, PANTORRILLAS Y LUMBAR
('Puente de gluteos unilateral', 'puente-gluteos-unilateral', 'Glúteos', '{"Femoral","Core"}', 'home', '{"cuerpo","colchoneta"}', 'compuesto', 'intermedio', 'Variante unilateral del puente. Mantener pelvis nivelada y empujar con el talon de la pierna de apoyo.'),
('Hip thrust en sofa', 'hip-thrust-sofa', 'Glúteos', '{"Femoral"}', 'home', '{"sofa o banco firme"}', 'compuesto', 'principiante', 'Hip thrust usando sofa como apoyo. Barbilla levemente hacia adentro, pelvis en retroversion al final.'),
('Abduccion lateral acostado', 'abduccion-lateral-acostado', 'Glúteos', '{"Cadera"}', 'home', '{"cuerpo o banda elastica"}', 'aislamiento', 'principiante', 'Trabajo de gluteo medio. Acostado de lado, elevar pierna sin rotar cadera hacia atras.'),
('Monster walks con banda', 'monster-walks-banda', 'Glúteos', '{"Cuádriceps"}', 'home', '{"banda elastica"}', 'estabilizacion', 'principiante', 'Caminata lateral o diagonal con banda. Mantener tension constante y rodillas alineadas.'),
('Patada de gluteo con banda', 'patada-gluteo-banda', 'Glúteos', '{}', 'home', '{"banda elastica"}', 'aislamiento', 'principiante', 'Aislamiento de gluteo mayor. Extender pierna hacia atras sin arquear la zona lumbar.'),
('Elevacion de pantorrillas doble', 'elevacion-pantorrillas-doble', 'Pantorrillas', '{}', 'home', '{"escalon opcional"}', 'aislamiento', 'principiante', 'Elevacion de talones con ambos pies. Puede hacerse en escalon para mas rango. Controlar bajada.'),
('Elevacion de pantorrillas con mochila', 'elevacion-pantorrillas-mochila', 'Pantorrillas', '{}', 'home', '{"mochila cargada","pared para apoyo"}', 'aislamiento', 'principiante', 'Pantorrillas con carga casera. Usar pared para equilibrio y subir/bajar sin rebote.'),
('Pantorrillas sentado con mochila', 'pantorrillas-sentado-mochila', 'Pantorrillas', '{}', 'home', '{"silla","mochila cargada"}', 'aislamiento', 'principiante', 'Enfatiza soleo. Sentado, mochila sobre rodillas y elevar talones de forma controlada.'),
('Bird dog', 'bird-dog', 'Lumbar', '{"Core","Glúteos"}', 'home', '{"cuerpo","colchoneta"}', 'estabilizacion', 'principiante', 'Estabilidad lumbar y core. En cuadrupedia, extender brazo y pierna contraria sin rotar la pelvis.'),
('Buenos dias peso corporal', 'buenos-dias-peso-corporal', 'Lumbar', '{"Femoral","Glúteos"}', 'home', '{"cuerpo"}', 'compuesto', 'principiante', 'Patron de bisagra sin carga. Ideal para aprender control de cadera y espalda neutra.'),
('Cobra hold', 'cobra-hold', 'Lumbar', '{"Espalda"}', 'home', '{"colchoneta"}', 'estabilizacion', 'principiante', 'Extension suave de espalda. Mantener pocos segundos sin dolor, evitando hiperextender cuello.'),

-- CORE EN CASA
('Hollow hold', 'hollow-hold', 'Core', '{}', 'home', '{"cuerpo","colchoneta"}', 'estabilizacion', 'intermedio', 'Mantencion abdominal. Zona lumbar pegada al piso, brazos y piernas extendidos segun nivel.'),
('Reverse crunch', 'reverse-crunch', 'Core', '{}', 'home', '{"cuerpo","colchoneta"}', 'aislamiento', 'principiante', 'Abdominal inferior. Elevar cadera levemente llevando rodillas al pecho sin impulso.'),
('Toe touches', 'toe-touches', 'Core', '{}', 'home', '{"cuerpo","colchoneta"}', 'aislamiento', 'principiante', 'Crunch hacia pies con piernas elevadas. Mantener movimiento corto y controlado.'),
('Plank shoulder taps', 'plank-shoulder-taps', 'Core', '{"Hombros"}', 'home', '{"cuerpo"}', 'estabilizacion', 'intermedio', 'Plancha con toque de hombros. Evitar balanceo de cadera; abrir pies para facilitar.'),
('Bear crawl', 'bear-crawl', 'Core', '{"Hombros","Cuádriceps"}', 'home', '{"cuerpo"}', 'compuesto', 'intermedio', 'Desplazamiento en cuadrupedia con rodillas cerca del piso. Trabaja core, hombros y coordinacion.'),
('V-ups', 'v-ups', 'Core', '{}', 'home', '{"cuerpo","colchoneta"}', 'aislamiento', 'intermedio', 'Abdominal dinamico avanzado. Subir tronco y piernas a la vez, controlar bajada.'),
('Plancha con elevacion de pierna', 'plancha-elevacion-pierna', 'Core', '{"Glúteos"}', 'home', '{"cuerpo"}', 'estabilizacion', 'intermedio', 'Plancha frontal agregando elevacion alternada de piernas. Mantener pelvis estable.'),

-- CARDIO Y ACTIVIDADES FISICAS
('Caminar', 'caminar', 'Cardio', '{"Piernas"}', 'both', '{"zapatillas"}', 'cardio', 'principiante', 'Actividad cardiovascular de bajo impacto. Recomendada para principiantes, retorno al ejercicio, descanso activo o usuarios con baja condicion. Ajustar duracion e intensidad.'),
('Caminata rapida', 'caminata-rapida', 'Cardio', '{"Piernas","Core"}', 'both', '{"zapatillas"}', 'cardio', 'principiante', 'Cardio moderado de bajo impacto. El usuario debe poder hablar con frases cortas. Buena opcion para perdida de grasa y salud general.'),
('Trotar', 'trotar', 'Cardio', '{"Piernas","Core"}', 'both', '{"zapatillas"}', 'cardio', 'principiante', 'Cardio continuo de intensidad baja a moderada. Requiere tolerancia basica al impacto. Progresar volumen gradualmente.'),
('Correr', 'correr', 'Cardio', '{"Piernas","Core"}', 'both', '{"zapatillas"}', 'cardio', 'intermedio', 'Cardio de mayor impacto e intensidad. Recomendado para usuarios sin dolor articular y con base minima de condicion.'),
('Sprints', 'sprints', 'Cardio', '{"Piernas","Glúteos","Core"}', 'both', '{"zapatillas","espacio abierto"}', 'explosivo', 'avanzado', 'Trabajo de velocidad e alta intensidad. Requiere buen calentamiento y experiencia. No ideal para principiantes o dolor de rodilla/tobillo.'),
('Bicicleta', 'bicicleta', 'Cardio', '{"Cuádriceps","Glúteos","Pantorrillas"}', 'both', '{"bicicleta"}', 'cardio', 'principiante', 'Cardio de bajo impacto. Ajustar duracion, cadencia y resistencia segun nivel. Bueno para salud cardiovascular.'),
('Bicicleta estatica', 'bicicleta-estatica', 'Cardio', '{"Cuádriceps","Glúteos","Pantorrillas"}', 'home', '{"bicicleta estatica"}', 'cardio', 'principiante', 'Cardio indoor de bajo impacto. Util cuando el usuario tiene implemento en casa. Controlar intensidad por respiracion o pulsaciones.'),
('Saltar la cuerda', 'saltar-la-cuerda', 'Cardio', '{"Pantorrillas","Hombros","Core"}', 'home', '{"cuerda","espacio libre"}', 'cardio', 'intermedio', 'Cardio coordinativo de impacto moderado. Requiere cuerda y espacio. Progresar con intervalos cortos.'),
('Jumping jacks', 'jumping-jacks', 'Cardio', '{"Piernas","Hombros"}', 'home', '{"cuerpo"}', 'cardio', 'principiante', 'Cardio simple para casa. Puede modificarse sin salto para bajo impacto.'),
('High knees', 'high-knees', 'Cardio', '{"Core","Cuádriceps"}', 'home', '{"cuerpo"}', 'cardio', 'intermedio', 'Cardio intenso en el lugar. Elevar rodillas, mantener tronco alto y usar intervalos.'),
('Burpees', 'burpees', 'Cardio', '{"Pecho","Hombros","Piernas","Core"}', 'home', '{"cuerpo"}', 'cardio', 'avanzado', 'Ejercicio metabolico de cuerpo completo. Requiere buena tolerancia al impacto y tecnica. Modificar sin salto para menor intensidad.'),
('Shadow boxing', 'shadow-boxing', 'Cardio', '{"Hombros","Core","Piernas"}', 'home', '{"espacio libre"}', 'cardio', 'principiante', 'Cardio sin implementos simulando golpes. Mantener guardia, rotar tronco suave y evitar hiperextender codos.'),
('Baile cardio', 'baile-cardio', 'Cardio', '{"Piernas","Core"}', 'home', '{"musica","espacio libre"}', 'cardio', 'principiante', 'Actividad cardiovascular entretenida y adaptable. Recomendada para adherencia, coordinacion y gasto energetico.'),
('Subir escaleras', 'subir-escaleras', 'Cardio', '{"Cuádriceps","Glúteos","Pantorrillas"}', 'both', '{"escaleras"}', 'cardio', 'intermedio', 'Cardio con enfasis en piernas. Usar pasamanos si hace falta y controlar bajadas para cuidar rodillas.'),
('Senderismo', 'senderismo', 'Cardio', '{"Piernas","Glúteos","Core"}', 'both', '{"zapatillas o botas","ruta segura"}', 'cardio', 'principiante', 'Actividad al aire libre de duracion variable. Considerar terreno, desnivel, hidratacion y experiencia del usuario.'),

-- DEPORTES
('Futbol', 'futbol', 'Deportes', '{"Cardio","Piernas","Core"}', 'both', '{"zapatillas o chuteadores","balon","cancha"}', 'cardio', 'intermedio', 'Deporte intermitente con carrera, cambios de direccion y contacto. Requiere tolerancia a impacto y calentamiento. Registrar como actividad deportiva.'),
('Basquetbol', 'basquetbol', 'Deportes', '{"Cardio","Piernas","Hombros","Core"}', 'both', '{"zapatillas","balon","cancha"}', 'cardio', 'intermedio', 'Deporte con saltos, sprints y cambios de direccion. Carga importante para rodillas y tobillos.'),
('Tenis', 'tenis', 'Deportes', '{"Cardio","Piernas","Hombros","Core"}', 'both', '{"raqueta","pelotas","cancha"}', 'cardio', 'intermedio', 'Deporte de desplazamientos laterales, aceleraciones y golpeo. Requiere coordinacion y movilidad de hombro.'),
('Padel', 'padel', 'Deportes', '{"Cardio","Piernas","Hombros","Core"}', 'both', '{"pala","pelotas","cancha"}', 'cardio', 'principiante', 'Deporte recreativo de intensidad variable. Buen gasto energetico con menor distancia que tenis, pero con giros frecuentes.'),
('Voleibol', 'voleibol', 'Deportes', '{"Cardio","Piernas","Hombros","Core"}', 'both', '{"balon","cancha"}', 'cardio', 'intermedio', 'Deporte con saltos y acciones por encima de la cabeza. Considerar hombros, rodillas y tobillos.'),
('Natacion', 'natacion', 'Deportes', '{"Cardio","Espalda","Hombros","Core"}', 'both', '{"piscina","traje de bano"}', 'cardio', 'principiante', 'Cardio de bajo impacto articular. Excelente para condicion general. Ajustar volumen segun tecnica y experiencia acuaticas.'),
('Boxeo recreativo', 'boxeo-recreativo', 'Deportes', '{"Cardio","Hombros","Core","Piernas"}', 'both', '{"guantes opcional","saco opcional"}', 'cardio', 'intermedio', 'Actividad de alta intensidad con golpes, desplazamientos y core. Puede hacerse como sombra, saco o clase.'),
('Artes marciales', 'artes-marciales', 'Deportes', '{"Cardio","Piernas","Core","Hombros"}', 'both', '{"segun disciplina"}', 'cardio', 'intermedio', 'Actividad tecnica y fisica de intensidad variable. Considerar experiencia, contacto, movilidad y riesgo de lesiones.'),
('Yoga', 'yoga', 'Deportes', '{"Core","Movilidad","Hombros"}', 'home', '{"colchoneta"}', 'estabilizacion', 'principiante', 'Practica de movilidad, fuerza isometrica y respiracion. Util para recuperacion, flexibilidad y control corporal.'),
('Pilates', 'pilates', 'Deportes', '{"Core","Glúteos","Movilidad"}', 'home', '{"colchoneta"}', 'estabilizacion', 'principiante', 'Actividad de control corporal y core. Buena para estabilidad, postura y fuerza de baja carga.'),
('Escalada indoor', 'escalada-indoor', 'Deportes', '{"Espalda","Bíceps","Core","Antebrazo"}', 'both', '{"muro de escalada","zapatillas de escalada"}', 'compuesto', 'intermedio', 'Deporte de traccion y agarre. Exige espalda, antebrazo y core. Requiere instalacion adecuada y tecnica basica.'),
('Patinaje', 'patinaje', 'Deportes', '{"Cardio","Cuádriceps","Glúteos","Core"}', 'both', '{"patines","protecciones"}', 'cardio', 'intermedio', 'Cardio con equilibrio y piernas. Recomendar protecciones y superficie segura.'),
('Remo indoor', 'remo-indoor', 'Cardio', '{"Espalda","Piernas","Core"}', 'both', '{"maquina de remo"}', 'cardio', 'principiante', 'Cardio de cuerpo completo con maquina. Enfatiza piernas, espalda y core. Mantener espalda neutra y ritmo controlado.')
on conflict (slug) do update set
  name_es = excluded.name_es,
  muscle_group_primary = excluded.muscle_group_primary,
  muscle_group_secondary = excluded.muscle_group_secondary,
  location = excluded.location,
  equipment = excluded.equipment,
  exercise_type = excluded.exercise_type,
  difficulty = excluded.difficulty,
  tips = excluded.tips,
  is_active = true;
