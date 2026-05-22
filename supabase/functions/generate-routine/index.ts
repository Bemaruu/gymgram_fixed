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

type ExerciseRow = {
  slug: string;
  name_es: string;
  muscle_group_primary: string;
  muscle_group_secondary: string[] | null;
  location: 'gym' | 'home' | 'both';
  exercise_type: string;
  difficulty: 'principiante' | 'intermedio' | 'avanzado';
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

  let body: { days_per_week?: number; session_duration_min?: number } = {};
  try {
    body = await req.json();
  } catch { /* body opcional */ }

  const supabase = serviceClient();

  // 1) Cargar perfil + onboarding
  const { data: profile } = await supabase
    .from('profiles')
    .select(
      'id, fitness_goal, training_location, weight, target_weight, age, gender',
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
  const allowedDiffs = difficultyFor(userProfile.experience_level);

  const { data: exercisesRaw } = await supabase
    .from('exercise_catalog')
    .select(
      'slug, name_es, muscle_group_primary, muscle_group_secondary, location, exercise_type, difficulty',
    )
    .eq('is_active', true)
    .in('location', [loc, 'both'])
    .in('difficulty', allowedDiffs);

  const exercises = (exercisesRaw ?? []) as ExerciseRow[];
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

${profileContext(userProfile)}

Ejercicios disponibles (slug | nombre | musculo primario | tipo | dificultad):
${exerciseListText}

Reglas:
- Distribuye los ${userProfile.training_days_per_week} dias cubriendo los grupos musculares principales.
- Cada dia: 4 a 7 ejercicios. Prioriza compuestos al inicio.
- Series: 3-4. Reps: rangos segun objetivo (fuerza 4-6, hipertrofia 8-12, resistencia 12-15).
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

  // 4) Validar que todos los slugs existan
  const validSlugs = new Set(exercises.map((e) => e.slug));
  const cleanDays = (plan.days ?? []).map((d) => ({
    ...d,
    exercises: (d.exercises ?? []).filter((ex) => validSlugs.has(ex.slug)),
  }));

  return jsonResponse({
    ok: true,
    plan: { days: cleanDays },
    catalog_size: exercises.length,
  });
});

// Silencia "unused" para corsHeaders re-export-style si quisieras.
export { corsHeaders };
