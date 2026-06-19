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
  serving_grams: number | null;
  kcal_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
  fiber_per_100g: number;
  sodium_mg_per_100g: number | null;
  sugar_per_100g: number | null;
  sat_fat_per_100g: number | null;
  country_relevance?: string[] | null;
  popular_in?: string[] | null;
  ai_exclude_from_plan?: boolean | null;
};

type DayPlan = {
  day: number;
  meals: Array<{
    meal_type: string;
    rationale?: string;
    foods: Array<{
      name: string;
      grams: number;
      kcal: number;
      protein: number;
      carbs: number;
      fat: number;
    }>;
  }>;
  daily_totals?: {
    kcal: number; protein: number; carbs: number; fat: number;
    fiber?: number; sodium?: number;
  };
};

type WeeklyPlan = {
  reasoning?: string;
  meta_warnings?: Record<string, string>;
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

  // 1) profile (incluye flags clinicas para C3)
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, fitness_goal, weight, age, gender, eating_disorder_risk, country_code, pregnancy_status, requires_medical_clearance, goal_target_date')
    .eq('id', user.id)
    .maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);

  // Plazo vencido: si goal_target_date ya pasó, el objetivo entra en
  // mantenimiento automáticamente (coherente con NutritionCalculator del
  // cliente, que ya guarda los targets de mantenimiento en nutrition_goals).
  let goalExpired = false;
  if (profile.goal_target_date) {
    const target = new Date(`${profile.goal_target_date}T23:59:59Z`);
    if (!isNaN(target.getTime()) && Date.now() > target.getTime()) {
      profile.fitness_goal = 'maintain';
      goalExpired = true;
    }
  }

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
    .select('daily_kcal, protein_g, carbs_g, fat_g, fiber_g, sodium_max_mg, water_target_ml, meals_per_day')
    .eq('user_id', user.id)
    .maybeSingle();

  // 3) onboarding (food preferences, allergies, disliked, cooking time)
  const { data: onbRows } = await supabase
    .from('user_onboarding_data')
    .select(
      'food_preferences, allergies, disliked_foods, cooking_time_preference, meals_per_day, country_code',
    )
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(1);
  const onb = onbRows?.[0];

  // País del usuario: profile.country_code o el de onboarding, fallback 'CL'.
  const countryCode = (
    `${profile.country_code ?? onb?.country_code ?? 'CL'}`
      .toUpperCase()
      .replace(/[^A-Z]/g, '') || 'CL'
  ).slice(0, 2);

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

  // 5) Catalog: filtrar por país, micros completos y exclusiones.
  //    A1: NO usar .limit(350) ciego (perdia ~58% del catalogo de forma
  //    sesgada alfabetico). Traer TODO el catalogo plan-IA del pais para
  //    despues hacer seleccion estratificada por categoria.
  const { data: foodsRaw } = await supabase
    .from('custom_foods')
    .select(
      'id, name, category, serving_grams, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, sodium_mg_per_100g, sugar_per_100g, sat_fat_per_100g, country_relevance, popular_in, ai_exclude_from_plan',
    )
    .overlaps('country_relevance', [countryCode, 'GLOBAL'])
    .eq('ai_exclude_from_plan', false)
    .gt('kcal_per_100g', 0)
    .limit(2000);

  const foods = (foodsRaw ?? []) as FoodRow[];
  const blacklist = new Set([...allergies, ...intolerances, ...disliked]);
  const filtered = foods.filter((f) => {
    if (f.ai_exclude_from_plan === true) return false;
    const n = f.name.toLowerCase();
    for (const b of blacklist) {
      if (b && n.includes(b)) return false;
    }
    return true;
  });
  if (filtered.length === 0) {
    return errorResponse('No foods matched user constraints', 422);
  }

  // B2: AVOID_LIST — leer food_logs ultimos 14 dias para detectar alimentos
  // que el usuario rechazo o no registro (saltado). Heuristica: si un alimento
  // aparece en plan pero NUNCA en logs, probablemente lo rechazo.
  // Implementacion simple: lista de los 10 items mas LOGGED (gustan) +
  // items con 0 logs que estan en planes recientes (potencialmente rechazados).
  let avoidList: string[] = [];
  let favoriteList: string[] = [];
  try {
    const since = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
    const { data: recentLogs } = await supabase
      .from('food_logs')
      .select('food_name')
      .eq('user_id', user.id)
      .gte('created_at', since)
      .limit(500);
    if (recentLogs && recentLogs.length > 0) {
      const tally: Record<string, number> = {};
      for (const l of recentLogs) {
        const n = (l.food_name as string | null)?.toLowerCase().trim() ?? '';
        if (!n) continue;
        tally[n] = (tally[n] ?? 0) + 1;
      }
      const sorted = Object.entries(tally).sort((a, b) => b[1] - a[1]);
      favoriteList = sorted.slice(0, 10).map(([k]) => k);
    }
  } catch (e) {
    console.error('AVOID_LIST food_logs read failed', e);
  }

  // 6) Targets
  const kcalTarget = goals?.daily_kcal ?? 2000;
  const pTarget = goals?.protein_g ?? 120;
  const cTarget = goals?.carbs_g ?? 220;
  const fTarget = goals?.fat_g ?? 60;
  // Fibra (NIH DRI 14 g / 1000 kcal) y sodio máximo (NIH DRI 2300 mg).
  const fiberTarget = Math.round((14 * kcalTarget) / 1000);
  const sodiumMax = (goals as { sodium_max_mg?: number } | null)?.sodium_max_mg ?? 2300;
  const mealsPerDay =
    goals?.meals_per_day ?? (onb?.meals_per_day as number | undefined) ?? 4;
  const meals = mealsByCount(mealsPerDay);

  // 7) Prompt — SELECCION ESTRATIFICADA POR CATEGORIA (A1)
  //
  // Cuotas por categoria con balance nutricional (no alfabetico). Para cada
  // categoria, cuota dura [CASERO] primero (A3 / fix P5) y resto despues.
  // Total objetivo ~380 items balanceados, no 350 ciegos.
  const isHomePopular = (f: FoodRow) =>
    Array.isArray(f.popular_in) &&
    f.popular_in.some((c) => c.toUpperCase() === countryCode);

  const byCategory: Record<string, FoodRow[]> = {};
  for (const f of filtered) {
    const cat = f.category || 'Otros';
    byCategory[cat] = byCategory[cat] ?? [];
    byCategory[cat].push(f);
  }

  // Cuotas: { totalQuota, caseroQuota } — Preparaciones tiene más espacio
  // y más cuota CASERO porque es el corazón de la dieta casera.
  const CATEGORY_QUOTAS: Record<string, { total: number; casero: number }> = {
    'Preparaciones': { total: 90, casero: 50 },
    'Proteinas':     { total: 60, casero: 30 },
    'Cereales':      { total: 40, casero: 20 },
    'Verduras':      { total: 40, casero: 15 },
    'Frutas':        { total: 30, casero: 12 },
    'Lacteos':       { total: 35, casero: 15 },
    'Legumbres':     { total: 25, casero: 10 },
    'Grasas':        { total: 20, casero: 5 },
    'Bebidas':       { total: 25, casero: 10 },
    'Snacks':        { total: 20, casero: 5 },
  };

  function pickStratified(cat: string): FoodRow[] {
    const items = (byCategory[cat] ?? []).slice();
    if (items.length === 0) return [];
    const quota = CATEGORY_QUOTAS[cat] ?? { total: 15, casero: 5 };
    const caseros = items.filter(isHomePopular).slice(0, quota.casero);
    const seen = new Set(caseros.map((f) => f.id));
    const rest = items.filter((f) => !seen.has(f.id));
    const remaining = Math.max(0, quota.total - caseros.length);
    return [...caseros, ...rest.slice(0, remaining)];
  }

  const categoriesOrdered = [
    'Preparaciones','Proteinas','Cereales','Legumbres','Verduras',
    'Frutas','Lacteos','Grasas','Bebidas','Snacks',
  ];

  // A2: foodList con TODOS los micros (fibra, sodio) + porcion sugerida.
  // El modelo ahora puede respetar reglas DRI fibra/sodio reales en vez de
  // adivinar. Formato compacto para no inflar tokens.
  const foodList = categoriesOrdered
    .map((cat) => {
      const picked = pickStratified(cat);
      if (picked.length === 0) return '';
      const lines = picked.map((f) => {
        const tag = isHomePopular(f) ? ' [CASERO]' : '';
        const fiber = f.fiber_per_100g ?? 0;
        const sodium = f.sodium_mg_per_100g ?? 0;
        const serving = f.serving_grams ?? 100;
        return `- ${f.name}${tag} | ${f.kcal_per_100g}kcal P${f.protein_per_100g} C${f.carbs_per_100g} G${f.fat_per_100g} F${fiber} Na${sodium} | porcion ${serving}g`;
      }).join('\n');
      return `=== ${cat.toUpperCase()} ===\n${lines}`;
    })
    .filter(Boolean)
    .join('\n\n');

  const prefList = [...preferences];
  const isHomeStyle =
    prefList.includes('omnivore') ||
    prefList.includes('casero') ||
    prefList.length === 0 ||
    prefList.includes('no_preference');
  const isVegan = prefList.includes('vegan') || prefList.includes('vegana');
  const isVegetarian =
    isVegan ||
    prefList.includes('vegetarian') ||
    prefList.includes('vegetariana');
  // Peso real para reglas ACSM post-entreno (g/kg). Si no hay peso, usar 70 kg
  // como aproximación; el validador server-side acota cualquier exceso.
  const weightKg = Number(profile.weight ?? 70) || 70;

  // C3: flags clinicas para sub-prompts condicionales.
  const pregnancyStatus = `${profile.pregnancy_status ?? ''}`.toLowerCase();
  const isPregnant = ['pregnant','embarazada','t1','t2','t3'].some((k) => pregnancyStatus.includes(k));
  const isPregnantT2T3 = pregnancyStatus.includes('t2') || pregnancyStatus.includes('t3') || pregnancyStatus.includes('third') || pregnancyStatus.includes('second');
  const needsMedicalClearance = profile.requires_medical_clearance === true;
  // sodium_max_mg<=1500 indica perfil HTA en goals. Diabetes hoy no se detecta
  // automaticamente — placeholder para futuro health_conditions.
  const isHypertensionFlag = sodiumMax <= 1500;

  const clinicalBlock = (() => {
    const parts: string[] = [];
    if (isPregnant) {
      const extraKcal = isPregnantT2T3 ? 450 : 340;
      parts.push(`- EMBARAZO detectado (${pregnancyStatus || 'sin trimestre'}). ACOG 2020 + DRI NIH:
   - kcal: ${kcalTarget} ya incluye ajuste si esta seteado; si dudas, +${extraKcal} kcal sobre mantenimiento (T${isPregnantT2T3 ? '2/3' : '1'}).
   - Hierro: prioriza carne roja magra, legumbres con vit C (kiwi/naranja/tomate). Meta 27 mg/dia.
   - Folato: incluye espinaca, brocoli, legumbres, palta. Meta 600 ug/dia. Senalalo en notes si la comida aporta.
   - Calcio: 1000 mg/dia (3 lacteos al dia).
   - EVITAR: pescado alto en mercurio (atun rojo, pez espada), embutidos crudos, quesos no pasteurizados, vino/cerveza/alcohol cero.
   - Sodio: 1500-2300 mg.`);
    }
    if (isHypertensionFlag) {
      parts.push(`- HIPERTENSION (sodium_max=${sodiumMax} mg). Patron DASH 2021:
   - Sodio diario estricto <= ${sodiumMax} mg. Sin embutidos, salame, jamon, anchoas, encurtidos.
   - Potasio alto: platano, palta, papa, espinaca, legumbres, naranja. Meta 4700 mg/dia (no calcules, prioriza estos items).
   - Calcio: 3 lacteos descremados/dia. Magnesio: granos integrales, almendras.
   - EVITAR snacks salados, mayonesa industrial, salsas de soja, caldos en cubo.`);
    }
    if (needsMedicalClearance && !isPregnant && !isHypertensionFlag) {
      parts.push(`- requires_medical_clearance=true. Modo CLINICO conservador:
   - Macros centrados (no extremos), variedad alta, evitar restricciones agresivas.
   - Incluye SIEMPRE el campo "rationale" con justificacion clinica del plato (mas critico que normalmente).
   - Marca "vegan_warning" o equivalente si aplica suplementacion obligatoria.`);
    }
    return parts.length > 0 ? parts.join('\n') : '';
  })();

  // B2: AVOID/FAVORITE list desde food_logs
  const avoidFavoriteBlock = (avoidList.length === 0 && favoriteList.length === 0)
    ? ''
    : `\n\nMEMORIA NUTRICIONAL DEL USUARIO (food_logs ultimos 14 dias):
${favoriteList.length > 0 ? `- Le gustan / ya consume seguido: ${favoriteList.join(', ')}. Usa estos cuando puedas, no fuerces si no calzan.` : ''}
${avoidList.length > 0 ? `- AVOID_LIST (rechazos detectados): ${avoidList.join(', ')}. No los incluyas en esta semana.` : ''}`;

  const system = `Eres NutriCore, planificador nutricional semanal de GymGram. Pensas como nutricionista clinico con respaldo evidencia (ACSM Position Stand 2017 - Thomas/Erdman/Burke, ISSN 2017 - Jager, NIH DRI, WHO 2015 azucares, WHO 2018 grasa saturada, AND 2016 vegetariana, ACOG 2020 embarazo, DASH 2021 HTA). Devuelves JSON estricto sin texto adicional, sin markdown, sin comentarios.

PERFIL DEL USUARIO
- Objetivo: ${profile.fitness_goal ?? 'mantener'}
- Peso: ${profile.weight ?? 'desconocido'} kg | Edad: ${profile.age ?? 'desconocida'} | Género: ${profile.gender ?? 'desconocido'}
- País: ${countryCode}
- Tipo de dieta / preferencias: ${prefList.join(', ') || 'casero (omnívoro)'}
- Tiempo de cocina disponible: ${onb?.cooking_time_preference ?? 'sin preferencia'}
- Modo seguro (TCA): ${eatingDisorderSafeMode ? 'SÍ — evita lenguaje restrictivo, prioriza variedad y suficiencia calórica, NO bajes del target' : 'no'}
${clinicalBlock ? '\nMODO CLINICO ACTIVO:\n' + clinicalBlock : ''}${avoidFavoriteBlock}

TARGETS DIARIOS (promedio semanal debe cumplirlos)
- ${kcalTarget} kcal | P ${pTarget} g | C ${cTarget} g | G ${fTarget} g
- Fibra ≥ ${fiberTarget} g/día (NIH DRI 14 g / 1000 kcal)
- Sodio ≤ ${sodiumMax} mg/día (NIH DRI / DASH si HTA)
- Azúcares libres ≤ ${Math.round((kcalTarget * 0.10) / 4)} g/día (WHO 2015, 10% kcal)
- Grasa saturada ≤ ${Math.round((kcalTarget * 0.10) / 9)} g/día (WHO 2018, 10% kcal)
- ${meals.length} comidas/día: ${meals.map((m) => MEAL_LABELS[m]).join(', ')}

CATÁLOGO DE ALIMENTOS (usa SOLO estos nombres, literales). Formato: nombre [CASERO si aplica] | kcal/100g P/100g C/100g G/100g F(fibra)/100g Na(sodio mg)/100g | porcion sugerida en g. Los marcados [CASERO] son cotidianos en una casa promedio del país ${countryCode}.
${foodList}

REGLAS NUMERADAS (cúmplelas todas, en orden):

1. ESTRUCTURA: genera 7 días (day 1 a 7), cada uno con las ${meals.length} comidas indicadas. Cada comida lleva 2 a 4 alimentos.

2. COHERENCIA DE PLATOS (regla crítica — esto es lo que más rompe la calidad):
   a. Si eliges un ítem de la categoría "Preparaciones" en almuerzo o cena, ese ítem ES el plato principal. Acompáñalo SOLO con: una ensalada/verdura (categoría Verduras) o pan (Cereales) o bebida. NUNCA con una fruta suelta.
   b. Una fruta nunca puede ser "el plato" de almuerzo o cena. Las frutas (categoría Frutas) SOLO van en desayuno o snack.
   c. Cenas y almuerzos deben tener una fuente proteica clara (carne, pollo, pescado, huevo, legumbre, tofu, queso o una Preparación que ya la incluya). Tofu, atún o yogur NUNCA se combinan solos con una fruta como almuerzo o cena.
   d. Combinaciones prohibidas explícitamente: { tofu + fruta }, { atún + fruta sola }, { yogur + fruta como almuerzo/cena }, { fruta como único acompañamiento de un plato principal }, { taco/milanesa/humita/empanada + fruta }, { ensalada de fruta como cena }.
   e. Si el almuerzo o cena es un sándwich/hamburguesa/wrap, NO añadas otro ítem fuerte de Preparaciones; añade máximo una bebida y/o snack ligero.

3. DIETA CASERA (${isHomeStyle ? 'ACTIVA' : 'inactiva'}):
   ${isHomeStyle
     ? `- El usuario eligió dieta "Casera". Esto significa: platos sencillos, populares, con ingredientes que siempre hay en una casa del país ${countryCode}. NADA exótico, NADA raro.
   - En al menos 5 de los 7 ALMUERZOS y al menos 4 de las 7 CENAS, el plato principal debe estar marcado [CASERO].
   - Acompañamientos también deben preferir items [CASERO] (pan local, ensalada simple del país, arroz/fideos, papa, palta, tomate, lechuga).
   - PROHIBIDO recomendar comida rápida de cadenas (no aparecerá en el catálogo, pero si la inventas se descarta).
   - Evita ingredientes raros o gourmet (tofu, edamame, quinoa exótica, kale, etc.) salvo que estén marcados [CASERO] para el país.`
     : `- Respeta la dieta declarada (${prefList.join(', ') || 'sin preferencia'}). Si es vegetariana/vegana evita carnes/pescados/huevo según corresponda.`}
   - Si preferencias incluye 'mediterránea': prioriza pescado, aceite de oliva, legumbres y vegetales.
   - Si tiempo de cocina = 'no_time' o 'quick_lt_15m': prioriza Preparaciones ya armadas (1 ítem fuerte + ensalada + bebida).

4. VARIEDAD SEMANAL (no seas perezoso):
   - Ningún alimento puede aparecer más de 3 veces en toda la semana en la misma comida.
   - Ninguna proteína animal principal (pollo, res, pescado, huevo, atún) puede aparecer en la cena de 2 días consecutivos.
   - Los almuerzos de los 7 días deben usar al menos 4 platos principales distintos.
   - Las cenas de los 7 días deben usar al menos 5 platos diferentes.
   - Desayuno: permite repetir hasta 4/7 días, pero rota al menos 2 variantes.

5. BALANCE DIARIO:
   - kcal diarias: cada día dentro de ±12% del target. Promedio semanal dentro de ±5%.
   - Proteína: cada día ≥90% del target. Promedio semanal ≥100%.
   - Carbos y grasas: promedio semanal dentro de ±15%.

6. DISTRIBUCIÓN PROTEÍNA POR COMIDA:
   - Comidas principales (desayuno/almuerzo/cena): 25-40 g de proteína.
   - Snacks/pre/post: 8-20 g.
   - Nunca >50 g en una sola comida.

7. TIMING NUTRICIONAL (ACSM Position Stand 2017 — Thomas, Erdman, Burke):
   - Si la comida es "pre_workout": ≥ ${Math.round(weightKg * 1.0)} g de carbohidratos (≈1 g/kg), proteína baja-moderada 10-20 g, GRASA total < 10 g (vacía gástrico rápido). Evita fibra alta y comidas pesadas.
   - Si la comida es "post_workout": carbohidratos 1.0-1.2 g/kg (≈ ${Math.round(weightKg * 1.0)}-${Math.round(weightKg * 1.2)} g) Y proteína ≥0.3 g/kg (≈ ${Math.round(weightKg * 0.3)} g). Esta es la "ventana anabólica" — prioriza absorción rápida (whey, leche, yogur, huevo, pan).
   - Si NO hay pre/post entreno explícitos en la lista de comidas, ignora esta regla.

8. NUTRIENTES PROTECTORES (usa los valores F y Na del catálogo para calcular):
   - Fibra promedio semanal ≥ ${fiberTarget} g/día. Items con F alta = legumbres, avena, fruta entera, verduras, integrales.
   - Sodio promedio diario ≤ ${sodiumMax} mg. Items con Na alta (Na>500 mg/100g) NO uses más de 2 por día.
   - Azúcares libres (dulces/snacks) ≤ 10% kcal/día. Usa fruta entera mejor que jugos.
   - Grasa saturada ≤ 10% kcal/día. Limita mantequilla, embutidos, helados.
   ${isVegan ? '- DIETA VEGANA: marca "vegan_warning":"B12 suplementación obligatoria + cuida hierro/zinc/omega-3 (AND 2016 Melina/Craig/Levin)" en meta_warnings.' : ''}
   ${isVegetarian && !isVegan ? '- Vegetariana: prioriza huevo + lácteos como proteína; combina legumbres + cereales (lentejas+arroz) para aminoácidos completos.' : ''}

9. CÁLCULO DE MACROS (obligatorio, no inventes):
   - Para cada alimento: kcal = round(grams/100 * kcal_per_100g). Igual para protein/carbs/fat.
   - Redondea a enteros.
   - Las "porciones sugeridas" del catálogo son orientativas; ajusta grams para cumplir targets pero RESPETA porciones razonables (ej. cazuela 300-400g, ensalada 100-200g, fruta entera 100-180g, NO porciones de 50g de un plato fuerte).

10. NOMBRES: usa SOLO los nombres exactos del catálogo, copiados literal (mismas tildes y mayúsculas).

11. RAZONAMIENTO PREVIO (B1/B4): Antes del "week", incluye un campo "reasoning" con tu planificación:
   - distribución kcal aproximada por meal_type
   - estrategia para llegar a proteína y fibra
   - patrón cultural elegido (qué [CASERO] vas a usar varias veces)
   - 2-3 alternativas que descartaste y por qué
   Y en CADA comida, incluye un "rationale" de 1 línea con la justificación clínica/cultural (ej. "Cazuela post-pierna: 0.4 g/kg proteína + carbo reposición + casero CL").

12. NO incluyas texto fuera del JSON. NO uses markdown. NO añadas un día 8.

FORMATO JSON EXACTO:
{
  "reasoning": "Distribución kcal: desayuno 25%, almuerzo 35%, cena 30%, snacks 10%. Proteína concentrada en almuerzo/cena con pollo/legumbres rotando. Casero CL: cazuela 3x, milanesa 2x, plateada 1x, reineta 1x. Descarté: tofu (no es casero CL), sushi (cocina compleja para 'no_time'), fast food (excluido).",
  "meta_warnings": {"vegan_warning": "..."},
  "week": [
    {
      "day": 1,
      "meals": [
        {
          "meal_type":"breakfast",
          "rationale":"Desayuno proteína moderada + fibra alta para saciedad",
          "foods":[
            {"name":"Avena cocida","grams":200,"kcal":142,"protein":5,"carbs":24,"fat":3}
          ]
        }
      ],
      "daily_totals": {"kcal":2000,"protein":150,"carbs":220,"fat":60,"fiber":28,"sodium":1900}
    }
  ],
  "totals": {
    "daily_avg": {"kcal":2000,"protein":150,"carbs":220,"fat":60,"fiber":28,"sodium":1900},
    "weekly": {"kcal":14000,"protein":1050,"carbs":1540,"fat":420}
  }
}`;

  let plan: WeeklyPlan;
  try {
    plan = await chatJson<WeeklyPlan>({
      model: 'gpt-4o-mini',
      temperature: 0.7,
      // CoT (reasoning) + rationale por comida requieren mas espacio.
      maxTokens: 8000,
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
      rationale: m.rationale, // B4: preservar rationale del modelo
      foods: (m.foods ?? []).filter((f) => validNames.has((f.name ?? '').toLowerCase())),
    })),
  }));

  // 2b. Detectar comidas principales (lunch/dinner) con combos incoherentes
  //     (fruta sola como plato, o sin proteína/preparación). Si una cena/almuerzo
  //     SOLO trae frutas, se descarta su contenido para que la UI muestre vacío
  //     en vez de "Tofu firme + Melón" o "Taco de pollo + Durazno".
  const catByName = new Map<string, string>();
  for (const f of filtered) catByName.set(f.name.toLowerCase(), f.category);
  const isMainMeal = (mt: string) => mt === 'lunch' || mt === 'dinner';
  let incoherentMains = 0;
  for (const d of cleanWeek) {
    for (const m of d.meals) {
      if (!isMainMeal(m.meal_type) || m.foods.length === 0) continue;
      const cats = m.foods.map((f) => catByName.get(f.name.toLowerCase()) ?? '');
      const hasMain =
        cats.includes('Preparaciones') ||
        cats.includes('Proteinas') ||
        cats.includes('Legumbres');
      const onlyFruitsAndDrinks = cats.every(
        (c) => c === 'Frutas' || c === 'Bebidas',
      );
      if (!hasMain || onlyFruitsAndDrinks) {
        incoherentMains++;
        m.foods = m.foods.filter((f) => {
          const c = catByName.get(f.name.toLowerCase());
          return c !== 'Frutas';
        });
      }
    }
  }

  // 3. Si algun dia quedo con <50% de comidas con alimentos validos, fallar
  const dayValidity = cleanWeek.map((d) =>
    d.meals.filter((m) => m.foods.length > 0).length / Math.max(1, d.meals.length),
  );
  if (dayValidity.some((v) => v < 0.5)) {
    return errorResponse('AI produced too many invalid foods', 502);
  }

  // 4. Recalcular totales server-side INCLUYENDO fibra y sodio reales del
  //    catalogo (A3). No confiamos en el modelo: usamos los macros nativos
  //    del item × proporcion de grams del plan.
  const foodByName = new Map<string, FoodRow>();
  for (const f of filtered) foodByName.set(f.name.toLowerCase(), f);

  const dailyTotals = cleanWeek.map((d) => {
    let kcal = 0, protein = 0, carbs = 0, fat = 0, fiber = 0, sodium = 0;
    let caseroMainCount = 0;
    let mainsTotal = 0;
    for (const m of d.meals) {
      const isMain = m.meal_type === 'lunch' || m.meal_type === 'dinner';
      if (isMain && m.foods.length > 0) mainsTotal++;
      for (const f of m.foods) {
        kcal += f.kcal ?? 0;
        protein += f.protein ?? 0;
        carbs += f.carbs ?? 0;
        fat += f.fat ?? 0;
        const meta = foodByName.get((f.name ?? '').toLowerCase());
        if (meta) {
          const factor = (f.grams ?? 0) / 100;
          fiber += (meta.fiber_per_100g ?? 0) * factor;
          sodium += (meta.sodium_mg_per_100g ?? 0) * factor;
          // [CASERO] en plato principal? cuenta para metricas adherencia
          if (isMain && Array.isArray(meta.popular_in) &&
              meta.popular_in.some((c) => c.toUpperCase() === countryCode) &&
              (meta.category === 'Preparaciones' || meta.category === 'Proteinas')) {
            caseroMainCount++;
          }
        }
      }
    }
    return {
      kcal: Math.round(kcal),
      protein: Math.round(protein),
      carbs: Math.round(carbs),
      fat: Math.round(fat),
      fiber: Math.round(fiber),
      sodium: Math.round(sodium),
      _caseroMainCount: caseroMainCount,
      _mainsTotal: mainsTotal,
    };
  });

  const cleanWeekWithTotals = cleanWeek.map((d, i) => ({
    ...d,
    daily_totals: {
      kcal: dailyTotals[i].kcal,
      protein: dailyTotals[i].protein,
      carbs: dailyTotals[i].carbs,
      fat: dailyTotals[i].fat,
      fiber: dailyTotals[i].fiber,
      sodium: dailyTotals[i].sodium,
    },
  }));

  const avgKcal = Math.round(dailyTotals.reduce((s, t) => s + t.kcal, 0) / 7);
  const avgProtein = Math.round(dailyTotals.reduce((s, t) => s + t.protein, 0) / 7);
  const avgCarbs = Math.round(dailyTotals.reduce((s, t) => s + t.carbs, 0) / 7);
  const avgFat = Math.round(dailyTotals.reduce((s, t) => s + t.fat, 0) / 7);
  const avgFiber = Math.round(dailyTotals.reduce((s, t) => s + t.fiber, 0) / 7);
  const avgSodium = Math.round(dailyTotals.reduce((s, t) => s + t.sodium, 0) / 7);
  const totalCaseroMains = dailyTotals.reduce((s, t) => s + t._caseroMainCount, 0);
  const totalMains = dailyTotals.reduce((s, t) => s + t._mainsTotal, 0);
  const caseroAdherence = totalMains > 0 ? totalCaseroMains / totalMains : 0;

  // 5. Quality flags (A3): convertir reglas decorativas en reglas auditadas
  const kcalDelta = Math.abs(avgKcal - kcalTarget) / kcalTarget;
  const fiberRatio = fiberTarget > 0 ? avgFiber / fiberTarget : 1;
  const sodiumRatio = sodiumMax > 0 ? avgSodium / sodiumMax : 0;
  const lowQuality =
    kcalDelta > 0.15 ||
    fiberRatio < 0.80 ||
    sodiumRatio > 1.10 ||
    (isHomeStyle && caseroAdherence < 0.50);
  const qualityFlags = {
    kcal_delta_pct: Math.round(kcalDelta * 100),
    fiber_ratio_pct: Math.round(fiberRatio * 100),
    sodium_ratio_pct: Math.round(sodiumRatio * 100),
    casero_adherence_pct: Math.round(caseroAdherence * 100),
  };

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
  const dailyAvg = {
    kcal: avgKcal, protein: avgProtein, carbs: avgCarbs, fat: avgFat,
    fiber: avgFiber, sodium: avgSodium,
  };
  try {
    await supabase.from('nutrition_plans').upsert(
      {
        user_id: user.id,
        week_index: weekIndex,
        plan_json: {
          reasoning: plan.reasoning ?? null,
          meta_warnings: plan.meta_warnings ?? null,
          quality_flags: qualityFlags,
          week: cleanWeekWithTotals,
        },
        daily_avg: dailyAvg,
        weekly_totals: {
          kcal: avgKcal * 7, protein: avgProtein * 7,
          carbs: avgCarbs * 7, fat: avgFat * 7,
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
  }

  return jsonResponse({
    ok: true,
    week_index: weekIndex,
    plan: {
      reasoning: plan.reasoning ?? null,
      meta_warnings: plan.meta_warnings ?? null,
      week: cleanWeekWithTotals,
    },
    totals: {
      daily_avg: dailyAvg,
      weekly: {
        kcal: avgKcal * 7, protein: avgProtein * 7,
        carbs: avgCarbs * 7, fat: avgFat * 7,
      },
    },
    quality_flags: qualityFlags,
    catalog_size: filtered.length,
    eating_disorder_safe_mode: eatingDisorderSafeMode,
    goal_expired: goalExpired,
    low_variety: lowVariety,
    low_quality: lowQuality || incoherentMains > 2,
    incoherent_mains: incoherentMains,
    country_code: countryCode,
    fiber_target: fiberTarget,
    sodium_max_mg: sodiumMax,
    vegan_warning_required: isVegan,
    clinical_mode_active: clinicalBlock.length > 0,
    favorites_used: favoriteList,
    avoid_used: avoidList,
  });
});
