// weekly-checkin-response — respuesta breve al check-in semanal (Plus + Premium).
//
// Input: { checkin_id: uuid }
// Output: { ok, assistant_message }
//
// Modelo: GPT-4o-mini (respuesta breve, no necesita razonamiento profundo).
// No envia FCM: el usuario ya ve la respuesta en el sheet de confirmacion.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { chat, OpenAIError } from '../_shared/openai.ts';
import { trainerPersona } from '../_shared/prompts.ts';
import { enforceMonthlyCap, UsageCapError } from '../_shared/usage.ts';

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { checkin_id?: string } = {};
  try { body = await req.json(); } catch {}
  if (!body.checkin_id) return errorResponse('checkin_id required', 400);

  const supabase = serviceClient();

  // Tope duro de costo IA (safety net mensual)
  try {
    await enforceMonthlyCap(supabase, user.id, 'weekly-checkin-response');
  } catch (e) {
    if (e instanceof UsageCapError) return errorResponse('Monthly AI limit reached', 429);
    throw e;
  }

  const { data: checkin } = await supabase
    .from('ai_weekly_checkins')
    .select('id, user_id, response, week_start')
    .eq('id', body.checkin_id)
    .maybeSingle();
  if (!checkin) return errorResponse('Checkin not found', 404);
  if (checkin.user_id !== user.id) return errorResponse('Forbidden', 403);

  const { data: profile } = await supabase
    .from('profiles')
    .select('subscription_tier, fitness_goal')
    .eq('id', user.id)
    .maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);
  if (profile.subscription_tier === 'free') {
    return errorResponse('Plus or Premium only', 403);
  }

  const { data: cfgRow } = await supabase
    .from('ai_trainer_config')
    .select('trainer_name, tone, focus')
    .eq('user_id', user.id)
    .maybeSingle();
  const cfg = cfgRow ?? {
    trainer_name: 'Coach',
    tone: 'motivador',
    focus: 'ambos',
  };

  const system = trainerPersona(cfg) +
    `\n\nObjetivo del usuario: ${profile.fitness_goal ?? 'sin definir'}.` +
    `\n\nContexto: el usuario hizo su check-in semanal contandote como le fue. Responde con 2-3 oraciones breves: reconoce lo bueno, da un consejo concreto para la proxima semana, cierra con animo. Sin pregunta final.`;

  let aiText: string;
  try {
    aiText = await chat({
      model: 'gpt-4o-mini',
      temperature: 0.6,
      maxTokens: 180,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: checkin.response as string },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // Inserta en el chat del coach como rastro (visible para Premium en su chat)
  // Plus tambien lo guarda; si quisieras esconderlo en Plus, filtra en cliente.
  await supabase.from('ai_trainer_messages').insert([
    {
      user_id: user.id,
      role: 'user',
      content: checkin.response,
      message_type: 'weekly_checkin',
    },
    {
      user_id: user.id,
      role: 'assistant',
      content: aiText,
      message_type: 'weekly_checkin',
    },
  ]);

  return jsonResponse({ ok: true, assistant_message: aiText });
});
