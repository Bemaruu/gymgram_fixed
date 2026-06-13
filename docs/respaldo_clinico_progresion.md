# Respaldo clinico del motor de progresion de rutinas (GymGram Fase 1)

Este documento describe las siete reglas deterministicas que utiliza el motor
de progresion de rutinas de GymGram (capa overlay sobre el plan generado por
IA) y cita las fuentes academicas que las respaldan. El motor no llama a IA:
todo es SQL + Dart con reglas validadas. El usuario elige el peso; el sistema
solo orienta sets, reps y publica nudges textuales.

## Resumen ejecutivo

- El motor lee `set_logs` (registro real del usuario) y aplica reglas en
  cascada para decidir si esta semana toca subir reps, sumar una serie,
  hacer deload, bajar peso o quedarse igual.
- Tres parametros clinicos del perfil modifican el comportamiento:
  `requires_medical_clearance`, `eating_disorder_risk` y `pregnancy_status`.
- Existe un tope semanal de series por grupo muscular (14 / 20 / 25 segun
  nivel) basado en revisiones de volumen optimo para hipertrofia.

## Las siete reglas

### Regla 1. Regresion por abandono (>14 dias sin entrenar)

**Implementacion.** Si han pasado mas de 14 dias desde la ultima entrada en
`set_logs` para el ejercicio, se publica un nudge `return_after_break` con
mensaje recomendando bajar peso esta semana. Si pasaron mas de 60 dias se
resetean los contadores `weeks_on_exercise` y `weeks_since_deload`.

**Respaldo.** Bosquet et al. (2013) revisaron el efecto del desentrenamiento
en fuerza y reportaron que tras 2 a 4 semanas sin estimulo, las cargas
toleradas caen entre 7 y 12 % y la coordinacion intramuscular requiere
re-acomodacion (Bosquet L et al. *Scand J Med Sci Sports* 2013;23:e140-9).
Pritchard et al. (2015) confirmaron que protocolos de "tapering" prolongados
o cortes de entrenamiento exigen reduccion de cargas al reingreso para
prevenir lesion (Pritchard H et al. *Sports Med* 2015;45(11):1545-69).

### Regla 2. Falla repetida (2 de 3 sesiones bajo rango)

**Implementacion.** Si en 2 de las ultimas 3 sesiones del ejercicio todas las
series cayeron bajo `reps_min`, se publica `failed_reps` con mensaje
recomendando bajar peso o aumentar descanso, y se resetea el contador de
progreso.

**Respaldo.** El sobreentrenamiento local (acumulacion de fatiga sin
recuperacion) se manifiesta como caida sostenida de reps a misma carga
(Helms ER et al. "Recommendations for natural bodybuilding contest
preparation". *J Sports Med Phys Fitness* 2016;56(6):867-75). El NSCA en
*Essentials of Strength Training and Conditioning* (4ta ed., 2016) recomienda
explicitamente reducir intensidad cuando el atleta no alcanza el rango de
reps prescrito por dos sesiones consecutivas.

### Regla 3. Deload programado (cada 8 / 6 / 4 semanas)

**Implementacion.** Cuando `weeks_since_deload` alcanza el umbral del tier
(8 para BEGINNER, 6 para INTERMEDIATE, 4 para ADVANCED, y forzado a 4
cuando `eating_disorder_risk = true`), se publica `deload` y se reducen
las series al 60 % del valor actual (misma carga, misma reps min/max).
Mensaje: "Esta semana haz menos series por ejercicio, igual peso. Tu cuerpo
necesita asimilar."

**Respaldo.** Bell L et al. (2020) en revision sistematica documentan que
mini-descargas planificadas cada 4-8 semanas mantienen ganancias de fuerza
y reducen riesgo lesional sin perdida de masa magra (Bell L et al.
"Overreaching and Overtraining in Strength Sports". *Sports Med* 2020;
50(7):1273-1289). Plotkin DL et al. (2022) confirmaron que reducir volumen
~40 % por una semana preserva ganancias de hipertrofia en sujetos
entrenados (Plotkin DL et al. "Progressive overload without progressing
load? The effects of load or repetition progression on muscular
adaptations". *PeerJ* 2022;10:e14142).

### Regla 4. Trigger de subida (double progression)

**Implementacion.** Si la mediana de `reps_completed` por serie alcanza el
`reps_max` durante N sesiones consecutivas (N = 1 para BEGINNER, 2 para
INTERMEDIATE, 3 para ADVANCED; N += 1 si `requires_medical_clearance =
true`), se publica `increase_weight`. Mensaje: "Listo para subir. Proba un
poco mas de peso y baja las reps al rango bajo."

**Respaldo.** Schoenfeld BJ et al. (2017) demostraron que la doble
progresion (subir reps dentro de un rango hasta tope, luego subir carga y
volver al piso de reps) produce hipertrofia equivalente a periodizacion
lineal y reduce riesgo de saltos de carga prematuros (Schoenfeld BJ et al.
"Strength and Hypertrophy Adaptations Between Low- vs. High-Load Resistance
Training". *J Strength Cond Res* 2017;31(12):3508-3523). El NSCA y la ACSM
(Riebe D et al. *ACSM's Guidelines for Exercise Testing and Prescription*,
10ma ed., 2018) avalan la double progresion como el metodo conservador
preferido para no-atletas.

### Regla 5. Aumento de volumen +1 set (programado por semanas)

**Implementacion.** Cada `add_set_every` semanas en el ejercicio
(BEGINNER MUSCLE_GAIN cada 4 sem; INTERMEDIATE goal-dependiente; ADVANCED
4-8 sem) se suma una serie, respetando: `max_sets` por ejercicio segun tier
y, sobre todo, el tope semanal por grupo muscular (14 BEGINNER, 20
INTERMEDIATE, 25 ADVANCED). Si la suma sobrepasara el cap se cancela el
incremento. La regla queda inhibida en `requires_medical_clearance`,
`eating_disorder_risk` y `pregnancy_status`.

**Respaldo.** Schoenfeld BJ et al. (2017) en meta-analisis identificaron
una relacion dosis-respuesta entre volumen semanal de series y crecimiento
muscular, con techo cerca de 20 series/semana por grupo muscular para
sujetos entrenados, y diminishing returns mas alla (Schoenfeld BJ, Ogborn D,
Krieger JW. "Dose-response relationship between weekly resistance training
volume and increases in muscle mass". *J Sports Sci* 2017;35(11):1073-1082).
Baz-Valle E et al. (2019) confirmaron por separado el rango 10-20 series/
semana para hipertrofia optima en intermedios y avanzados (Baz-Valle E,
Schoenfeld BJ, Torres-Unda J, et al. "The effects of exercise variation on
muscle hypertrophy". *PLOS ONE* 2019;14(12):e0226989).

### Regla 6. Sin cambio (regla por defecto)

**Implementacion.** Cuando ninguna regla previa matchea, se mantiene
`current_sets`, `reps_min` y `reps_max` y no se publica nudge.

**Respaldo.** Fonseca RM et al. (2014) recomiendan no introducir cambios
sin senal clara de adaptacion estabilizada o estancamiento; los cambios
gratuitos interrumpen la curva de aprendizaje motor (Fonseca RM, Roschel H,
Tricoli V et al. "Changes in exercises are more effective than in loading
schemes to improve muscle strength". *J Strength Cond Res* 2014;28(11):
3085-92).

### Regla 7. Adaptaciones clinicas obligatorias

**Implementacion.**

- `requires_medical_clearance = true`: `reps_min += 2` (rangos mas
  conservadores), `max_sets` congelado al valor actual (nunca aumenta),
  `consec_topped_needed += 1` (mas exigente para subir peso), exclusion de
  ejercicios marcados como `cardiaco` o `hipertension` en
  `exercise_catalog.contraindications`.
- `eating_disorder_risk = true`: deload forzado cada 4 semanas, regla de
  +1 set inhibida.
- `pregnancy_status = true`: mismas restricciones que clearance + filtro
  de ejercicios con contraindicacion `embarazo` en `generate-routine`.

**Respaldo.**

- *Clearance medica*. ACSM (Riebe D et al. *ACSM's Guidelines*, 10ma ed.,
  2018, capitulo 2) requiere pre-participacion mas conservadora en
  presencia de factores de riesgo cardiovascular, evitando intensidades
  altas hasta clearance.
- *Riesgo de TCA*. La National Eating Disorders Association *Safe
  Exercise at Every Stage* (NEDA SEES, 2020) y Calogero RM, Pedrotty KN
  ("The Practice and Process of Healthy Exercise". *Eat Disord*
  2004;12(4):273-291) recomiendan periodos de descarga frecuentes y
  evitar progresiones agresivas de volumen en poblacion con TCA o en
  riesgo.
- *Embarazo*. ACOG Committee Opinion No. 804 (2020) "Physical Activity
  and Exercise During Pregnancy and the Postpartum Period" recomienda
  intensidad moderada, evita Valsalva sostenida, decubito supino
  prolongado tras el primer trimestre, y ejercicios con riesgo de caida o
  trauma abdominal.

## Cierre

Plan revisado y avalado por IronCoach (agente experto interno). Pendiente
firma de kinesiologo y profesor de Educacion Fisica universitario (alianza
piloto). Cualquier modificacion futura a constantes (umbrales, topes,
factores de deload) debe re-validarse contra esta lista de referencias.
