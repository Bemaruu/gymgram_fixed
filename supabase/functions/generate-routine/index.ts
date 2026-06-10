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
      .select('plan_json, days_per_week, session_duration_min, catalog_size')
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
      'id, fitness_goal, training_location, weight, target_weight, age, gender, requires_medical_clearance, parq_answers',
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

  // 3) Construir prompt
  const exerciseListText = exercises
    .map(
      (e) =>
        `- ${e.slug} | ${e.name_es} | ${e.muscle_group_primary} | ${e.exercise_type} | ${e.difficulty}`,
    )
    .join('\n');

  const systemPrompt = `Eres un planificador de rutinas para GymGram. NUNCA inventes ejercicios. Solo usas los slugs de la lista que te entregan. Devuelves JSON estricto sin texto adicional.

${profileContext(userProfile)}${injuriesClause}

Ejercicios disponibles (slug | nombre | musculo primario | tipo | dificultad):
${exerciseListText}

Reglas:
- Distribuye los ${userProfile.training_days_per_week} dias cubriendo los grupos musculares principales.
- Cada dia: 4 a 7 ejercicios. Prioriza compuestos al inicio.
- Series: ${requiresClearance ? '2-3 (reduce volumen por seguridad)' : '3-4'}. Reps: rangos segun objetivo (fuerza 4-6, hipertrofia 8-12, resistencia 12-15).
- Rest: 60-180 seg segun tipo de ejercicio.
- Solo retorna ejercicios cuyo slug este en la lista.
- Formato JSON exacto:
  {"days":[{"day":1,"focus":"Pecho y triceps","exercises":[{"slug":"press-banca-barra","name":"Press de banca con barra","sets":4,"reps":"6-8","rest_seconds":120}]}]}`;

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
  const cleanDays = (plan.days ?? []).map((d) => ({
    ...d,
    exercises: (d.exercises ?? [])
      .filter((ex) => validSlugs.has(ex.slug))
      .map((ex) =>
        requiresClearance
          ? { ...ex, sets: Math.max(1, (ex.sets ?? 3) - 1) }
          : ex,
      ),
  }));

  const finalPlan = { days: cleanDays };

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
