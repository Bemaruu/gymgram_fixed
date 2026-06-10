# Respaldo clínico del sistema de recomendación de ejercicios — GymGram

**Documento de respaldo profesional para convenio universitario (piloto)**
Versión 1.1 · 7 de junio de 2026 · Elaborado con base en guías de organismos profesionales y literatura revisada por pares.

> **Aviso clínico.** Este material respalda las decisiones de seguridad del software (qué ejercicios excluir o recomendar según condición declarada) y **no sustituye la evaluación médica ni kinésica individual** de cada usuario. Antes de su uso en el piloto, este documento debe ser revisado y validado por el/la kinesiólogo(a) y el/la profesor(a) de Educación Física de la institución. La app incluye disclaimer, tamizaje PAR-Q+ y SCOFF, y deriva a evaluación profesional cuando corresponde.

> **Posicionamiento.** GymGram **no** afirma que sus rutinas sean "médicamente correctas". Lo que este documento demuestra es que **el sistema incorpora filtros de seguridad basados en evidencia para reducir riesgos y derivar a evaluación profesional cuando corresponde** — una afirmación acotada y defendible, adecuada a un piloto universitario.

---

## 1. Cómo funciona el filtro de seguridad

GymGram clasifica cada ejercicio del catálogo (193 ejercicios) con un vocabulario clínico **cerrado** de 8 condiciones:

`lumbar · rodilla · hombro · cervical · muñeca · embarazo · hipertensión · cardiaco`

- **En el onboarding** el usuario declara las zonas con lesión/molestia y responde el cuestionario **PAR-Q+** (tamizaje de aptitud para actividad física) y **SCOFF** (riesgo de trastorno de conducta alimentaria).
- El **motor de recomendación** —basado en reglas de seguridad, el perfil declarado por el usuario y un catálogo validado— **excluye automáticamente** todo ejercicio etiquetado con la condición declarada. Las respuestas del PAR-Q+ que indican riesgo cardiovascular activan los filtros `cardiaco` e `hipertensión`.
- Existe además un filtro por **nivel de experiencia** (principiante / intermedio / avanzado): a un principiante nunca se le asignan patrones de alta demanda técnica o carga axial.
- Los **ejercicios de rehabilitación** (sección 4) se mantienen disponibles para la población lesionada precisamente como alternativas seguras.

Cada etiqueta de este catálogo está respaldada por la evidencia que se resume a continuación.

### 1.1 Declaración de la condición y severidad

Actualmente el usuario declara **las zonas afectadas** (selección múltiple) más un campo de **notas libres** opcional. El filtro de seguridad es, por diseño, **conservador**: ante cualquier zona declarada se excluyen los ejercicios de riesgo para esa zona.

Reconocemos que, clínicamente, **no es lo mismo una molestia ocasional que una lesión activa o una patología diagnosticada** (p. ej. molestia lumbar puntual vs. hernia discal). Por ello proponemos co-diseñar con el equipo de salud de la institución un **nivel de severidad** declarable:

| Nivel | Descripción | Comportamiento propuesto |
|-------|-------------|--------------------------|
| **Molestia** | Incomodidad ocasional, sin diagnóstico | Filtro estándar de la zona + sugerencia de progresión gradual |
| **Lesión previa** | Lesión ya resuelta o en fase final de rehab | Filtro estándar + priorización de ejercicios de rehabilitación de la zona |
| **Lesión activa / diagnóstico** | Lesión en curso o patología diagnosticada | Modo conservador reforzado + **recomendación explícita de evaluación profesional** antes de iniciar |

Este modelo de severidad es un **punto de mejora abierto** que esperamos validar con el/la kinesiólogo(a) durante el piloto.

---

## 2. Criterio de seguridad por condición

### Lumbar (zona baja de la espalda)
El principal mecanismo lesivo en el gimnasio es la **flexión lumbar repetida bajo carga** junto a la compresión axial. La investigación de **Stuart McGill (Universidad de Waterloo)** describe la flexión repetida del raquis como el mecanismo número uno de herniación discal (migración progresiva del núcleo pulposo); ejercicios como sit-ups/crunches generan fuerzas compresivas del orden de ~3.300 N. **Se restringen:** crunches, sit-ups, toe-touches, elevación de piernas colgado, *good mornings* y peso muerto pesado (alta cizalla). **Alternativas avaladas:** el *McGill Big 3* (curl-up modificado, plancha lateral y *bird-dog*), *dead-bug* e inclinación pélvica, que mantienen la columna neutra con mínima carga discal. *(Fuentes 8, 9.)*

### Rodilla
El riesgo proviene del **alto impacto** (saltos, carrera, pliometría) y de la **carga en rangos profundos con mal control del valgo**, que aumentan el estrés patelofemoral y meniscal. **Se restringen:** sentadilla con salto, *burpees*, *high knees*, *sprints*, carrera y rangos profundos no controlados. **Alternativas avaladas (AAOS/OrthoInfo):** isométrico de cuádriceps (*quad set*), extensión terminal de rodilla, elevación de pierna recta y *step-downs* controlados; el *clamshell* con banda mejora el control del glúteo medio para evitar el valgo. *(Fuente 2.)*

### Hombro
Mecanismo predominante: **pinzamiento subacromial** — elevar el brazo en rotación interna por encima del hombro reduce el espacio subacromial y daña el manguito rotador. El *upright row* (remo al mentón) es el ejemplo paradigmático (*Strength & Conditioning Journal*, 2011) y la *press tras nuca* somete al manguito a carga en posición vulnerable. **Se restringen:** *upright row*, press tras nuca y elevaciones por encima de la cabeza con dolor. **Alternativas avaladas (AAOS):** rotación externa con banda, *scaption* con pulgares arriba (entrena el supraespinoso, el más lesionado), pendulares de Codman (fase temprana) y *wall slides*. *(Fuentes 3, 7.)*

### Cervical (cuello)
Los ejercicios que **cargan o traccionan el cuello en posición forzada** (press tras nuca, crunches con tirón de manos tras la cabeza, *v-ups*) aumentan el riesgo de tensión y, con carga, de lesión discal cervical. **Recomendado en rehabilitación:** entrenamiento de los **flexores cervicales profundos** mediante retracción cervical (*chin tucks*) e isométricos cervicales; la evidencia muestra reducción de dolor, discapacidad cervical y cefalea cervicogénica. *(Fuente 10.)*

### Muñeca
El dolor de muñeca se agrava con el **apoyo de carga en extensión** (flexiones, planchas en manos, *burpees*), que comprime la articulación en su rango final. La evidencia biomecánica lo cuantifica: al pasar de muñeca neutra a extendida en una flexión, la transmisión de fuerza por la fosa escafoidea aumenta del 52 % al 62 % y la tensión de los ligamentos intrínsecos palmares y del retináculo flexor se eleva notablemente. **Modificaciones recomendadas:** planchas y flexiones sobre antebrazos, uso de soportes/mancuernas para mantener la muñeca neutra, y sustitución por press y remos que no requieren apoyo en extensión. *(Fuentes 13, 14.)*

### Embarazo
Según **ACOG**, la mayoría de embarazadas sin complicaciones puede mantener ejercicio regular, pero debe evitarse: ejercicio en **decúbito supino prolongado** tras el primer trimestre, **maniobras de Valsalva** sostenidas con levantamiento de peso (reducen la perfusión uterina), deportes de **contacto** y de **raqueta** vigorosos, y toda actividad con **riesgo de trauma abdominal o caída**. **Seguro:** aeróbico de bajo impacto (caminata, natación, aquagym, bicicleta estática), fuerza con cargas ligeras y más repeticiones sin Valsalva, y movilidad suave. *(Fuente 1.)*

### Hipertensión
Riesgo central: el **pico extremo de presión arterial** inducido por el levantamiento pesado con **maniobra de Valsalva** (apnea durante el esfuerzo), que puede causar mareo o síncope. **Se restringen:** cargas máximas/casi máximas e isométricos sostenidos prolongados. **ACSM recomienda** fuerza de carga moderada y mayor número de repeticiones, con movimiento controlado y **espiración durante el esfuerzo** (sin Valsalva). *(Fuentes 4, 12.)*

### Cardiaco
En cardiopatía la prescripción se basa en la **capacidad funcional (METs)** medida por prueba de esfuerzo; debe evitarse la actividad de alto impacto y el progreso debe ser gradual. La fuerza segura es en **circuito con cargas ligeras (40-60 % de 1RM)**, poco descanso y monitorización de frecuencia cardíaca y presión arterial, evitando Valsalva y cargas máximas. *(Fuentes 5, 6.)*

---

## 3. Restricción por nivel de experiencia

El principiante carece del control motor para ejecutar con seguridad patrones de alta demanda técnica y carga axial. **No se asignan a principiantes:** peso muerto convencional, sentadilla libre con barra, press militar con barra, *good mornings* con barra, *nordic curl*, *pistol squat* y *handstand/wall walks*. La **NSCA** recomienda una progresión por etapas de los patrones fundamentales (sentadilla *goblet* → libre, bisagra con bastón → barra) porque la técnica correcta es el principal factor de reducción de lesiones. Las variantes explosivas y de cadena posterior pesada se reservan para nivel avanzado, y la progresión de carga debe ser realista (sin saltos bruscos). *(Fuente 11.)*

---

## 4. Ejercicios de rehabilitación incorporados (junio 2026)

Se añadieron 18 ejercicios seguros, basados en protocolos de fisioterapia, que permanecen disponibles para la población lesionada como alternativas:

| Zona | Ejercicios añadidos | Respaldo |
|------|--------------------|----------|
| Lumbar / core | Curl-up de McGill, plancha de antebrazos, inclinación pélvica, cat-camel | McGill / U. Waterloo |
| Rodilla | Isométrico de cuádriceps, extensión terminal con banda, elevación de pierna recta, step-down controlado | AAOS/OrthoInfo |
| Hombro | Rotación externa con banda, pendulares de Codman, *wall slides*, *scaption* | AAOS/OrthoInfo |
| Cervical | Retracción cervical (*chin tucks*), isométrico cervical | Physiopedia / JOSPT |
| Femoral / patrón | Bisagra de cadera con bastón (enseñanza del patrón) | NSCA |
| Muñeca / pecho | Flexión con apoyo neutro de muñeca | J. Hand Therapy / J. Hand Surgery |
| Cardio bajo impacto | Aquagym / caminata acuática, elíptica | ACOG / ACSM / Cleveland Clinic |

---

## 5. Flujo de derivación a evaluación profesional

El tamizaje **PAR-Q+** y los flags clínicos del onboarding activan un **modo conservador reforzado**. Comportamiento actual del sistema cuando se detecta una posible condición de salud (flag `requires_medical_clearance`, p. ej. por respuestas positivas en PAR-Q+ sobre corazón, presión arterial, dolor torácico o mareos):

1. Se **fuerzan** los filtros `cardiaco` e `hipertensión` (se excluyen ejercicios con Valsalva / carga axial pesada).
2. Se **limita la intensidad**: no se asignan ejercicios de nivel avanzado ni de tipo explosivo, y se reduce el volumen (series) de la rutina.
3. Se muestra un **aviso explícito** al usuario: *"Detectamos posibles condiciones de salud. Consulta a un médico antes de empezar y avísanos si algún ejercicio te incomoda."*

**Casos en los que se recomienda evaluación profesional antes de usar rutinas automáticas** (gating reforzado, en parte ya activo y en parte propuesto como mejora del piloto):

- Dolor torácico durante el esfuerzo.
- Hipertensión no controlada o medicación cardiovascular.
- Cirugía reciente o lesión activa severa.
- Embarazo de riesgo (más allá del ejercicio rutinario que avala ACOG).
- Respuestas críticas en PAR-Q+.
- Indicios de trastorno de conducta alimentaria (tamizaje SCOFF), que además bloquea recomendaciones de déficit calórico.

> El equipo de salud de la institución puede ayudarnos a **definir el umbral exacto** en el que el sistema debería pasar de "rutina conservadora + aviso" a "bloqueo y derivación obligatoria". Es uno de los entregables que buscamos del piloto.

---

## 6. Limitaciones del sistema

Para transparencia con el equipo de salud, dejamos explícitas las limitaciones:

- El sistema **no realiza diagnósticos médicos**.
- El sistema **no reemplaza la evaluación profesional** (médica ni kinésica).
- Las recomendaciones **dependen de lo que el usuario declara**; una condición no informada no puede filtrarse.
- El vocabulario de condiciones es **cerrado** (8 categorías): cubre las lesiones más frecuentes, no la totalidad de cuadros clínicos posibles.
- Ante **dolor agudo, síntomas neurológicos, dolor torácico u otros signos de alarma**, la aplicación recomienda **suspender** y acudir a atención profesional.

---

## 7. Fuentes

1. **ACOG** — *Physical Activity and Exercise During Pregnancy and the Postpartum Period* (Committee Opinion, 2020). Colegio profesional / guía oficial. https://www.acog.org/clinical/clinical-guidance/committee-opinion/articles/2020/04/physical-activity-and-exercise-during-pregnancy-and-the-postpartum-period
2. **OrthoInfo — AAOS** — *Knee Conditioning Program* (2023). Academia Americana de Cirujanos Ortopédicos. https://orthoinfo.aaos.org/en/staying-healthy/knee-exercises
3. **OrthoInfo — AAOS** — *Rotator Cuff and Shoulder Conditioning Program*. https://orthoinfo.aaos.org/en/recovery/rotator-cuff-and-shoulder-conditioning-program/
4. **ACSM** — *Exercise for the Prevention and Treatment of Hypertension*. Colegio Americano de Medicina del Deporte. https://acsm.org/exercise-for-the-prevention-and-treatment-of-hypertension/
5. **American Heart Association** — *Resistance Exercise in Individuals With and Without Cardiovascular Disease* (Circulation). Journal revisado por pares. https://www.ahajournals.org/doi/10.1161/01.cir.101.7.828
6. **Cleveland Clinic** — *Cardiac Rehabilitation: Phases & Exercises*. Hospital. https://my.clevelandclinic.org/health/treatments/22069-cardiac-rehab
7. **Kolber et al.** — *The Upright Row: Implications for Preventing Subacromial Impingement* (Strength & Conditioning Journal, NSCA, 2011). Journal revisado por pares. https://journals.lww.com/nsca-scj/fulltext/2011/10000/the_upright_row__implications_for_preventing.2.aspx
8. **Stuart McGill** — Universidad de Waterloo / BackFitPro, *Designing Back Exercise* y *McGill Big 3*. Investigación en biomecánica espinal. https://www.backfitpro.com/designing-back-exercise-from-rehabilitation-to-enhancing-performance/
9. *The McGill Approach to Core Stabilization in Chronic Low Back Pain: A Review* (medRxiv, 2022). https://www.medrxiv.org/content/10.1101/2022.01.21.22269311.full.pdf
10. **Physiopedia** — *Deep Neck Flexor Stabilisation Protocol*. Recurso clínico de fisioterapia basado en evidencia. https://www.physio-pedia.com/Deep_Neck_Flexor_Stabilisation_Protocol
11. **NSCA** — *Position Statement on Weightlifting* / *Fundamental Resistance Training Movement Patterns*. https://www.nsca.com/contentassets/d8cfbfa7955544a78832822bbada99b7/nsca-position-statement-on-weightlifting.pdf
12. *Influence of breathing technique on arterial blood pressure during heavy weight lifting* (ScienceDirect) e *Intra-arterial BP during heavy resistance exercise* (Translational Sports Medicine, 2019). Journals revisados por pares.
13. **Rohman E. M. et al.** — *Effect of Push-Up Position on Wrist Joint Pressures in the Intact Wrist and Following Scapholunate Interosseous Ligament Sectioning* (Journal of Hand Therapy / PubMed). Journal revisado por pares. https://pubmed.ncbi.nlm.nih.gov/29157783/
14. **Majima M. et al.** — *Load transmission through the wrist in the extended position* (Journal of Hand Surgery / PubMed). Journal revisado por pares. https://pubmed.ncbi.nlm.nih.gov/18294538/ · y **Physiopedia — Wrist Sprain** (recurso clínico de fisioterapia). https://www.physio-pedia.com/Wrist_Sprain

---

*Investigación recopilada por el agente clínico interno de GymGram (IronCoach) verificando cada afirmación contra las fuentes citadas. Pendiente de validación por profesional colegiado de la institución antes de su uso en el piloto.*
