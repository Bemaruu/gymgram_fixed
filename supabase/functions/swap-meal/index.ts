// swap-meal — regenera UN solo plato del plan semanal sin tocar el resto.
//
// Body: { week_index: number, day: 1..7, meal_index: number, exclude?: string[] }
// Output: { ok: true, meal: {meal_type, foods:[{name,grams,kcal,protein,carbs,fat}]} }
//
// Filtros: respeta país, dieta, alergias, items ai_exclude_from_plan,
// y excluye los nombres listados en `exclude` (para que el usuario itere).

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
  country_relevance?: string[] | null;
  popular_in?: string[] | null;
  ai_exclude_from_plan?: boolean | null;
};

type MealOut = {
  meal_type: string;
  foods: Array<{
    name: string;
    grams: number;
    kcal: number;
    protein: number;
    carbs: number;
    fat: number;
  }>;
};

const MEAL_LABELS: Record<string, string> = {
  breakfast: 'Desayuno',
  lunch: 'Almuerzo',
  dinner: 'Cena',
  snack: 'Merienda',
  pre_workout: 'Pre-entreno',
  post_workout: 'Post-entreno',
};

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  const supabase = serviceClient();
  let body: { week_index?: number; day?: number; meal_index?: number; exclude?: string[] } = {};
  try { body = await req.json(); } catch { /* empty */ }

  const day = Number(body.day ?? 1);
  const mealIndex = Number(body.meal_index ?? 0);
  const excludeNames = (body.exclude ?? []).map((s) => s.toLowerCase());
  if (!Number.isFinite(day) || day < 1 || day > 7) {
    return errorResponse('day must be 1..7', 400);
  }

  try { await enforceMonthlyCap(supabase, user.id, 'swap-meal'); }
  catch (e) {
    if (e instanceof UsageCapError) return errorResponse('Monthly AI limit reached', 429);
    throw e;
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, weight, age, gender, fitness_goal, country_code, eating_disorder_risk')
    .eq('id', user.id).maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);

  const { data: goals } = await supabase
    .from('nutrition_goals')
    .select('daily_kcal, protein_g, carbs_g, fat_g, meals_per_day')
    .eq('user_id', user.id).maybeSingle();

  const { data: onbRows } = await supabase
    .from('user_onboarding_data')
    .select('food_preferences, allergies, disliked_foods, country_code, meals_per_day')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false }).limit(1);
  const onb = onbRows?.[0];

  const countryCode = (
    `${profile.country_code ?? onb?.country_code ?? 'CL'}`
      .toUpperCase().replace(/[^A-Z]/g, '') || 'CL'
  ).slice(0, 2);

  const preferences = new Set<string>(
    [...((onb?.food_preferences as string[] | null) ?? [])].map((s) => s.toLowerCase()),
  );
  const blacklist = new Set<string>(
    [
      ...((onb?.allergies as string[] | null) ?? []),
      ...((onb?.disliked_foods as string[] | null) ?? []),
    ].map((s) => s.toLowerCase()),
  );

  const { data: foodsRaw } = await supabase
    .from('custom_foods')
    .select('id, name, category, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, country_relevance, popular_in, ai_exclude_from_plan')
    .overlaps('country_relevance', [countryCode, 'GLOBAL'])
    .limit(350);

  const foods = (foodsRaw ?? []) as FoodRow[];
  const filtered = foods.filter((f) => {
    if (f.ai_exclude_from_plan === true) return false;
    const n = f.name.toLowerCase();
    if (excludeNames.includes(n)) return false;
    for (const b of blacklist) { if (b && n.includes(b)) return false; }
    return true;
  });
  if (filtered.length === 0) return errorResponse('No foods', 422);

  const mealsPerDay = goals?.meals_per_day ?? 4;
  const meals = mealsPerDay <= 3
    ? ['breakfast','lunch','dinner']
    : mealsPerDay === 4
      ? ['breakfast','lunch','snack','dinner']
      : mealsPerDay === 5
        ? ['breakfast','snack','lunch','snack','dinner']
        : ['breakfast','snack','lunch','snack','dinner','snack'];
  const mealType = meals[Math.max(0, Math.min(mealIndex, meals.length - 1))];

  const isHomePopular = (f: FoodRow) =>
    Array.isArray(f.popular_in) &&
    f.popular_in.some((c) => c.toUpperCase() === countryCode);

  // Lista compacta: prioriza [CASERO]. Limitamos a 80 items.
  const sorted = [...filtered].sort((a, b) => (isHomePopular(a) ? 0 : 1) - (isHomePopular(b) ? 0 : 1));
  const foodList = sorted.slice(0, 80).map((f) => {
    const tag = isHomePopular(f) ? ' [CASERO]' : '';
    return `- ${f.name}${tag} | ${f.kcal_per_100g}kcal P${f.protein_per_100g} C${f.carbs_per_100g} G${f.fat_per_100g}`;
  }).join('\n');

  const kcalTarget = goals?.daily_kcal ?? 2000;
  const isHomeStyle = preferences.has('omnivore') || preferences.has('casero') ||
    preferences.size === 0 || preferences.has('no_preference');
  const isVegan = preferences.has('vegan') || preferences.has('vegana');

  const system = `Eres NutriCore. Devuelves UN SOLO plato en JSON estricto, sin texto adicional.

CONTEXTO
- País: ${countryCode}
- Dieta: ${[...preferences].join(', ') || 'casera'}
- Comida a regenerar: ${MEAL_LABELS[mealType]} (meal_type=${mealType})
- Excluye estos nombres ya usados: ${excludeNames.length ? excludeNames.join(', ') : '(ninguno)'}
- kcal aproximadas del plato: ${Math.round(kcalTarget / meals.length)} ± 20%

CATÁLOGO (usa SOLO estos nombres literales; [CASERO]=cotidiano en el país):
${foodList}

REGLAS:
1. Devuelve 2-4 alimentos coherentes para esta comida.
2. Si es almuerzo o cena: al menos 1 fuente proteica clara + 1 carbo o vegetal. Fruta NUNCA como plato principal.
3. ${isHomeStyle ? `Prioriza items [CASERO]. Plato sencillo, popular, ingredientes que siempre hay en una casa de ${countryCode}.` : 'Respeta la dieta declarada.'}
${isVegan ? '4. Dieta VEGANA: nada de carne/pescado/lácteos/huevo.' : ''}
5. Usa SOLO nombres exactos del catálogo.
6. kcal = round(grams/100 * kcal_per_100g). Lo mismo para protein/carbs/fat. Redondea a enteros.

FORMATO JSON EXACTO:
{
  "meal_type": "${mealType}",
  "foods": [
    {"name":"Cazuela de pollo","grams":350,"kcal":333,"protein":30,"carbs":35,"fat":7}
  ]
}`;

  let meal: MealOut;
  try {
    meal = await chatJson<MealOut>({
      model: 'gpt-4o-mini',
      temperature: 0.8,
      maxTokens: 600,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: 'Devuelve solo el JSON con un plato nuevo coherente.' },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // Validar nombres
  const validNames = new Map(filtered.map((f) => [f.name.toLowerCase(), f] as const));
  const cleanFoods = (meal.foods ?? []).filter((f) => validNames.has((f.name ?? '').toLowerCase()));
  if (cleanFoods.length === 0) return errorResponse('AI returned no valid foods', 502);

  return jsonResponse({
    ok: true,
    week_index: body.week_index ?? null,
    day,
    meal_index: mealIndex,
    meal: { meal_type: mealType, foods: cleanFoods },
  });
});
