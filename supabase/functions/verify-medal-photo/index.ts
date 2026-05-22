// verify-medal-photo — verifica con GPT-4o vision la foto de prueba de una medalla
// de evento y, si aprueba, la otorga (service role).
//
// Flujo:
//  1. Auth user
//  2. Valida badge_id (debe tener criterio de verificacion definido aqui)
//  3. Valida que image_path pertenezca al usuario ({uid}/...)
//  4. Si ya tiene la medalla, responde ok sin gastar IA
//  5. Descarga la imagen del bucket privado (service role) -> data URL base64
//  6. GPT-4o vision con detail:low -> { approved, reason }
//  7. Registra la solicitud en medal_submissions con el veredicto
//  8. Si approved -> inserta en user_badges (otorga)
//
// Input:  { badge_id: string, image_path: string }
// Output: { ok, approved: boolean, reason: string }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { encode as base64Encode } from 'https://deno.land/std@0.168.0/encoding/base64.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { visionJson, OpenAIError } from '../_shared/openai.ts';

// Criterios de verificacion por medalla (fuente de verdad en el servidor).
const CRITERIA: Record<string, string> = {
  conquistador:
    'La foto muestra a una persona haciendo actividad fisica, entrenando o posando al aire libre en un cerro, colina, montana, sendero, cumbre o naturaleza. RECHAZA fotos dentro de un gimnasio techado, selfies en una habitacion, o capturas de pantalla.',
  runner:
    'La foto es una captura de pantalla de una app de running o reloj deportivo (Strava, Nike Run, Adidas, Apple Salud, Google Fit, Garmin, Samsung Health) que muestra una distancia recorrida de AL MENOS 5.0 km (o 5000 m). Lee la distancia. RECHAZA si la distancia es menor a 5 km o si no hay distancia visible.',
  renacido:
    'La foto es una foto de progreso fisico/corporal de una persona (cuerpo de frente o de perfil mostrando su condicion fisica). Acepta una sola foto de fisico o una comparacion antes/despues. RECHAZA fotos sin relacion, solo del rostro, o imagenes que no muestren el cuerpo.',
};

const SYSTEM_PROMPT =
  'Eres un verificador estricto de retos fitness para otorgar medallas. ' +
  'Recibes un criterio y una imagen. Responde UNICAMENTE con JSON valido: ' +
  '{"approved": boolean, "reason": string}. ' +
  'El campo "reason" debe ser una explicacion breve en espanol (max 12 palabras). ' +
  'Aprueba solo si la imagen cumple claramente el criterio; ante la duda, rechaza.';

function contentTypeFor(path: string): string {
  const ext = path.split('.').pop()?.toLowerCase();
  if (ext === 'png') return 'image/png';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'heic') return 'image/heic';
  return 'image/jpeg';
}

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { badge_id?: string; image_path?: string } = {};
  try { body = await req.json(); } catch {}
  const badgeId = (body.badge_id ?? '').trim();
  const imagePath = (body.image_path ?? '').trim();

  if (!badgeId || !CRITERIA[badgeId]) {
    return errorResponse('badge_id invalido o sin verificacion por foto', 400);
  }
  if (!imagePath) return errorResponse('image_path requerido', 400);
  // La imagen debe vivir bajo la carpeta del propio usuario.
  if (!imagePath.startsWith(`${user.id}/`)) {
    return errorResponse('Forbidden', 403);
  }

  const supabase = serviceClient();

  // Si ya tiene la medalla, no gastamos IA.
  const { data: existing } = await supabase
    .from('user_badges')
    .select('badge_id, progress')
    .eq('user_id', user.id)
    .eq('badge_id', badgeId)
    .maybeSingle();
  if (existing && (existing.progress as number) >= 1.0) {
    return jsonResponse({ ok: true, approved: true, reason: 'Ya tienes esta medalla.' });
  }

  // Descarga la imagen del bucket privado.
  const { data: blob, error: dlErr } = await supabase.storage
    .from('medal-proofs')
    .download(imagePath);
  if (dlErr || !blob) {
    console.error('download error', dlErr);
    return errorResponse('No se pudo leer la imagen', 404);
  }
  const bytes = new Uint8Array(await blob.arrayBuffer());
  const dataUrl = `data:${contentTypeFor(imagePath)};base64,${base64Encode(bytes)}`;

  // Verificacion con vision.
  let verdict: { approved: boolean; reason: string };
  try {
    verdict = await visionJson<{ approved: boolean; reason: string }>({
      model: 'gpt-4o',
      detail: 'low',
      system: SYSTEM_PROMPT,
      prompt: `Criterio: ${CRITERIA[badgeId]}`,
      imageUrl: dataUrl,
      maxTokens: 200,
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('vision error', err);
    return errorResponse(`Error de IA: ${err.message}`, err.status ?? 500);
  }

  const approved = verdict.approved === true;
  const reason = (verdict.reason ?? '').toString().slice(0, 160);

  // Registra la solicitud con el veredicto.
  await supabase.from('medal_submissions').insert({
    user_id: user.id,
    badge_id: badgeId,
    image_path: imagePath,
    status: approved ? 'approved' : 'rejected',
    ai_verdict: approved,
    ai_reason: reason,
    reviewed_at: new Date().toISOString(),
  });

  // Si aprueba, otorga la medalla (service role bypassa RLS).
  if (approved) {
    await supabase
      .from('user_badges')
      .upsert(
        { user_id: user.id, badge_id: badgeId, progress: 1.0, earned_at: new Date().toISOString() },
        { onConflict: 'user_id,badge_id' },
      );
  }

  return jsonResponse({ ok: true, approved, reason });
});
