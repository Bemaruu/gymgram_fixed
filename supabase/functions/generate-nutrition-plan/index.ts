// generate-nutrition-plan — RAG sobre custom_foods, plan SEMANAL cacheado.
//
// Lee perfil + nutrition_goals + user_dietary_restrictions + onboarding,
// filtra custom_foods por restricciones/preferencias, y le pide a GPT-4o-mini
// que arme un plan semanal (7 dias) seleccionando SOLO alimentos del catalogo.
// Persiste el plan en public.nutrition_plans para cache semanal (1 llamada
// IA por usuario por semana).
//
// Body opcional: { week_index?: number }
// Output JSON:
//   { ok: true, week_index, plan: { week: DayPlan[] }, totals: {...},
//     catalog_size, eating_disorder_safe_mode, low_variety, low_quality }

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

type DayPlan = {
  day: number;
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
  daily_totals?: { kcal: number; protein: number; carbs: number; fat: number };
};

type WeeklyPlan = {
  week: DayPlan[];
  totals?: { daily_avg: unknown; weekly: unknown };
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

  let body: { week_index?: number } = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

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
    .select('id, fitness_goal, weight, age, gender, eating_disorder_risk')
    .eq('id', user.id)
    .maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);

  // Safety override: si hay riesgo declarado en screening, forzar mantenimiento
  // cuando el objetivo sea perder peso o cutting. NUNCA se le dice al usuario
  // "tienes TCA"; el override es transparente para la generacion.
  let eatingDisorderSafeMode = false;
  if (
    profile.eating_disorder_risk === true &&
    ['lose_weight', 'cutting'].includes(`${profile.fitness_goal ?? ''}`.toLowerCase())
  ) {
    profile.fitness_goal = 'maintain';
    eatingDisorderSafeMode = true;
  }

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

  // 5) Catalog: traer hasta ~200 alimentos para no inflar prompt
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

  const system = `Eres NutriCore, planificador nutricional semanal de GymGram. Devuelves JSON estricto sin texto adicional, sin markdown, sin comentarios.

PERFIL DEL USUARIO
- Objetivo: ${profile.fitness_goal ?? 'mantener'}
- Peso: ${profile.weight ?? 'desconocido'} kg | Edad: ${profile.age ?? 'desconocida'} | Género: ${profile.gender ?? 'desconocido'}
- Preferencias culturales/dieta: ${[...preferences].join(', ') || 'ninguna'}
- Tiempo de cocina disponible: ${onb?.cooking_time_preference ?? 'sin preferencia'}
- Modo seguro (TCA): ${eatingDisorderSafeMode ? 'SÍ — evita lenguaje restrictivo, prioriza variedad y suficiencia calórica, NO bajes del target' : 'no'}

TARGETS DIARIOS (promedio semanal debe cumplirlos)
- ${kcalTarget} kcal | P ${pTarget} g | C ${cTarget} g | G ${fTarget} g
- ${meals.length} comidas/día: ${meals.map((m) => MEAL_LABELS[m]).join(', ')}

CATÁLOGO DE ALIMENTOS (usa SOLO estos nombres, literales)
${foodList}

REGLAS NUMERADAS (cúmplelas todas, en orden):

1. ESTRUCTURA: genera 7 días (day 1 a 7), cada uno con las ${meals.length} comidas indicadas. Cada comida lleva 2 a 4 alimentos.

2. VARIEDAD SEMANAL (crítico, no seas perezoso):
   - Ningún alimento puede aparecer más de 3 veces en toda la semana en la misma comida (ej. avena en desayuno máx 3/7 días).
   - Ninguna proteína animal principal (pollo, res, pescado, huevo, atún) puede aparecer en la cena de 2 días consecutivos.
   - Los almuerzos de los 7 días deben usar al menos 4 fuentes de proteína distintas.
   - Las cenas de los 7 días deben usar al menos 5 platos diferentes (≠ combinaciones).
   - Desayuno: SE PERMITE repetir hasta 4/7 días (la gente lo hace), pero rota al menos 2 variantes.

3. BALANCE DIARIO:
   - kcal diarias: cada día dentro de ±12% del target. Promedio semanal dentro de ±5%.
   - Proteína: cada día ≥90% del target. Promedio semanal ≥100%.
   - Carbos y grasas: promedio semanal dentro de ±15%.

4. DISTRIBUCIÓN PROTEÍNA POR COMIDA:
   - Comidas principales (desayuno/almuerzo/cena): 25-40 g de proteína.
   - Snacks/pre/post: 8-20 g.
   - Nunca >50 g en una sola comida.

5. CULTURAL Y COCINA:
   - Si preferencias incluye 'mediterránea': prioriza pescado, aceite de oliva, legumbres, vegetales, granos integrales.
   - Si incluye 'latina': prioriza arroz, legumbres, palta, plátano, pollo, huevo, vegetales locales.
   - Si tiempo de cocina = 'quick' o 'rapido': máx 3 alimentos por comida, evita preparaciones largas.
   - Si tiempo de cocina = 'long' o 'extenso': permite combinaciones más elaboradas (4 alimentos).

6. CATEGORÍAS POR COMIDA (mínimo recomendado):
   - Almuerzo y cena: al menos 1 proteína + 1 carbohidrato + 1 vegetal/fruta.
   - Desayuno: al menos 1 proteína + 1 carbohidrato.
   - Snacks: al menos 1 fuente de proteína o fruta.

7. CÁLCULO DE MACROS (obligatorio, no inventes):
   - Para cada alimento: kcal = round(grams/100 * kcal_per_100g). Igual para protein/carbs/fat.
   - Redondea a enteros.

8. NOMBRES: usa SOLO los nombres exactos del catálogo, copiados literal (mismas tildes y mayúsculas).

9. NO incluyas texto fuera del JSON. NO uses markdown. NO añadas un día 8.

FORMATO JSON EXACTO (respeta llaves, no agregues campos):
{
  "week": [
    {
      "day": 1,
      "meals": [
        {"meal_type":"breakfast","foods":[{"name":"Avena","grams":80,"kcal":300,"protein":10,"carbs":54,"fat":6}]}
      ],
      "daily_totals": {"kcal":2000,"protein":150,"carbs":220,"fat":60}
    }
  ],
  "totals": {
    "daily_avg": {"kcal":2000,"protein":150,"carbs":220,"fat":60},
    "weekly": {"kcal":14000,"protein":1050,"carbs":1540,"fat":420}
  }
}`;

  let plan: WeeklyPlan;
  try {
    plan = await chatJson<WeeklyPlan>({
      model: 'gpt-4o-mini',
      temperature: 0.7,
      maxTokens: 6000,
      messages: [
        { role: 'system', content: system },
        {
          role: 'user',
          content: `Genera mi plan semanal completo (7 días), ${meals.length} comidas por día. Recuerda: variedad real entre días, NO repitas el mismo plato más de lo permitido. Devuelve solo el JSON.`,
        },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // 8) Validaciones post-respuesta

  // 1. Estructura: 7 dias
  if (!plan.week || plan.week.length !== 7) {
    return errorResponse('AI returned invalid week structure', 502);
  }

  // 2. Validar nombres por dia (filtrar alimentos que no esten en catalogo)
  const validNames = new Set(filtered.map((f) => f.name.toLowerCase()));
  const cleanWeek: DayPlan[] = plan.week.map((d) => ({
    day: d.day,
    meals: (d.meals ?? []).map((m) => ({
      meal_type: m.meal_type,
      foods: (m.foods ?? []).filter((f) => validNames.has((f.name ?? '').toLowerCase())),
    })),
  }));

  // 3. Si algun dia quedo con <50% de comidas con alimentos validos, fallar
  const dayValidity = cleanWeek.map((d) =>
    d.meals.filter((m) => m.foods.length > 0).length / Math.max(1, d.meals.length),
  );
  if (dayValidity.some((v) => v < 0.5)) {
    return errorResponse('AI produced too many invalid foods', 502);
  }

  // 4. Recalcular totales server-side (no confiar en el modelo)
  const dailyTotals = cleanWeek.map((d) => {
    let kcal = 0, protein = 0, carbs = 0, fat = 0;
    for (const m of d.meals) {
      for (const f of m.foods) {
        kcal += f.kcal ?? 0;
        protein += f.protein ?? 0;
        carbs += f.carbs ?? 0;
        fat += f.fat ?? 0;
      }
    }
    return {
      kcal: Math.round(kcal),
      protein: Math.round(protein),
      carbs: Math.round(carbs),
      fat: Math.round(fat),
    };
  });

  const cleanWeekWithTotals = cleanWeek.map((d, i) => ({
    ...d,
    daily_totals: dailyTotals[i],
  }));

  const avgKcal = Math.round(dailyTotals.reduce((s, t) => s + t.kcal, 0) / 7);
  const avgProtein = Math.round(dailyTotals.reduce((s, t) => s + t.protein, 0) / 7);
  const avgCarbs = Math.round(dailyTotals.reduce((s, t) => s + t.carbs, 0) / 7);
  const avgFat = Math.round(dailyTotals.reduce((s, t) => s + t.fat, 0) / 7);

  // 5. Validar promedio semanal kcal dentro de ±15% (mas permisivo que la regla del prompt)
  const kcalDelta = Math.abs(avgKcal - kcalTarget) / kcalTarget;
  const lowQuality = kcalDelta > 0.15;

  // 6. Contar repeticiones por meal_type (info opcional, no rechaza)
  const repCount: Record<string, Record<string, number>> = {};
  for (const d of cleanWeekWithTotals) {
    for (const m of d.meals) {
      repCount[m.meal_type] = repCount[m.meal_type] ?? {};
      for (const f of m.foods) {
        const k = f.name.toLowerCase();
        repCount[m.meal_type][k] = (repCount[m.meal_type][k] ?? 0) + 1;
      }
    }
  }
  const lowVariety = Object.values(repCount).some((mealMap) =>
    Object.values(mealMap).some((c) => c > 4),
  );

  // 7. Persistir en nutrition_plans (cache semanal)
  const weekIndex =
    body.week_index ?? Math.floor(Date.now() / (7 * 24 * 60 * 60 * 1000));
  try {
    await supabase.from('nutrition_plans').upsert(
      {
        user_id: user.id,
        week_index: weekIndex,
        plan_json: { week: cleanWeekWithTotals },
        daily_avg: {
          kcal: avgKcal,
          protein: avgProtein,
          carbs: avgCarbs,
          fat: avgFat,
        },
        weekly_totals: {
          kcal: avgKcal * 7,
          protein: avgProtein * 7,
          carbs: avgCarbs * 7,
          fat: avgFat * 7,
        },
        meals_per_day: mealsPerDay,
        catalog_size: filtered.length,
        eating_disorder_safe_mode: eatingDisorderSafeMode,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,week_index' },
    );
  } catch (e) {
    console.error('nutrition_plans upsert failed', e);
    // no fallar la request por esto
  }

  return jsonResponse({
    ok: true,
    week_index: weekIndex,
    plan: { week: cleanWeekWithTotals },
    totals: {
      daily_avg: {
        kcal: avgKcal,
        protein: avgProtein,
        carbs: avgCarbs,
        fat: avgFat,
      },
      weekly: {
        kcal: avgKcal * 7,
        protein: avgProtein * 7,
        carbs: avgCarbs * 7,
        fat: avgFat * 7,
      },
    },
    catalog_size: filtered.length,
    eating_disorder_safe_mode: eatingDisorderSafeMode,
    low_variety: lowVariety,
    low_quality: lowQuality,
  });
});
