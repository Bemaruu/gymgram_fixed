// analyze-routine — opinión IA sobre rutinas importadas por el usuario.
//
// Para usuarios que eligieron analyze_existing_routine durante el onboarding:
// no genera rutina, sólo evalúa la que el usuario aportó.
//
// Lee las rutinas activas con source='user_imported' del usuario, hace match
// contra exercise_catalog cuando hay exercise_id, calcula cobertura muscular,
// detecta contraindicaciones (lesiones + PAR-Q+) y pide a GPT-4o-mini un
// resumen estructurado en JSON.
//
// Output JSON:
//   { ok: true, analysis: { summary, strengths[], warnings[], suggestions[],
//     muscle_coverage{}, generated_at } }
//
// Persiste el resultado en `routines.routine_analysis` de cada día con
// status='completed' para que la UI lo muestre como banner.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { chatJson, OpenAIError } from '../_shared/openai.ts';
import { enforceMonthlyCap, UsageCapError } from '../_shared/usage.ts';

type RoutineRow = {
  id: string;
  day_of_week: number | null;
  title: string | null;
};

type ExerciseRow = {
  id: string;
  routine_id: string;
  name: string;
  sets: number | null;
  reps: string | null;
  rest_seconds: number | null;
  muscle_group: string | null;
  is_custom: boolean | null;
  exercise_id: string | null;
};

type CatalogRow = {
  id: string;
  name_es: string;
  muscle_group_primary: string;
  exercise_type: string | null;
  contraindications: string[] | null;
};

type AnalysisResponse = {
  summary: string;
  strengths: string[];
  warnings: Array<{ text: string; severity: 'low' | 'medium' | 'high' }>;
  suggestions: string[];
  muscle_coverage: Record<string, number>;
};

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
  if (parq['chest_pain'] === true) out.add('cardiaco');
  if (parq['dizziness_fainting'] === true) out.add('cardiaco');
  return [...out];
}

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  const supabase = serviceClient();

  try {
    await enforceMonthlyCap(supabase, user.id, 'analyze-routine');
  } catch (e) {
    if (e instanceof UsageCapError) return errorResponse('Monthly AI limit reached', 429);
    throw e;
  }

  // 1) Perfil + onboarding (lesiones, PAR-Q+).
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, fitness_goal, training_location, weight, age, gender, requires_medical_clearance, parq_answers')
    .eq('id', user.id)
    .maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);

  const { data: onbRows } = await supabase
    .from('user_onboarding_data')
    .select('training_level, experience_level, injuries')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(1);
  const onboarding = onbRows?.[0];

  const injuries = Array.isArray(onboarding?.injuries)
    ? (onboarding!.injuries as unknown[])
        .map((x) => `${x}`.trim())
        .filter((s) => s.length > 0 && s.toLowerCase() !== 'ninguna')
    : [];

  const blockedCats = new Set<string>([
    ...mapInjuriesToContraindications(injuries),
    ...parqToContraindications(profile.parq_answers as Record<string, unknown> | null),
  ]);
  if (profile.requires_medical_clearance === true) {
    blockedCats.add('cardiaco');
    blockedCats.add('hipertension');
  }

  // 2) Rutinas importadas activas del usuario.
  const { data: routines } = await supabase
    .from('routines')
    .select('id, day_of_week, title')
    .eq('user_id', user.id)
    .eq('kind', 'personal')
    .eq('source', 'user_imported')
    .eq('is_archived', false);
  const routineList = (routines ?? []) as RoutineRow[];
  if (routineList.length === 0) {
    return errorResponse('No imported routine found for this user', 404);
  }
  const routineIds = routineList.map((r) => r.id);

  const { data: exRows } = await supabase
    .from('routine_exercises')
    .select('id, routine_id, name, sets, reps, rest_seconds, muscle_group, is_custom, exercise_id')
    .in('routine_id', routineIds)
    .order('order_index', { ascending: true });
  const exercises = (exRows ?? []) as ExerciseRow[];

  // 3) Catálogo para los exercise_id presentes (para contraindicaciones y nombre canónico).
  const catalogIds = [...new Set(exercises.map((e) => e.exercise_id).filter((x): x is string => !!x))];
  let catalogById: Record<string, CatalogRow> = {};
  if (catalogIds.length > 0) {
    const { data: catRows } = await supabase
      .from('exercise_catalog')
      .select('id, name_es, muscle_group_primary, exercise_type, contraindications')
      .in('id', catalogIds);
    catalogById = Object.fromEntries(
      ((catRows ?? []) as CatalogRow[]).map((r) => [r.id, r]),
    );
  }

  // 4) Cobertura muscular y warnings preliminares.
  const coverage: Record<string, number> = {};
  const preWarnings: string[] = [];
  let customCount = 0;
  for (const ex of exercises) {
    const cat = ex.exercise_id ? catalogById[ex.exercise_id] : null;
    const mg = cat?.muscle_group_primary ?? ex.muscle_group ?? 'otro';
    coverage[mg] = (coverage[mg] ?? 0) + 1;
    if (ex.is_custom || !cat) customCount += 1;
    const cs = cat?.contraindications ?? [];
    for (const c of cs) {
      if (blockedCats.has(c)) {
        preWarnings.push(
          `"${ex.name}" tiene contraindicación "${c}" y el usuario reportó esa zona.`,
        );
        break;
      }
    }
  }

  // 5) Prompt para opinión estructurada.
  const dayLines = routineList
    .map((r) => {
      const exs = exercises.filter((e) => e.routine_id === r.id);
      const items = exs
        .map((e) => {
          const cat = e.exercise_id ? catalogById[e.exercise_id] : null;
          const label = cat ? `${cat.name_es} (${cat.muscle_group_primary})` : `${e.name} (custom)`;
          const detail = e.sets && e.sets > 1 && e.reps
            ? `${e.sets}×${e.reps}`
            : (e.reps ?? '?');
          return `  - ${label} — ${detail}`;
        })
        .join('\n');
      return `Día ${(r.day_of_week ?? 0) + 1} (${r.title ?? ''}):\n${items}`;
    })
    .join('\n\n');

  const safetyClause = blockedCats.size > 0
    ? `\nEl usuario tiene contraindicaciones: ${[...blockedCats].join(', ')}. Marca como warning de severidad "high" cualquier ejercicio incompatible.`
    : '';
  const goalText = profile.fitness_goal ?? 'mantener';

  const systemPrompt = `Eres un entrenador profesional. Analizas la rutina propia de un usuario de GymGram. No la generas: SÓLO opinas.

Perfil: objetivo ${goalText}, ${profile.age ?? '?'} años, ${profile.gender ?? '?'}, ${profile.weight ?? '?'} kg, nivel ${onboarding?.training_level ?? onboarding?.experience_level ?? '?'}.${safetyClause}

Devuelve JSON exacto con:
{
  "summary": "1 párrafo breve y honesto (máx 60 palabras)",
  "strengths": ["..." máx 3],
  "warnings": [{"text":"...", "severity":"low|medium|high"} máx 4],
  "suggestions": ["..." máx 4],
  "muscle_coverage": {"chest": 3, "back": 2, ...}
}

Reglas:
- Si hay contraindicaciones declaradas y la rutina las incumple, severity="high".
- Si hay grupos musculares sin trabajo, sugierelo.
- Si hay ${customCount} ejercicios personalizados (no canónicos), mencionarlo brevemente.
- No inventes datos del perfil. No des consejos médicos.`;

  let analysis: AnalysisResponse;
  try {
    analysis = await chatJson<AnalysisResponse>({
      model: 'gpt-4o-mini',
      temperature: 0.3,
      maxTokens: 900,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: `Rutina del usuario:\n\n${dayLines}\n\nWarnings preliminares detectadas en código: ${preWarnings.length > 0 ? preWarnings.join(' | ') : 'ninguna'}.`,
        },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // 6) Override de cobertura con el cálculo determinístico nuestro.
  analysis.muscle_coverage = coverage;

  // 7) Persistir en todas las rutinas activas del usuario.
  const generatedAt = new Date().toISOString();
  const analysisPayload = {
    status: 'completed',
    source: 'openai-gpt-4o-mini',
    generated_at: generatedAt,
    ...analysis,
  };
  await supabase
    .from('routines')
    .update({ routine_analysis: analysisPayload })
    .in('id', routineIds);

  return jsonResponse({
    ok: true,
    analysis: { ...analysis, generated_at: generatedAt },
  });
});
