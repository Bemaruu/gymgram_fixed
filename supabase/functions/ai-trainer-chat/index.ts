// ai-trainer-chat — chat libre con el coach IA (solo Premium).
//
// Flujo:
//  1. Auth user
//  2. Verifica tier == premium
//  3. Verifica dailyMessagesUsed < 10 (cuenta msgs role='user' de hoy)
//  4. Inserta el msg del usuario en ai_trainer_messages
//  5. Carga ai_trainer_config (persona) + ultimos 20 msgs + perfil
//  6. Llama a GPT-4o-mini con system prompt segun tono
//  7. Inserta respuesta assistant en ai_trainer_messages
//
// Input: { content: string }
// Output: { ok, assistant_message: string, daily_used: number }

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { chat, ChatMessage, OpenAIError } from '../_shared/openai.ts';
import { profileContext, trainerPersona, UserProfile } from '../_shared/prompts.ts';

const DAILY_LIMIT = 10;

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { content?: string } = {};
  try { body = await req.json(); } catch {}
  const content = (body.content ?? '').trim();
  if (!content) return errorResponse('content required', 400);
  if (content.length > 2000) return errorResponse('content too long', 400);

  const supabase = serviceClient();

  // 1) Tier check
  const { data: profile } = await supabase
    .from('profiles')
    .select(
      'id, subscription_tier, fitness_goal, training_location, weight, age, gender',
    )
    .eq('id', user.id)
    .maybeSingle();
  if (!profile) return errorResponse('Profile not found', 404);
  if (profile.subscription_tier !== 'premium') {
    return errorResponse('AI trainer chat requires Premium', 403);
  }

  // 2) Daily limit
  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);
  const { data: todayRows } = await supabase
    .from('ai_trainer_messages')
    .select('id')
    .eq('user_id', user.id)
    .eq('role', 'user')
    .gte('created_at', startOfDay.toISOString());
  const usedToday = (todayRows as unknown[] | null)?.length ?? 0;
  if (usedToday >= DAILY_LIMIT) {
    return errorResponse('Daily message limit reached', 429);
  }

  // 3) Inserta msg user
  const { error: insertUserErr } = await supabase
    .from('ai_trainer_messages')
    .insert({
      user_id: user.id,
      role: 'user',
      content,
      message_type: 'chat',
    });
  if (insertUserErr) {
    console.error('insert user msg error', insertUserErr);
    return errorResponse('Could not record message', 500);
  }

  // 4) Config + history
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

  const { data: historyDesc } = await supabase
    .from('ai_trainer_messages')
    .select('role, content')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(20);
  const history = (historyDesc ?? []).reverse();

  // 5) Onboarding (opcional, da contexto)
  const { data: onbRows } = await supabase
    .from('user_onboarding_data')
    .select('training_level, session_duration_minutes')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(1);
  const onb = onbRows?.[0];

  const userProfile: UserProfile = {
    id: profile.id,
    fitness_goal: profile.fitness_goal,
    training_location: profile.training_location,
    experience_level: onb?.training_level,
    weight: profile.weight,
    age: profile.age,
    gender: profile.gender,
    session_duration_min: onb?.session_duration_minutes,
  };

  const systemPrompt =
    trainerPersona(cfg) + '\n\n' + profileContext(userProfile);

  const messages: ChatMessage[] = [
    { role: 'system', content: systemPrompt },
    ...history.map((m) => ({
      role: m.role as 'user' | 'assistant',
      content: m.content as string,
    })),
  ];

  // 6) OpenAI
  let aiText: string;
  try {
    aiText = await chat({
      model: 'gpt-4o-mini',
      temperature: 0.7,
      maxTokens: 400,
      messages,
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return errorResponse(`AI error: ${err.message}`, err.status ?? 500);
  }

  // 7) Inserta assistant (RLS bloquea desde cliente, service role OK)
  const { error: insertAiErr } = await supabase
    .from('ai_trainer_messages')
    .insert({
      user_id: user.id,
      role: 'assistant',
      content: aiText,
      message_type: 'chat',
    });
  if (insertAiErr) console.error('insert assistant msg error', insertAiErr);

  return jsonResponse({
    ok: true,
    assistant_message: aiText,
    daily_used: usedToday + 1,
  });
});
