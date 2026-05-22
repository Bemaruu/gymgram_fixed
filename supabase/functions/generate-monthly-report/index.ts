// generate-monthly-report — genera el reporte mensual de IA.
//
// Dos modos de invocacion:
//   (a) Cron (pg_cron via pg_net): body { batch: true }
//       Recorre todos los usuarios Plus/Premium sin reporte para el mes objetivo.
//   (b) On-demand: body { user_id?: string, month?: 'YYYY-MM-01' }
//       Si no se pasa user_id, usa el caller autenticado.
//
// Plus  -> GPT-4o-mini (resumen breve)
// Premium -> GPT-4o (reporte completo)
//
// FCM: notifica al usuario cuando el reporte queda listo.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, handlePreflight, jsonResponse } from '../_shared/cors.ts';
import { getAuthedUser, serviceClient } from '../_shared/supabase.ts';
import { chat, OpenAIError } from '../_shared/openai.ts';
import { trainerPersona } from '../_shared/prompts.ts';
import { pushToUser } from '../_shared/fcm.ts';

type Tier = 'plus' | 'premium';

function firstOfPrevMonthIso(): string {
  const now = new Date();
  const first = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
  const y = first.getUTCFullYear();
  const m = (first.getUTCMonth() + 1).toString().padStart(2, '0');
  return `${y}-${m}-01`;
}

async function generateFor(
  supabase: ReturnType<typeof serviceClient>,
  userId: string,
  monthIso: string,
): Promise<{ generated: boolean; reason?: string }> {
  // Skip si ya existe
  const { data: existing } = await supabase
    .from('ai_monthly_summaries')
    .select('id')
    .eq('user_id', userId)
    .eq('month', monthIso)
    .maybeSingle();
  if (existing) return { generated: false, reason: 'already_exists' };

  const { data: profile } = await supabase
    .from('profiles')
    .select('subscription_tier, fitness_goal')
    .eq('id', userId)
    .maybeSingle();
  if (!profile) return { generated: false, reason: 'no_profile' };
  if (profile.subscription_tier === 'free') {
    return { generated: false, reason: 'free_tier' };
  }
  const tier = profile.subscription_tier as Tier;

  const { data: cfgRow } = await supabase
    .from('ai_trainer_config')
    .select('trainer_name, tone, focus')
    .eq('user_id', userId)
    .maybeSingle();
  const cfg = cfgRow ?? {
    trainer_name: 'Coach',
    tone: 'motivador',
    focus: 'ambos',
  };

  // Rango: mes anterior completo
  const monthStart = `${monthIso}T00:00:00Z`;
  const next = new Date(monthIso + 'T00:00:00Z');
  next.setUTCMonth(next.getUTCMonth() + 1);
  const monthEnd = next.toISOString();

  // Check-ins del mes
  const { data: checkins } = await supabase
    .from('ai_weekly_checkins')
    .select('week_start, response')
    .eq('user_id', userId)
    .gte('week_start', monthIso)
    .lt('week_start', next.toISOString().slice(0, 10))
    .order('week_start');

  // Feedback post-workout del mes (solo Premium)
  let workoutFeedback: { user_response: string }[] = [];
  if (tier === 'premium') {
    const { data: fb } = await supabase
      .from('workout_feedback')
      .select('user_response, workout_completed_at')
      .eq('user_id', userId)
      .gte('workout_completed_at', monthStart)
      .lt('workout_completed_at', monthEnd)
      .order('workout_completed_at');
    workoutFeedback = (fb ?? []) as { user_response: string }[];
  }

  const checkinBlock = (checkins ?? [])
    .map((c, i) => `Semana ${i + 1} (${c.week_start}): ${c.response}`)
    .join('\n') || 'sin check-ins esta vez';
  const fbBlock = workoutFeedback.length > 0
    ? workoutFeedback.map((f, i) => `Entreno ${i + 1}: ${f.user_response}`).join('\n')
    : null;

  const isPremium = tier === 'premium';
  const system = trainerPersona(cfg) +
    `\n\nObjetivo del usuario: ${profile.fitness_goal ?? 'sin definir'}.` +
    (isPremium
      ? `\n\nGenera un REPORTE MENSUAL COMPLETO de entrenador personal. Estructura:
1) Resumen del mes (3-4 oraciones).
2) Patrones detectados en los entrenamientos y la semana del usuario.
3) Recomendaciones concretas para el proximo mes (3 bullets accionables).
4) Cierre motivador alineado a su objetivo y tono.
Total 250-400 palabras. Sin titulos exagerados; usa parrafos cortos.`
      : `\n\nGenera un RESUMEN MENSUAL BREVE de coach. 2 parrafos cortos: como fue el mes y un consejo accionable para el proximo. Total 90-140 palabras.`);

  const userPrompt = `Check-ins del mes:
${checkinBlock}

${fbBlock ? `Feedback post-entreno:\n${fbBlock}` : ''}`;

  let content: string;
  try {
    content = await chat({
      model: isPremium ? 'gpt-4o' : 'gpt-4o-mini',
      temperature: 0.65,
      maxTokens: isPremium ? 700 : 280,
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: userPrompt },
      ],
    });
  } catch (e) {
    const err = e as OpenAIError;
    console.error('OpenAI error', err);
    return { generated: false, reason: `ai_error:${err.message}` };
  }

  await supabase.from('ai_monthly_summaries').insert({
    user_id: userId,
    month: monthIso,
    tier_at_generation: tier,
    summary_type: isPremium ? 'premium_full' : 'plus_basic',
    content,
  });

  await pushToUser(
    supabase,
    userId,
    'Tu reporte del mes esta listo',
    `${cfg.trainer_name} preparo tu resumen del mes pasado.`,
    { type: 'monthly_report', month: monthIso },
  );

  return { generated: true };
}

serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  let body: { batch?: boolean; user_id?: string; month?: string } = {};
  try { body = await req.json(); } catch {}

  const supabase = serviceClient();
  const monthIso = body.month ?? firstOfPrevMonthIso();

  // --- (a) modo batch: llamado desde pg_cron via service_role ---
  if (body.batch) {
    // El header Authorization=Bearer <service_role> permite invocar sin user JWT.
    // Verificamos eso para no exponer la ruta a usuarios.
    const auth = req.headers.get('Authorization') ?? '';
    const expected = `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`;
    if (auth !== expected) return errorResponse('Forbidden', 403);

    // Todos los usuarios Plus/Premium
    const { data: users } = await supabase
      .from('profiles')
      .select('id')
      .in('subscription_tier', ['plus', 'premium']);

    const results: Array<{ user_id: string; ok: boolean; reason?: string }> = [];
    for (const u of users ?? []) {
      const r = await generateFor(supabase, u.id as string, monthIso);
      results.push({ user_id: u.id as string, ok: r.generated, reason: r.reason });
    }
    return jsonResponse({ ok: true, month: monthIso, count: results.length, results });
  }

  // --- (b) modo on-demand: usuario autenticado ---
  const user = await getAuthedUser(req);
  if (!user) return errorResponse('Unauthorized', 401);
  const targetUser = body.user_id ?? user.id;
  if (targetUser !== user.id) return errorResponse('Forbidden', 403);

  const r = await generateFor(supabase, targetUser, monthIso);
  return jsonResponse({ ok: r.generated, reason: r.reason, month: monthIso });
});
