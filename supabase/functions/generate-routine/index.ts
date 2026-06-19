// generate-routine — RAG sobre exercise_catalog.
//
// Input (POST body):
//   { days_per_week?: number, session_duration_min?: number }
//
// Lee profile + onboarding del usuario autenticado, filtra exercise_catalog por
// location y nivel, y le pide a GPT-4o-mini que arme un plan semanal usando
// SOLO ejercicios de la lista entregada.
//
// Output JSON:
//   { ok: true, plan: { days: [ { day, focus, exercises: [{slug, name, sets, reps, rest_seconds}] } ] } }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders, errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { chatJson, OpenAIError } from '../_shared/openai.ts';
import { profileContext, UserProfile } from '../_shared/prompts.ts';
import { enforceMonthlyCap, UsageCapError } from '../_shared/usage.ts';

type ExerciseRow = {
  slug: string;
  name_es: string;
  muscle_group_primary: string;
  muscle_group_secondary: string[] | null;
  location: 'gym' | 'home' | 'both';
  exercise_type: string;
  difficulty: 'principiante' | 'intermedio' | 'avanzado';
  contraindications?: string[] | null;
};

type PlanResponse = {
  days: Array<{
    day: number;
    focus: string;
    exercises: Array<{
      slug: string;
      name: string;
      sets: number;
      reps: string;
      rest_seconds: number;
    }>;
  }>;
};

function mapLocation(loc?: string | null): 'gym' | 'home' {
  return (loc?.toUpperCase() === 'HOME') ? 'home' : 'gym';
}

// Mapea lesiones declaradas en onboarding al vocabulario controlado de
// `exercise_catalog.contraindications` (lumbar, rodilla, hombro, cervical,
// muneca, embarazo, hipertension, cardiaco). Sin tilde en "muneca".
function mapInjuriesToContraindications(injuries: string[]): string[] {
  const map: Record<string, string> = {
    'lumbar': 'lumbar',
    'espalda': 'lumbar',
    'espalda baja': 'lumbar',
    'rodilla': 'rodilla',
    'rodillas': 'rodilla',
    'hombro': 'hombro',
    'hombros': 'hombro',
    'cuello': 'cervical',
    'cervical': 'cervical',
    'muneca': 'muneca',
    'muñeca': 'muneca',
    'munecas': 'muneca',
    'muñecas': 'muneca',
  };
  return injuries
    .map((i) => map[i.toLowerCase().trim()])
    .filter((v): v is string => Boolean(v));
}

// Mapea las 5 preguntas del PAR-Q+ (signup_parq.dart) a contraindicaciones
// del catalogo. heart_or_pressure / meds_heart_pressure / chest_pain -> cardiacas
// + hipertension. dizziness_fainting es senal de alerta cardiovascular tambien.
function parqToContraindications(parq: Record<string, unknown> | null | undefined): string[] {
  if (!parq || typeof parq !== 'object') return [];
  const out = new Set<string>();
  if (parq['heart_or_pressure'] === true) {
    out.add('cardiaco');
    out.add('hipertension');
  }
  if (parq['meds_heart_pressure'] === true) {
    out.add('cardiaco');
    out.add('hipertension');
  }
  if (parq['chest_pain'] === true) {
    out.add('cardiaco');
  }
  if (parq['dizziness_fainting'] === true) {
    out.add('cardiaco');
  }
  return [...out];
}

function difficultyFor(level?: string | null): string[] {
  // experience_level (BEGINNER/INTERMEDIATE/ADVANCED) o training_level
  // (beginner / intermediate_lt_1y / intermediate_1y_3y / advanced_gt_3y).
  const l = (level ?? '').toLowerCase();
  if (l.startsWith('advanced')) {
    return ['principiante', 'intermedio', 'avanzado'];
  }
  if (l.startsWith('intermediate')) {
    return ['principiante', 'intermedio'];
  }
  return ['principiante'];
}

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: {
    days_per_week?: number;
    session_duration_min?: number;
    force_regenerate?: boolean;
  } = {};
  try {
    body = await req.json();
  } catch { /* body opcional */ }

  const supabase = serviceClient();

  // Cache hit: si hay plan vigente para el usuario y los parametros piden son
  // iguales a los del cache, devolver directo sin tocar Gemini ni el cap.
  // El force_regenerate del body lo bypasea (boton "regenerar plan" futuro).
  if (!body.force_regenerate) {
    const { data: cached } = await supabase
      .from('routine_plans')
      .select('plan_json, days_per_week, session_duration_min, catalog_size, quality_flags')
      .eq('user_id', user.id)
      .maybeSingle();

    if (cached) {
      const cachedDays = cached.days_per_week as number;
      const cachedSession = cached.session_duration_min as number;
      const requestedDays = body.days_per_week;
      const requestedSession = body.session_duration_min;
      // Sirve el cache si los params NO fueron explicitamente distintos.
      const daysMatch = requestedDays == null || requestedDays === cachedDays;
      const sessionMatch =
        requestedSession == null || requestedSession === cachedSession;
      if (daysMatch && sessionMatch) {
        return jsonResponse({
          ok: true,
          plan: cached.plan_json,
          catalog_size: cached.catalog_size ?? null,
          quality_flags: cached.quality_flags ?? null,
          cached: true,
        });
      }
    }
  }

  // Tope duro de costo IA (safety net mensual)
  try {
    await enforceMonthlyCap(supabase, user.id, 'generate-routine');
  } catch (e) {
    if (e instanceof UsageCapError) return errorResponse('Monthly AI limit reached', 429);
    throw e;
  }

  // 1) Cargar perfil + onboarding
  const { data: profile } = await supabase
    .from('profiles')
    .select(
      'id, fitness_goal, training_location, weight, target_weight, age, gender, requires_medical_clearance, pregnancy_status, parq_answers',
    )
    .eq('id', user.id)
    .maybeSingle();

  if (!profile) return errorResponse('Profile not found', 404);

  const { data: onboardingRows } = await supabase
    .from('user_onboarding_data')
    .select(
      'training_level, experience_level, session_duration_minutes, available_days, equipment_available, injuries, routine_split_preference',
    )
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(1);
  const onboarding = onboardingRows?.[0];

  // Lesiones declaradas → restricción de seguridad para el prompt.
  const injuries = Array.isArray(onboarding?.injuries)
    ? (onboarding!.injuries as unknown[])
        .map((x) => `${x}`.trim())
        .filter((s) => s.length > 0 && s.toLowerCase() !== 'ninguna')
    : [];
  const injuriesClause = injuries.length > 0
    ? `\n\nIMPORTANTE (seguridad): el usuario reporta molestias o lesiones en: ${injuries.join(', ')}. EVITA ejercicios que carguen o estresen esas zonas; elige alternativas seguras de la lista y, si un grupo muscular no tiene alternativa segura, redúcelo o cámbialo.`
    : '';

  // Split preferido (full_body / upper_lower / push_pull_legs / bro_split /
  // no_preference). Antes se leía pero NO se usaba → la IA ignoraba la
  // preferencia del usuario.
  const splitPref = `${onboarding?.routine_split_preference ?? ''}`.toLowerCase().trim();

  // Equipo disponible declarado en onboarding. 'full_gym' habilita todo; en
  // gimnasio sin declarar equipo asumimos gimnasio completo; en casa sin
  // declarar asumimos solo peso corporal / objetos del hogar.
  const userEquip = new Set<string>(
    (Array.isArray(onboarding?.equipment_available)
      ? (onboarding!.equipment_available as unknown[])
      : []
    ).map((e) => `${e}`.toLowerCase().trim()).filter(Boolean),
  );

  const inferredDays =
    Array.isArray(onboarding?.available_days)
      ? (onboarding.available_days as unknown[]).length
      : null;

  const userProfile: UserProfile = {
    id: profile.id,
    fitness_goal: profile.fitness_goal,
    training_location: profile.training_location,
    experience_level:
      onboarding?.training_level ?? onboarding?.experience_level,
    weight: profile.weight,
    age: profile.age,
    gender: profile.gender,
    training_days_per_week:
      body.days_per_week ?? (inferredDays && inferredDays > 0 ? inferredDays : 3),
    session_duration_min:
      body.session_duration_min ?? onboarding?.session_duration_minutes ?? 60,
  };

  // 2) Filtrar exercise_catalog por location y nivel
  const loc = mapLocation(userProfile.training_location);
  let allowedDiffs = difficultyFor(userProfile.experience_level);

  // Contraindicaciones: lesiones declaradas + PAR-Q+ (si hay flags clinicos)
  const requiresClearance = profile.requires_medical_clearance === true;
  const pregnancyStatus = profile.pregnancy_status === true;
  const blockedCats = new Set<string>([
    ...mapInjuriesToContraindications(injuries),
    ...parqToContraindications(profile.parq_answers as Record<string, unknown> | null),
  ]);
  if (requiresClearance) {
    blockedCats.add('cardiaco');
    blockedCats.add('hipertension');
    // Solo principiante/intermedio si requiere clearance medica.
    allowedDiffs = allowedDiffs.filter((d) => d !== 'avanzado');
    if (allowedDiffs.length === 0) allowedDiffs = ['principiante'];
  }
  // Embarazo (ACOG 804/2020): excluir ejercicios contraindicados en
  // gestacion (decubito supino prolongado, valsalva, alto impacto).
  if (pregnancyStatus) {
    blockedCats.add('embarazo');
    allowedDiffs = allowedDiffs.filter((d) => d !== 'avanzado');
    if (allowedDiffs.length === 0) allowedDiffs = ['principiante'];
  }
  const blockedArr = [...blockedCats];

  let query = supabase
    .from('exercise_catalog')
    .select(
      'slug, name_es, muscle_group_primary, muscle_group_secondary, location, exercise_type, difficulty, contraindications',
    )
    .eq('is_active', true)
    .in('location', [loc, 'both'])
    .in('difficulty', allowedDiffs);

  // Si requiere clearance, tambien excluir ejercicios explosivos.
  if (requiresClearance) {
    query = query.neq('exercise_type', 'explosivo');
  }

  const { data: exercisesRaw } = await query;

  // Filtrado de contraindicaciones en codigo (mas portable que .ov/.cd
  // entre versiones de supabase-js / PostgREST).
  let exercises = (exercisesRaw ?? []) as ExerciseRow[];
  if (blockedArr.length > 0) {
    exercises = exercises.filter((e) => {
      const cs = (e as unknown as { contraindications?: string[] | null })
        .contraindications;
      if (!Array.isArray(cs) || cs.length === 0) return true;
      for (const c of cs) {
        if (blockedArr.includes(`${c}`)) return false;
      }
      return true;
    });
  }
  if (exercises.length === 0) {
    return errorResponse('No exercises matched user constraints', 422);
  }

  // 2b) Excluir 'Deportes' (escalada, patinaje, drills deportivos): no son
  // parte de una rutina estructurada de gimnasio/casa.
  exercises = exercises.filter((e) => e.muscle_group_primary !== 'Deportes');

  // 2c) Filtrado por EQUIPO disponible (antes se ignoraba → planes con barra
  // para alguien en casa con bandas). Datos de equipo son texto libre, así que
  // usamos heurística conservadora con fallback si deja muy pocos ejercicios.
  const hasFullGym = userEquip.has('full_gym') ||
    (loc === 'gym' && userEquip.size === 0);
  const cap = {
    dumbbells: hasFullGym || userEquip.has('dumbbells'),
    barbell: hasFullGym || userEquip.has('barbell'),
    machines: hasFullGym || userEquip.has('machines'),
    bands: hasFullGym || userEquip.has('bands'),
    kettlebell: hasFullGym || userEquip.has('kettlebell'),
    cardioMachines: hasFullGym || userEquip.has('cardio_machines'),
    pullupBar: hasFullGym || userEquip.has('pullup_bar'),
  };
  // ¿Un token de equipo es satisfacible con lo que el usuario tiene? Los
  // objetos del hogar / peso corporal siempre lo son (improvisables). Maneja
  // alternativas "X o Y" dentro del mismo token.
  const tokenOk = (raw: string): boolean => {
    const t = raw.toLowerCase().trim();
    if (!t) return true;
    if (t.includes(' o ')) return t.split(' o ').some((s) => tokenOk(s));
    const household = [
      'cuerpo', 'colchoneta', 'silla', 'pared', 'toalla', 'botella', 'mochila',
      'piso', 'suelo', 'espacio', 'escal', 'sofa', 'mesa', 'cuerda', 'banco',
      'baston', 'musica', 'zapatill', 'ruta', 'cancha', 'marco', 'puerta',
      'soporte', 'apoyo', 'pelota', 'balon', 'protecc', 'guantes', 'saco',
      'traje', 'patines', 'raqueta', 'pala', 'segun', 'bicicleta', 'escaleras',
    ];
    if (household.some((h) => t.includes(h))) return true;
    if (t.includes('mancuern')) return cap.dumbbells;
    if (t.includes('kettlebell')) return cap.kettlebell || cap.dumbbells;
    if (t.includes('banda')) return cap.bands;
    if (t.includes('barra fija') || t.includes('paralel') || t.includes('dominad')) {
      return cap.pullupBar;
    }
    if (t.includes('smith') || t.includes('barra ez') || t.includes('t-bar') ||
        t.includes('barra')) {
      return cap.barbell;
    }
    if (t.includes('maquin') || t.includes('máquin') || t.includes('cable') ||
        t.includes('polea')) {
      return cap.machines;
    }
    if (t.includes('eliptica') || t.includes('remo') || t.includes('cinta')) {
      return cap.cardioMachines;
    }
    if (t.includes('piscina') || t.includes('escalada') || t.includes('muro')) {
      return false; // requiere instalación específica
    }
    return true; // desconocido → no sobre-filtrar
  };
  const equipOk = (e: ExerciseRow): boolean => {
    const arr = (e as unknown as { equipment?: unknown }).equipment;
    if (!Array.isArray(arr) || arr.length === 0) return true;
    return arr.every((tok) => tokenOk(`${tok}`));
  };
  if (!hasFullGym) {
    const byEquip = exercises.filter(equipOk);
    // Fallback: solo aplicamos el filtro si deja un catálogo sano (≥18).
    if (byEquip.length >= 18) exercises = byEquip;
  }

  // 2d) Separar cardio del trabajo de fuerza para dosificarlo por objetivo.
  const goalUp = `${profile.fitness_goal ?? ''}`.toUpperCase();
  const wantsConditioning =
    goalUp === 'LOSE_WEIGHT' || goalUp === 'IMPROVE_ENDURANCE' ||
    goalUp === 'TONE_BODY';
  const cardioCount =
    exercises.filter((e) => e.exercise_type === 'cardio').length;

  // 3) Construir prompt
  const exerciseListText = exercises
    .map(
      (e) =>
        `- ${e.slug} | ${e.name_es} | ${e.muscle_group_primary} | ${e.exercise_type} | ${e.difficulty}`,
    )
    .join('\n');

  const days = userProfile.training_days_per_week ?? 3;

  // Split: si el usuario eligió uno, se respeta. Si no, elegimos el óptimo
  // según los días disponibles (ACSM/NSCA: frecuencia 2x/músculo/semana).
  const splitGuidance = (() => {
    switch (splitPref) {
      case 'full_body':
        return `Estructura FULL BODY (cuerpo completo) elegida por el usuario: cada día entrena todo el cuerpo con 1 ejercicio compuesto por patrón (empuje, tirón, sentadilla/bisagra) + accesorios. Ideal para ${days} días.`;
      case 'upper_lower':
        return `Estructura UPPER/LOWER elegida por el usuario: alterna días de TREN SUPERIOR (pecho, espalda, hombros, brazos) y TREN INFERIOR (cuádriceps, femoral, glúteos, pantorrillas). Distribuye los ${days} días alternando.`;
      case 'push_pull_legs':
        return `Estructura PUSH/PULL/LEGS elegida por el usuario: días de EMPUJE (pecho, hombros, tríceps), TIRÓN (espalda, bíceps) y PIERNA (cuádriceps, femoral, glúteos, pantorrillas). Rota P/P/L a lo largo de los ${days} días.`;
      case 'bro_split':
        return `Estructura por GRUPO MUSCULAR/DÍA (bro split) elegida por el usuario: asigna 1-2 grupos musculares principales por día sin repetir en exceso. Apto solo si hay ${days}≥4 días; si no, agrupa.`;
      default:
        // Sin preferencia → elegir el split óptimo por días.
        if (days <= 3) {
          return `Sin preferencia de split → usa FULL BODY (cada día cuerpo completo): es lo óptimo para ${days} días/semana (mayor frecuencia por músculo).`;
        }
        if (days === 4) {
          return `Sin preferencia de split → usa UPPER/LOWER (2 superior + 2 inferior): óptimo para 4 días.`;
        }
        return `Sin preferencia de split → usa PUSH/PULL/LEGS: óptimo para ${days}-6 días.`;
    }
  })();

  // Acondicionamiento/cardio según objetivo (la lista incluye ${cardioCount}
  // ejercicios de tipo cardio).
  const cardioGuidance = cardioCount === 0
    ? '- No hay ejercicios de cardio en la lista; no agregues cardio.'
    : wantsConditioning
      ? `- ACONDICIONAMIENTO (objetivo ${goalUp}): incluye 1 ejercicio tipo "cardio" como FINISHER al final de 2-3 días (no al inicio). El resto del día es fuerza. El cardio NO reemplaza el trabajo de fuerza.`
      : '- Cardio: opcional, máximo 1 finisher corto por semana. El foco es la fuerza/hipertrofia.';

  // Volumen semanal objetivo por músculo (Schoenfeld 2017 meta-análisis;
  // NSCA). Ajustado a los días disponibles y a clearance.
  const lowVol = requiresClearance || pregnancyStatus;
  const volumeGuidance = lowVol
    ? '~6-10 series semanales por grupo muscular principal (volumen reducido por seguridad).'
    : days <= 3
      ? '~8-12 series semanales por grupo muscular principal (con pocos días, prioriza compuestos que cubren varios músculos).'
      : '~10-16 series semanales por grupo muscular principal (10 mínimo efectivo, no pases de ~20).';

  const repScheme = goalUp === 'GAIN_MUSCLE'
    ? 'hipertrofia 8-12 reps (algunos compuestos 6-8)'
    : goalUp === 'LOSE_WEIGHT' || goalUp === 'TONE_BODY'
      ? 'mixto 10-15 reps con descansos cortos para mayor gasto'
      : goalUp === 'IMPROVE_ENDURANCE'
        ? 'resistencia 12-20 reps, descansos cortos'
        : 'fuerza 4-6 en compuestos / hipertrofia 8-12 en accesorios';

  const systemPrompt = `Eres un entrenador de fuerza certificado (NSCA/ACSM) que planifica rutinas para GymGram. NUNCA inventes ejercicios: solo usas los slugs de la lista entregada. Devuelves JSON estricto sin texto adicional.

${profileContext(userProfile)}${injuriesClause}

ESTRUCTURA / SPLIT:
${splitGuidance}

Ejercicios disponibles (slug | nombre | musculo primario | tipo | dificultad):
${exerciseListText}

Reglas (cúmplelas todas):
1. SPLIT: respeta la estructura indicada arriba. Cada día debe tener un "focus" coherente con esa estructura.
2. SELECCIÓN: 4 a 7 ejercicios por día. Empieza SIEMPRE con los compuestos (compuesto) y deja aislamiento/estabilización al final.
3. VOLUMEN SEMANAL: apunta a ${volumeGuidance} Reparte las series entre los días para no sobrecargar un músculo en un solo día.
4. BALANCE: equilibra empuje vs tirón (pecho/hombro/tríceps ≈ espalda/bíceps) y no descuides piernas (cuádriceps, femoral, glúteos). Evita rutinas "solo torso".
5. REPS: ${repScheme}. Ajusta según si el ejercicio es compuesto (menos reps) o aislamiento (más reps).
6. SERIES: ${requiresClearance ? '2-3 por ejercicio (volumen reducido por seguridad)' : '3-4 por ejercicio'}.
7. DESCANSO (rest_seconds): compuestos pesados 120-180s, accesorios 60-90s, cardio/core 30-60s.
8. CARDIO/ACONDICIONAMIENTO:
${cardioGuidance}
9. Solo retorna ejercicios cuyo slug esté EXACTO en la lista. No repitas el mismo ejercicio dos veces el mismo día.
10. NO incluyas texto fuera del JSON. Formato exacto:
{"days":[{"day":1,"focus":"Empuje (pecho, hombro, tríceps)","exercises":[{"slug":"press-banca-barra","name":"Press de banca con barra","sets":4,"reps":"6-8","rest_seconds":120}]}]}`;

  let plan: PlanResponse;
  try {
    plan = await chatJson<PlanResponse>({
      model: 'gpt-4o-mini',
      temperature: 0.4,
      maxTokens: 1800,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: `Arma mi plan semanal de ${userProfile.training_days_per_week} dias, sesiones de ~${userProfile.session_duration_min} min, objetivo ${userProfile.fitness_goal ?? 'mantener'}.`,
        },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // 4) Validar que todos los slugs existan y, si requiere clearance, recortar
  // -1 serie por ejercicio para reducir volumen.
  const validSlugs = new Set(exercises.map((e) => e.slug));
  const muscleBySlug = new Map(exercises.map((e) => [e.slug, e.muscle_group_primary]));
  let cleanDays = (plan.days ?? []).map((d) => ({
    ...d,
    exercises: (d.exercises ?? [])
      .filter((ex) => validSlugs.has(ex.slug))
      .map((ex) =>
        requiresClearance
          ? { ...ex, sets: Math.max(1, (ex.sets ?? 3) - 1) }
          : ex,
      ),
  }));
  // Descartar días que quedaron sin ejercicios válidos.
  cleanDays = cleanDays.filter((d) => d.exercises.length > 0);

  const finalPlan = { days: cleanDays };

  // 4b) AUDITORÍA DE CALIDAD del plan (igual que nutrición tiene quality_flags).
  // Volumen semanal por grupo muscular + balance empuje/tirón/pierna.
  const weeklySetsByMuscle: Record<string, number> = {};
  let totalSets = 0;
  for (const d of cleanDays) {
    for (const ex of d.exercises) {
      const m = muscleBySlug.get(ex.slug) ?? 'Otros';
      const s = Math.max(0, Number(ex.sets ?? 0));
      weeklySetsByMuscle[m] = (weeklySetsByMuscle[m] ?? 0) + s;
      totalSets += s;
    }
  }
  const sumOf = (groups: string[]) =>
    groups.reduce((acc, g) => acc + (weeklySetsByMuscle[g] ?? 0), 0);
  const pushSets = sumOf(['Pecho', 'Hombros', 'Tríceps']);
  const pullSets = sumOf(['Espalda', 'Bíceps']);
  const legSets = sumOf(['Cuádriceps', 'Femoral', 'Glúteos', 'Pantorrillas']);
  const ratio = (a: number, b: number) => (b > 0 ? a / b : (a > 0 ? 99 : 1));
  // Flags (no rechazan el plan; informan al cliente / a futuras métricas).
  const pushPullImbalanced =
    !lowVol && (pushSets + pullSets > 0) &&
    (ratio(pushSets, pullSets) > 2 || ratio(pullSets, pushSets) > 2);
  const legsNeglected = !lowVol && days >= 3 && legSets < 6 &&
    !injuries.some((i) => /rodilla|lumbar|cadera/i.test(i));
  const tooFewExercises = cleanDays.some((d) => d.exercises.length < 3);
  const lowWeeklyVolume = !lowVol && cleanDays.length > 0 &&
    totalSets < cleanDays.length * 9; // <~9 series efectivas por día
  const qualityFlags = {
    weekly_sets_by_muscle: weeklySetsByMuscle,
    push_sets: pushSets,
    pull_sets: pullSets,
    leg_sets: legSets,
    total_weekly_sets: totalSets,
  };
  const lowQuality =
    pushPullImbalanced || legsNeglected || tooFewExercises || lowWeeklyVolume ||
    cleanDays.length < Math.min(days, 2);

  // Persistir cache (upsert por user_id). Errores no son fatales: igual
  // devolvemos el plan al cliente.
  try {
    await supabase
      .from('routine_plans')
      .upsert({
        user_id: user.id,
        plan_json: finalPlan,
        days_per_week: userProfile.training_days_per_week,
        session_duration_min: userProfile.session_duration_min,
        catalog_size: exercises.length,
        quality_flags: qualityFlags,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' });
  } catch (e) {
    console.error('routine_plans upsert warning:', e);
  }

  const response: Record<string, unknown> = {
    ok: true,
    plan: finalPlan,
    catalog_size: exercises.length,
    cached: false,
    quality_flags: qualityFlags,
    low_quality: lowQuality,
    split_used: splitPref || 'auto',
  };
  if (requiresClearance) {
    response.medical_clearance_warning = true;
    response.medical_clearance_message =
      'Detectamos posibles condiciones de salud. Consulta a un medico antes de empezar y avisanos si algun ejercicio te incomoda.';
  }
  return jsonResponse(response);
});

// Silencia "unused" para corsHeaders re-export-style si quisieras.
export { corsHeaders };
