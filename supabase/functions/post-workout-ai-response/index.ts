// post-workout-ai-response — responde el feedback post-entreno (solo Premium).
//
// Disparable de dos formas:
//   (a) On-demand: cliente Flutter llama tras submitFeedback
//       body: { feedback_id: uuid }
//   (b) Webhook supabase: row inserted en workout_feedback con ai_response NULL
//
// Modelo: GPT-4o-mini (conversacion frecuente tras cada entreno; barata).
// GPT-4o se reserva exclusivamente para el informe mensual Premium.
//
// Acciones:
//   1. Lee workout_feedback.id, ai_trainer_config, ultimos feedbacks recientes
//   2. Genera respuesta del coach
//   3. UPDATE workout_feedback SET ai_response, ai_responded_at
//   4. INSERT en ai_trainer_messages (role='assistant', message_type='post_workout')
//   5. FCM push al usuario: "<Coach> respondio tu entreno"

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { chat, OpenAIError } from '../_shared/openai.ts';
import { profileContext, trainerPersona, UserProfile } from '../_shared/prompts.ts';
import { pushToUser } from '../_shared/fcm.ts';
import { enforceMonthlyCap, UsageCapError } from '../_shared/usage.ts';

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { feedback_id?: string } = {};
  try { body = await req.json(); } catch {}
  if (!body.feedback_id) return errorResponse('feedback_id required', 400);

  const supabase = serviceClient();

  // Tope duro de costo IA (safety net mensual)
  try {
    await enforceMonthlyCap(supabase, user.id, 'post-workout-ai-response');
  } catch (e) {
    if (e instanceof UsageCapError) return errorResponse('Monthly AI limit reached', 429);
    throw e;
  }

  // 1) Cargar el feedback (debe ser del usuario y sin respuesta aun)
  const { data: feedback } = await supabase
    .from('workout_feedback')
    .select('id, user_id, user_response, ai_response, workout_completed_at')
    .eq('id', body.feedback_id)
    .maybeSingle();
  if (!feedback) return errorResponse('Feedback not found', 404);
  if (feedback.user_id !== user.id) return errorResponse('Forbidden', 403);
  if (feedback.ai_response) {
    return jsonResponse({ ok: true, already_responded: true });
  }

  // 2) Tier premium
  const { data: profile } = await supabase
    .from('profiles')
    .select(
      'id, subscription_tier, fitness_goal, training_location, weight, age, gender',
    )
    .eq('id', user.id)
    .maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);
  if (profile.subscription_tier !== 'premium') {
    return errorResponse('Premium only', 403);
  }

  // 3) Coach config
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

  // 4) Historia reciente de feedback (ultimos 30 dias, max 8)
  const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const { data: recent } = await supabase
    .from('workout_feedback')
    .select('user_response, workout_completed_at')
    .eq('user_id', user.id)
    .gte('workout_completed_at', since)
    .order('workout_completed_at', { ascending: false })
    .limit(8);

  const recentText = (recent ?? [])
    .slice(1) // sin contar el actual
    .map((r, i) => `[hace ${i + 1}]: ${r.user_response}`)
    .join('\n');

  const userProfile: UserProfile = {
    id: profile.id,
    fitness_goal: profile.fitness_goal,
    training_location: profile.training_location,
    weight: profile.weight,
    age: profile.age,
    gender: profile.gender,
  };

  const systemPrompt =
    trainerPersona(cfg) + '\n\n' + profileContext(userProfile) +
    `\n\nFeedback reciente del usuario:\n${recentText || 'sin feedback previo'}` +
    `\n\nContexto: el usuario acaba de completar un entrenamiento y te describe como le fue. Responde con feedback breve, 2-4 oraciones, que reconozca lo que cuenta, agregue un dato util (recuperacion, nutricion, proxima sesion) y cierre con una pregunta corta o un animo.`;

  let aiText: string;
  try {
    aiText = await chat({
      model: 'gpt-4o-mini', // conversacion post-entreno: frecuente y barata
      temperature: 0.65,
      maxTokens: 250,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: feedback.user_response as string },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // 5) Actualiza feedback
  const nowIso = new Date().toISOString();
  await supabase
    .from('workout_feedback')
    .update({ ai_response: aiText, ai_responded_at: nowIso })
    .eq('id', feedback.id);

  // 6) Inserta mensajes en el chat del coach con timestamps explícitos para
  //    garantizar que el mensaje del usuario aparezca antes que la respuesta IA.
  const userMsgAt = nowIso;
  const aiMsgAt = new Date(Date.now() + 1000).toISOString();
  await supabase.from('ai_trainer_messages').insert([
    {
      user_id: user.id,
      role: 'user',
      content: feedback.user_response,
      message_type: 'post_workout',
      created_at: userMsgAt,
    },
    {
      user_id: user.id,
      role: 'assistant',
      content: aiText,
      message_type: 'post_workout',
      created_at: aiMsgAt,
    },
  ]);

  // 7) Notificación en tabla para que el badge del campana se encienda
  try {
    await supabase.from('notifications').insert({
      user_id: user.id,
      type: 'coach_message',
    });
  } catch (_) { /* no bloquear si falla */ }

  // 8) FCM
  await pushToUser(
    supabase,
    user.id,
    `${cfg.trainer_name} respondio tu entreno`,
    aiText.length > 90 ? `${aiText.slice(0, 87)}...` : aiText,
    { type: 'post_workout_response', feedback_id: feedback.id },
  );

  return jsonResponse({ ok: true, assistant_message: aiText });
});
