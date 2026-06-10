// scan-food — estima alimentos y macros desde una foto del plato con Gemini.
// Solo Plus/Premium. La foto viaja como base64, se analiza y se descarta.
//
// Flujo:
//  1. Auth user
//  2. Valida imagen
//  3. Paralelo: tier + daily/monthly caps + alergias + suspended_until
//  4. Gemini vision con safety estricto + schema con content_type
//  5. Moderación:
//      - NSFW (bloqueado por Gemini O content_type='nsfw') -> strike + 403
//      - 'other' (no comida pero no NSFW) -> 200 vacío, SÍ cobra el scan
//      - 'food' -> flujo normal
//  6. Cruce con alergias y devuelve items + warnings

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { visionJson, GeminiError, GeminiSafetyBlocked } from '../_shared/gemini.ts';
import { GLOBAL_MONTHLY_CAP } from '../_shared/usage.ts';

const DAILY_CAP: Record<string, number> = { plus: 15, premium: 30 };
const MAX_BASE64_LEN = 10_000_000;

type ContentType = 'food' | 'nsfw' | 'other';

type ScannedItem = {
  name: string;
  grams: number;
  kcal: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  confidence: number;
};

type ScanPayload = {
  content_type?: ContentType;
  items?: ScannedItem[];
};

const SYSTEM_PROMPT =
  'Eres un sistema que clasifica fotos y, solo si son comida, estima macros. ' +
  'Primero clasifica el "content_type": ' +
  '"food" (la foto muestra comida, plato, ingredientes o bebida nutricional), ' +
  '"nsfw" (la foto contiene desnudez, contenido sexual, violento o explicito), ' +
  '"other" (cualquier otra cosa: persona vestida, mascota, paisaje, captura de ' +
  'pantalla, texto, etc). Si content_type es "food", lista cada alimento ' +
  'visible y estima su porcion en gramos usando referencias visuales (plato ' +
  'estandar 25cm, cubiertos, mano, vaso) y calcula calorias y macros PARA ESA ' +
  'PORCION. Usa nombres en espanol (comida latinoamericana). Agrupa porciones ' +
  'del mismo alimento. Maximo 8 items. "confidence" es 0..1. Si content_type ' +
  'NO es "food", devuelve items vacio []. NO inventes alimentos que no se ven.';

const FOOD_SCHEMA = {
  type: 'object',
  properties: {
    content_type: { type: 'string', enum: ['food', 'nsfw', 'other'] },
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
  required: ['content_type', 'items'],
};

const ALLERGY_SYNONYMS: Record<string, string[]> = {
  'lacteos': ['leche', 'queso', 'yogur', 'yogurt', 'mantequilla', 'crema', 'ricotta', 'parmesano', 'mozzarella', 'cheddar', 'manteca'],
  'lacteo': ['leche', 'queso', 'yogur', 'yogurt', 'mantequilla', 'crema', 'ricotta', 'parmesano', 'mozzarella'],
  'dairy': ['leche', 'queso', 'yogur', 'mantequilla', 'crema'],
  'leche': ['lacteo', 'queso', 'yogur', 'crema'],
  'gluten': ['trigo', 'pan', 'pasta', 'harina', 'cebada', 'centeno', 'avena', 'galleta', 'cuscus', 'couscous', 'fideo', 'tallarin'],
  'trigo': ['pan', 'pasta', 'harina', 'galleta', 'fideo'],
  'frutos secos': ['almendra', 'nuez', 'maní', 'mani', 'cacahuete', 'avellana', 'pistacho', 'castana', 'castaña', 'anacardo'],
  'nueces': ['almendra', 'nuez', 'maní', 'mani', 'cacahuete', 'avellana', 'pistacho'],
  'mani': ['cacahuete'],
  'maní': ['cacahuete'],
  'mariscos': ['camaron', 'camarón', 'langosta', 'cangrejo', 'ostra', 'mejillon', 'mejillón', 'almeja', 'pulpo', 'calamar', 'jaiba'],
  'marisco': ['camaron', 'camarón', 'langosta', 'cangrejo', 'ostra', 'almeja'],
  'shellfish': ['camaron', 'langosta', 'cangrejo', 'ostra'],
  'huevo': ['tortilla', 'omelette', 'mayonesa', 'huevos'],
  'huevos': ['tortilla', 'omelette', 'mayonesa'],
  'soja': ['tofu', 'edamame', 'salsa de soya', 'soya'],
  'soya': ['tofu', 'edamame', 'salsa de soya', 'soja'],
  'pescado': ['atun', 'atún', 'salmon', 'salmón', 'merluza', 'bacalao', 'reineta', 'congrio'],
  'fish': ['atun', 'salmon', 'merluza', 'bacalao'],
};

function num(v: unknown): number {
  const n = typeof v === 'number' ? v : parseFloat(String(v));
  return Number.isFinite(n) && n > 0 ? n : 0;
}

function detectAllergyHit(foodName: string, allergies: string[]): boolean {
  const lower = foodName.toLowerCase();
  for (const a of allergies) {
    if (!a) continue;
    if (lower.includes(a)) return true;
    const syns = ALLERGY_SYNONYMS[a];
    if (syns) {
      for (const s of syns) {
        if (lower.includes(s)) return true;
      }
    }
  }
  return false;
}

// deno-lint-ignore no-explicit-any
async function recordNsfwViolation(supabase: any, userId: string): Promise<{
  strikes30d: number;
  suspendedUntil: string | null;
}> {
  const { data, error } = await supabase.rpc('register_nsfw_violation', {
    p_user_id: userId,
  });
  if (error) {
    console.error('register_nsfw_violation error', error);
    return { strikes30d: 1, suspendedUntil: null };
  }
  const row = Array.isArray(data) ? data[0] : data;
  return {
    strikes30d: Number(row?.strikes_30d ?? 1),
    suspendedUntil: row?.suspended_until ?? null,
  };
}

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { image_base64?: string; mime_type?: string } = {};
  try { body = await req.json(); } catch { /* ignore */ }
  const imageBase64 = (body.image_base64 ?? '').trim();
  const mimeType = (body.mime_type ?? 'image/jpeg').trim();

  if (!imageBase64) return errorResponse('image_base64 requerido', 400);
  if (imageBase64.length > MAX_BASE64_LEN) {
    return errorResponse('Imagen demasiado grande', 413);
  }

  const supabase = serviceClient();

  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);
  const monthStart = new Date();
  monthStart.setUTCDate(1);
  monthStart.setUTCHours(0, 0, 0, 0);

  const [
    profileRes,
    dailyRes,
    monthlyRes,
    onbRes,
    restrictionsRes,
  ] = await Promise.all([
    supabase
      .from('profiles')
      .select('subscription_tier, suspended_until')
      .eq('id', user.id)
      .maybeSingle(),
    supabase
      .from('ai_usage_events')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('fn', 'scan-food')
      .gte('created_at', dayStart.toISOString()),
    supabase
      .from('ai_usage_events')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('created_at', monthStart.toISOString()),
    supabase
      .from('user_onboarding_data')
      .select('allergies')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1),
    supabase
      .from('user_dietary_restrictions')
      .select('value')
      .eq('user_id', user.id)
      .eq('restriction_type', 'allergy'),
  ]);

  const profile = profileRes.data ?? {};
  const tier = (profile.subscription_tier ?? 'free') as string;

  // Suspensión vigente → 403 con código específico.
  const suspendedUntil = profile.suspended_until as string | null;
  if (suspendedUntil && new Date(suspendedUntil) > new Date()) {
    return jsonResponse({
      ok: false,
      code: 'suspended',
      error: 'Tu cuenta está suspendida temporalmente por subir contenido que viola las reglas.',
      suspended_until: suspendedUntil,
    }, 403);
  }

  if (tier !== 'plus' && tier !== 'premium') {
    return errorResponse('El escaner de comida requiere Plus o Premium', 403);
  }

  const dailyCap = DAILY_CAP[tier] ?? 15;
  if ((dailyRes.count ?? 0) >= dailyCap) {
    return errorResponse(`Limite diario de escaneos alcanzado (${dailyCap}/dia)`, 429);
  }

  if ((monthlyRes.count ?? 0) >= GLOBAL_MONTHLY_CAP) {
    return errorResponse('Limite mensual de IA alcanzado', 429);
  }

  // Gemini vision con safety estricto.
  let result: ScanPayload;
  try {
    result = await visionJson<ScanPayload>({
      model: 'gemini-2.5-flash-lite',
      system: SYSTEM_PROMPT,
      prompt: 'Clasifica esta foto y, si es comida, devuelve los alimentos visibles con su porcion estimada en gramos y macros para esa porcion.',
      imageBase64,
      mimeType,
      maxTokens: 500,
      schema: FOOD_SCHEMA,
      strictSafety: true,
    });
  } catch (e) {
    // Gemini bloqueó por safety → es NSFW. Strike + 403.
    if (e instanceof GeminiSafetyBlocked) {
      const v = await recordNsfwViolation(supabase, user.id);
      return jsonResponse({
        ok: false,
        code: v.suspendedUntil ? 'suspended' : 'nsfw_violation',
        error: v.suspendedUntil
          ? 'Tu cuenta fue suspendida temporalmente por subir contenido no permitido.'
          : 'Solo se permiten fotos de comida. Tu cuenta tiene un aviso.',
        strikes_30d: v.strikes30d,
        suspended_until: v.suspendedUntil,
      }, 403);
    }
    const err = e as GeminiError;
    console.error('gemini error', err);
    return errorResponse(`Error de IA: ${err.message}`, err.status ?? 500);
  }

  const contentType: ContentType = (result.content_type === 'food' ||
    result.content_type === 'nsfw' ||
    result.content_type === 'other')
    ? result.content_type
    : 'other';

  // Si el modelo clasifica NSFW (no fue bloqueado por safety, pero detectado
  // por el prompt) → strike + 403, sin cobrar el scan.
  if (contentType === 'nsfw') {
    const v = await recordNsfwViolation(supabase, user.id);
    return jsonResponse({
      ok: false,
      code: v.suspendedUntil ? 'suspended' : 'nsfw_violation',
      error: v.suspendedUntil
        ? 'Tu cuenta fue suspendida temporalmente por subir contenido no permitido.'
        : 'Solo se permiten fotos de comida. Tu cuenta tiene un aviso.',
      strikes_30d: v.strikes30d,
      suspended_until: v.suspendedUntil,
    }, 403);
  }

  // 'food' u 'other': cobramos el scan (consumió tokens de Gemini).
  // Best-effort: si el insert falla, no rompemos la respuesta.
  supabase
    .from('ai_usage_events')
    .insert({ user_id: user.id, fn: 'scan-food' })
    .then(({ error }: { error: unknown }) => {
      if (error) console.error('ai_usage_events insert error', error);
    });

  // 'other' → 200 con items vacíos + mensaje. Cobra cuota.
  if (contentType === 'other') {
    return jsonResponse({
      ok: true,
      code: 'not_food',
      items: [],
      allergy_warnings: [],
      message: 'No detectamos comida en la foto. Intenta con una foto del plato.',
    });
  }

  // 'food' → flujo normal.
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

  const allergies = [
    ...(((onbRes.data?.[0]?.allergies as string[] | null) ?? [])),
    ...((restrictionsRes.data ?? []).map((r: { value: string }) => r.value)),
  ]
    .map((s) => (s ?? '').toLowerCase().trim())
    .filter(Boolean);

  const allergyWarnings: string[] = [];
  if (allergies.length > 0) {
    for (const it of items) {
      if (detectAllergyHit(it.name, allergies)) {
        allergyWarnings.push(it.name);
      }
    }
  }

  return jsonResponse({ ok: true, items, allergy_warnings: allergyWarnings });
});
