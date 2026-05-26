// scan-food — estima alimentos y macros desde una foto del plato con Gemini.
// Solo Plus/Premium. La foto viaja como base64, se analiza y se descarta
// (no se guarda en Storage).
//
// Flujo:
//  1. Auth user
//  2. Valida imagen (presente y bajo el limite de tamano)
//  3. Verifica tier in (plus, premium)
//  4. Tope diario de escaneos por tier + tope mensual global (red de seguridad)
//  5. Gemini Flash vision -> { items: [...] } (valores estimados)
//  6. Cruza con alergias del usuario y marca advertencias
//  7. Devuelve los items para que el usuario edite porciones y confirme
//
// Input:  { image_base64: string, mime_type?: string }
// Output: { ok, items: ScannedItem[], allergy_warnings: string[] }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { visionJson, GeminiError } from '../_shared/gemini.ts';
import { enforceMonthlyCap, UsageCapError } from '../_shared/usage.ts';

// Topes diarios de escaneos por tier (anti-abuso; uso real 3-4 comidas/dia).
const DAILY_CAP: Record<string, number> = { plus: 15, premium: 30 };

// Limite de tamano del base64 (~7MB de imagen comprimida ya es de sobra).
const MAX_BASE64_LEN = 10_000_000;

type ScannedItem = {
  name: string;
  grams: number;
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  confidence: number;
};

const SYSTEM_PROMPT =
  'Eres un nutricionista experto que estima alimentos y macros a partir de una ' +
  'foto de comida. Identifica cada alimento visible, estima su porcion en gramos ' +
  'y calcula calorias y macros PARA ESA PORCION. Usa nombres en espanol. ' +
  'Considera comida latinoamericana. Responde UNICAMENTE JSON valido con la forma: ' +
  '{"items":[{"name":string,"grams":number,"kcal":number,"protein_g":number,' +
  '"carbs_g":number,"fat_g":number,"confidence":number}]}. ' +
  '"confidence" es 0..1 (que tan seguro estas). Si la foto NO contiene comida, ' +
  'devuelve {"items":[]}. No inventes alimentos que no se ven.';

const FOOD_SCHEMA = {
  type: 'object',
  properties: {
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          grams: { type: 'number' },
          kcal: { type: 'number' },
          protein_g: { type: 'number' },
          carbs_g: { type: 'number' },
          fat_g: { type: 'number' },
          confidence: { type: 'number' },
        },
        required: ['name', 'grams', 'kcal', 'protein_g', 'carbs_g', 'fat_g'],
      },
    },
  },
  required: ['items'],
};

function num(v: unknown): number {
  const n = typeof v === 'number' ? v : parseFloat(String(v));
  return Number.isFinite(n) && n > 0 ? n : 0;
}

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { image_base64?: string; mime_type?: string } = {};
  try { body = await req.json(); } catch {}
  const imageBase64 = (body.image_base64 ?? '').trim();
  const mimeType = (body.mime_type ?? 'image/jpeg').trim();

  if (!imageBase64) return errorResponse('image_base64 requerido', 400);
  if (imageBase64.length > MAX_BASE64_LEN) {
    return errorResponse('Imagen demasiado grande', 413);
  }

  const supabase = serviceClient();

  // 1) Tier check
  const { data: profile } = await supabase
    .from('profiles')
    .select('subscription_tier')
    .eq('id', user.id)
    .maybeSingle();
  const tier = (profile?.subscription_tier ?? 'free') as string;
  if (tier !== 'plus' && tier !== 'premium') {
    return errorResponse('El escaner de comida requiere Plus o Premium', 403);
  }

  // 2) Tope diario por tier
  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);
  const { count: usedToday } = await supabase
    .from('ai_usage_events')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .eq('fn', 'scan-food')
    .gte('created_at', dayStart.toISOString());
  const dailyCap = DAILY_CAP[tier] ?? 15;
  if ((usedToday ?? 0) >= dailyCap) {
    return errorResponse(`Limite diario de escaneos alcanzado (${dailyCap}/dia)`, 429);
  }

  // 3) Tope mensual global (registra el evento de uso)
  try {
    await enforceMonthlyCap(supabase, user.id, 'scan-food');
  } catch (e) {
    if (e instanceof UsageCapError) {
      return errorResponse('Limite mensual de IA alcanzado', 429);
    }
    throw e;
  }

  // 4) Gemini vision
  let result: { items?: ScannedItem[] };
  try {
    result = await visionJson<{ items?: ScannedItem[] }>({
      model: 'gemini-2.0-flash',
      system: SYSTEM_PROMPT,
      prompt: 'Analiza esta foto de comida y estima los alimentos y sus macros.',
      imageBase64,
      mimeType,
      maxTokens: 800,
      schema: FOOD_SCHEMA,
    });
  } catch (e) {
    const err = e as GeminiError;
    console.error('gemini error', err);
    return errorResponse(`Error de IA: ${err.message}`, err.status ?? 500);
  }

  // Normaliza y descarta items basura.
  const items: ScannedItem[] = (result.items ?? [])
    .map((it) => ({
      name: String(it.name ?? '').trim().slice(0, 80),
      grams: Math.round(num(it.grams)),
      kcal: Math.round(num(it.kcal)),
      protein_g: Math.round(num(it.protein_g)),
      carbs_g: Math.round(num(it.carbs_g)),
      fat_g: Math.round(num(it.fat_g)),
      confidence: Math.max(0, Math.min(1, num(it.confidence) || 0.5)),
    }))
    .filter((it) => it.name && it.grams > 0);

  // 5) Cruce con alergias (onboarding + restricciones explicitas)
  const { data: onbRows } = await supabase
    .from('user_onboarding_data')
    .select('allergies')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(1);
  const { data: restrictions } = await supabase
    .from('user_dietary_restrictions')
    .select('restriction_type, value')
    .eq('user_id', user.id)
    .eq('restriction_type', 'allergy');

  const allergies = [
    ...(((onbRows?.[0]?.allergies as string[] | null) ?? [])),
    ...((restrictions ?? []).map((r) => r.value as string)),
  ]
    .map((s) => (s ?? '').toLowerCase().trim())
    .filter(Boolean);

  const allergyWarnings: string[] = [];
  for (const it of items) {
    const lower = it.name.toLowerCase();
    for (const a of allergies) {
      if (a && lower.includes(a)) {
        allergyWarnings.push(it.name);
        break;
      }
    }
  }

  return jsonResponse({ ok: true, items, allergy_warnings: allergyWarnings });
});
