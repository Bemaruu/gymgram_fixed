// generate-nutrition-plan — RAG sobre custom_foods.
//
// Lee perfil + nutrition_goals + user_dietary_restrictions + onboarding,
// filtra custom_foods por restricciones/preferencias, y le pide a GPT-4o-mini
// que arme un plan diario seleccionando SOLO alimentos de la lista entregada.
//
// Output JSON:
//   { ok: true, plan: { meals: [ { meal_type, foods: [{name, grams, kcal, protein, carbs, fat}] } ], totals: {...} } }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { chatJson, OpenAIError } from '../_shared/openai.ts';
import { enforceMonthlyCap, UsageCapError } from '../_shared/usage.ts';

type FoodRow = {
  id: string;
  name: string;
  category: string;
  kcal_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
  fiber_per_100g: number;
};

type Plan = {
  meals: Array<{
    meal_type: string;
    foods: Array<{
      name: string;
      grams: number;
      kcal: number;
      protein: number;
      carbs: number;
      fat: number;
    }>;
  }>;
  totals: { kcal: number; protein: number; carbs: number; fat: number };
};

const MEAL_LABELS: Record<string, string> = {
  breakfast: 'Desayuno',
  lunch: 'Almuerzo',
  dinner: 'Cena',
  snack: 'Merienda',
  pre_workout: 'Pre-entreno',
  post_workout: 'Post-entreno',
};

function mealsByCount(n: number): string[] {
  if (n <= 3) return ['breakfast', 'lunch', 'dinner'];
  if (n === 4) return ['breakfast', 'lunch', 'snack', 'dinner'];
  if (n === 5) return ['breakfast', 'snack', 'lunch', 'snack', 'dinner'];
  return ['breakfast', 'snack', 'lunch', 'snack', 'dinner', 'snack'];
}

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  const supabase = serviceClient();

  // Tope duro de costo IA (safety net mensual)
  try {
    await enforceMonthlyCap(supabase, user.id, 'generate-nutrition-plan');
  } catch (e) {
    if (e instanceof UsageCapError) return errorResponse('Monthly AI limit reached', 429);
    throw e;
  }

  // 1) profile
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, fitness_goal, weight, age, gender')
    .eq('id', user.id)
    .maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);

  // 2) nutrition_goals
  const { data: goals } = await supabase
    .from('nutrition_goals')
    .select('daily_kcal, protein_g, carbs_g, fat_g, meals_per_day')
    .eq('user_id', user.id)
    .maybeSingle();

  // 3) onboarding (food preferences, allergies, disliked, cooking time)
  const { data: onbRows } = await supabase
    .from('user_onboarding_data')
    .select(
      'food_preferences, allergies, disliked_foods, cooking_time_preference, meals_per_day',
    )
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(1);
  const onb = onbRows?.[0];

  // 4) restricciones explicitas
  const { data: restrictions } = await supabase
    .from('user_dietary_restrictions')
    .select('restriction_type, value')
    .eq('user_id', user.id);

  const allergies = new Set<string>(
    [
      ...((onb?.allergies as string[] | null) ?? []),
      ...((restrictions ?? [])
        .filter((r) => r.restriction_type === 'allergy')
        .map((r) => r.value as string)),
    ].map((s) => s.toLowerCase()),
  );
  const intolerances = new Set<string>(
    (restrictions ?? [])
      .filter((r) => r.restriction_type === 'intolerance')
      .map((r) => (r.value as string).toLowerCase()),
  );
  const preferences = new Set<string>(
    [
      ...((onb?.food_preferences as string[] | null) ?? []),
      ...((restrictions ?? [])
        .filter((r) => r.restriction_type === 'preference')
        .map((r) => r.value as string)),
    ].map((s) => s.toLowerCase()),
  );
  const disliked = new Set<string>(
    ((onb?.disliked_foods as string[] | null) ?? []).map((s) => s.toLowerCase()),
  );

  // 5) Catalog: traer hasta ~150 alimentos para no inflar prompt
  const { data: foodsRaw } = await supabase
    .from('custom_foods')
    .select(
      'id, name, category, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g',
    )
    .order('category')
    .limit(200);

  const foods = (foodsRaw ?? []) as FoodRow[];
  const blacklist = new Set([...allergies, ...intolerances, ...disliked]);
  const filtered = foods.filter((f) => {
    const n = f.name.toLowerCase();
    for (const b of blacklist) {
      if (b && n.includes(b)) return false;
    }
    return true;
  });
  if (filtered.length === 0) {
    return errorResponse('No foods matched user constraints', 422);
  }

  // 6) Targets
  const kcalTarget = goals?.daily_kcal ?? 2000;
  const pTarget = goals?.protein_g ?? 120;
  const cTarget = goals?.carbs_g ?? 220;
  const fTarget = goals?.fat_g ?? 60;
  const mealsPerDay =
    goals?.meals_per_day ?? (onb?.meals_per_day as number | undefined) ?? 4;
  const meals = mealsByCount(mealsPerDay);

  // 7) Prompt
  const foodList = filtered
    .slice(0, 120)
    .map(
      (f) =>
        `- ${f.name} (${f.category}) | ${f.kcal_per_100g} kcal/100g | P${f.protein_per_100g} C${f.carbs_per_100g} G${f.fat_per_100g}`,
    )
    .join('\n');

  const system = `Eres un planificador nutricional para GymGram. NUNCA inventes alimentos. Solo usas los NOMBRES exactos de la lista que te entregan. Devuelves JSON estricto sin texto adicional.

Perfil:
- Objetivo: ${profile.fitness_goal ?? 'mantener'}
- Peso: ${profile.weight ?? 'desconocido'} kg
- Edad: ${profile.age ?? 'desconocida'}
- Genero: ${profile.gender ?? 'desconocido'}
- Preferencias: ${[...preferences].join(', ') || 'ninguna'}
- Tiempo de cocina: ${onb?.cooking_time_preference ?? 'sin preferencia'}

Targets diarios: ${kcalTarget} kcal, P${pTarget}g, C${cTarget}g, G${fTarget}g.
Comidas del dia (${meals.length}): ${meals.map((m) => MEAL_LABELS[m]).join(', ')}.

Alimentos disponibles (nombre | categoria | kcal/100g | macros/100g):
${foodList}

Reglas:
- Cada comida: 2 a 4 alimentos. Variedad entre comidas.
- Suma de kcal del dia debe estar dentro de +/- 10% del target.
- Proteina debe llegar al menos al 90% del target.
- Usa SOLO nombres exactos de la lista (literal).
- Calcula tu mismo kcal/protein/carbs/fat por porcion (gramos del item / 100 * valor_por_100g, redondea a 0 decimales).
- Formato JSON exacto:
  {"meals":[{"meal_type":"breakfast","foods":[{"name":"Avena","grams":80,"kcal":300,"protein":10,"carbs":54,"fat":6}]}],"totals":{"kcal":2000,"protein":120,"carbs":220,"fat":60}}`;

  let plan: Plan;
  try {
    plan = await chatJson<Plan>({
      model: 'gpt-4o-mini',
      temperature: 0.5,
      maxTokens: 1800,
      messages: [
        { role: 'system', content: system },
        {
          role: 'user',
          content: `Arma mi plan de hoy con ${meals.length} comidas (${meals.map((m) => MEAL_LABELS[m]).join(', ')}).`,
        },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // 8) Validar que los nombres de alimento existan en la lista
  const validNames = new Set(filtered.map((f) => f.name.toLowerCase()));
  const cleanMeals = (plan.meals ?? []).map((m) => ({
    ...m,
    foods: (m.foods ?? []).filter((f) =>
      validNames.has((f.name ?? '').toLowerCase()),
    ),
  }));

  return jsonResponse({
    ok: true,
    plan: { meals: cleanMeals, totals: plan.totals },
    catalog_size: filtered.length,
  });
});
