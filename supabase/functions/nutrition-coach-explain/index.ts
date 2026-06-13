// nutrition-coach-explain — el "tip de nutricionista" cuantificado.
//
// Body: { food_name?: string, grams?: number, current_meal?: {kcal,protein,...} }
// Modos:
//   1) Si food_name + grams: responde "agregar X g de Y suma A kcal, P g proteina,
//      F g fibra, Na mg sodio" + sugerencia clinica corta.
//   2) Si current_meal: analiza la comida vs guidelines y sugiere 1 mejora concreta.
//
// Output:
//   { ok, summary: string, deltas: {...}, tips: string[] }
//
// 100% deterministico (no LLM) para velocidad y costo cero — usa los macros del
// catalogo + reglas DRI. La IA conversacional ya esta en ai-trainer-chat.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';

type FoodRow = {
  name: string;
  category: string;
  serving_grams: number | null;
  kcal_per_100g: number;
  protein_per_100g: number;
  carbs_per_100g: number;
  fat_per_100g: number;
  fiber_per_100g: number | null;
  sodium_mg_per_100g: number | null;
  sugar_per_100g: number | null;
  sat_fat_per_100g: number | null;
};

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: {
    food_name?: string;
    grams?: number;
    current_meal?: { kcal?: number; protein?: number; carbs?: number; fat?: number };
  } = {};
  try { body = await req.json(); } catch { /* ok */ }

  const supabase = serviceClient();

  // MODO 1: "qué pasa si agrego X g de Y"
  if (body.food_name && body.grams && body.grams > 0) {
    const { data: row } = await supabase
      .from('custom_foods')
      .select('name, category, serving_grams, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, sodium_mg_per_100g, sugar_per_100g, sat_fat_per_100g')
      .ilike('name', body.food_name)
      .limit(1)
      .maybeSingle();
    if (!row) return errorResponse('Food not found', 404);
    const f = row as FoodRow;
    const factor = body.grams / 100;
    const deltas = {
      kcal: Math.round((f.kcal_per_100g ?? 0) * factor),
      protein: +((f.protein_per_100g ?? 0) * factor).toFixed(1),
      carbs: +((f.carbs_per_100g ?? 0) * factor).toFixed(1),
      fat: +((f.fat_per_100g ?? 0) * factor).toFixed(1),
      fiber: +((f.fiber_per_100g ?? 0) * factor).toFixed(1),
      sodium: Math.round((f.sodium_mg_per_100g ?? 0) * factor),
      sugar: +((f.sugar_per_100g ?? 0) * factor).toFixed(1),
      sat_fat: +((f.sat_fat_per_100g ?? 0) * factor).toFixed(1),
    };

    const tips: string[] = [];
    if (deltas.protein >= 15) tips.push(`Buen aporte proteico (${deltas.protein} g). Apoya hipertrofia / saciedad (ISSN 2017).`);
    if (deltas.fiber >= 5) tips.push(`Fibra alta (${deltas.fiber} g) — suma a la meta diaria 14 g/1000 kcal (NIH DRI).`);
    if (deltas.sodium > 500) tips.push(`⚠ Sodio elevado (${deltas.sodium} mg). Limita a 2 porciones de items >500 mg/día.`);
    if (deltas.sat_fat > 5) tips.push(`Grasa saturada moderada-alta (${deltas.sat_fat} g). WHO 2018 recomienda <10% kcal/día.`);
    if (deltas.sugar > 15) tips.push(`Azúcar alto (${deltas.sugar} g). WHO 2015 sugiere azúcares libres <10% kcal.`);
    if (f.category === 'Frutas' && deltas.fiber > 2) tips.push(`Fruta entera vs jugo: conserva fibra y baja IG.`);

    const summary = `${body.grams} g de ${f.name} = ${deltas.kcal} kcal, P${deltas.protein} C${deltas.carbs} G${deltas.fat}, fibra ${deltas.fiber} g, sodio ${deltas.sodium} mg.`;
    return jsonResponse({ ok: true, summary, deltas, tips, food_name: f.name });
  }

  // MODO 2: análisis de una comida ya armada
  if (body.current_meal) {
    const m = body.current_meal;
    const tips: string[] = [];
    if ((m.protein ?? 0) < 20) tips.push(`Proteína baja (${m.protein ?? 0} g). Agrega 30 g de pollo (≈10 g P), 1 huevo (6 g) o 100 g de yogur griego (10 g).`);
    if ((m.kcal ?? 0) > 800) tips.push(`Comida densa (${m.kcal} kcal). Reduce porción de carbo o quita una grasa.`);
    if ((m.kcal ?? 0) < 200) tips.push(`Comida muy ligera (${m.kcal} kcal). Si es plato principal, agrega proteína y/o carbo.`);
    if ((m.fat ?? 0) > 35) tips.push(`Grasa alta (${m.fat} g). Sustituye fritos por horneado o plancha.`);
    return jsonResponse({
      ok: true,
      summary: `Comida: ${m.kcal ?? 0} kcal, P${m.protein ?? 0} C${m.carbs ?? 0} G${m.fat ?? 0}.`,
      deltas: null,
      tips,
    });
  }

  return errorResponse('Provide food_name+grams OR current_meal', 400);
});
