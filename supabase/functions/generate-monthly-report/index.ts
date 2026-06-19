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
  const isPremium = tier === 'premium';

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
  const monthEndDate = next.toISOString().slice(0, 10);

  // ── Check-ins del mes ──────────────────────────────────────────────────────
  const { data: checkins } = await supabase
    .from('ai_weekly_checkins')
    .select('week_start, response')
    .eq('user_id', userId)
    .gte('week_start', monthIso)
    .lt('week_start', monthEndDate)
    .order('week_start');
  const checkinCount = (checkins ?? []).length;
  const checkinBlock = (checkins ?? [])
    .map((c, i) => `Semana ${i + 1} (${c.week_start}): ${c.response}`)
    .join('\n') || 'sin check-ins esta vez';

  // ── Entrenamiento (ambos tiers) ────────────────────────────────────────────
  const { data: wlogs } = await supabase
    .from('workout_logs')
    .select('id')
    .eq('user_id', userId)
    .gte('logged_at', monthStart)
    .lt('logged_at', monthEnd);
  const sessionCount = (wlogs ?? []).length;

  const { data: sets } = await supabase
    .from('set_logs')
    .select('exercise_name, movement_pattern, weight_kg, reps')
    .eq('user_id', userId)
    .gte('logged_at', monthStart)
    .lt('logged_at', monthEnd)
    .order('logged_at')
    .limit(3000);
  const setRows = (sets ?? []) as Array<{
    exercise_name: string;
    movement_pattern: string | null;
    weight_kg: number;
    reps: number;
  }>;

  let totalVolume = 0;
  const topExercisesArr: Array<{ name: string; sets: number; firstW: number; maxW: number }> = [];
  let trainingBlock = 'sin datos de entrenamiento este mes';
  if (setRows.length > 0) {
    const byExercise: Record<string, { sets: number; firstW: number; maxW: number }> = {};
    const byPattern: Record<string, number> = {};
    for (const s of setRows) {
      const w = Number(s.weight_kg) || 0;
      totalVolume += w * (Number(s.reps) || 0);
      const ex = (byExercise[s.exercise_name] ||= { sets: 0, firstW: w, maxW: 0 });
      ex.sets += 1;
      if (w > ex.maxW) ex.maxW = w;
      const pat = s.movement_pattern ?? 'other';
      byPattern[pat] = (byPattern[pat] ?? 0) + 1;
    }
    for (const [name, v] of Object.entries(byExercise)) {
      topExercisesArr.push({ name, ...v });
    }
    topExercisesArr.sort((a, b) => b.sets - a.sets);
    const topText = topExercisesArr.slice(0, 6).map((v) =>
      `- ${v.name}: ${v.sets} sets, ` +
      (v.maxW > v.firstW ? `subio de ${v.firstW} a ${v.maxW} kg` : `carga max ${v.maxW} kg`)
    ).join('\n');
    const patternText = Object.entries(byPattern)
      .sort((a, b) => b[1] - a[1]).map(([p, n]) => `${p}: ${n}`).join(', ');
    trainingBlock =
      `Sesiones: ${sessionCount}. Series totales: ${setRows.length}. ` +
      `Volumen total: ${Math.round(totalVolume)} kg.\n` +
      `Ejercicios mas trabajados:\n${topText}\n` +
      `Distribucion por patron: ${patternText}.`;
  } else if (sessionCount > 0) {
    trainingBlock = `Sesiones registradas: ${sessionCount} (sin detalle de series).`;
  }

  // ── Nutrición (ambos tiers): promedios + fibra/sodio + adherencia ──────────
  const { data: foods } = await supabase
    .from('food_logs')
    .select('log_date, kcal_total, protein_total, carbs_total, fat_total, fiber_total, sodium_mg_total')
    .eq('user_id', userId)
    .gte('log_date', monthIso)
    .lt('log_date', monthEndDate)
    .limit(5000);
  const foodRows = (foods ?? []) as Array<{
    log_date: string;
    kcal_total: number | null;
    protein_total: number | null;
    carbs_total: number | null;
    fat_total: number | null;
    fiber_total: number | null;
    sodium_mg_total: number | null;
  }>;

  const { data: goals } = await supabase
    .from('nutrition_goals')
    .select('daily_kcal, protein_g, carbs_g, fat_g, fiber_g, sodium_max_mg')
    .eq('user_id', userId)
    .maybeSingle();

  let nutritionDays = 0;
  let avg = { kcal: 0, p: 0, c: 0, f: 0, fiber: 0, sodium: 0 };
  let nutritionBlock = 'sin registros de alimentacion este mes';
  if (foodRows.length > 0) {
    const days = new Set(foodRows.map((f) => f.log_date));
    nutritionDays = days.size;
    const dc = nutritionDays || 1;
    const sum = foodRows.reduce((a, f) => {
      a.kcal += Number(f.kcal_total) || 0;
      a.p += Number(f.protein_total) || 0;
      a.c += Number(f.carbs_total) || 0;
      a.f += Number(f.fat_total) || 0;
      a.fiber += Number(f.fiber_total) || 0;
      a.sodium += Number(f.sodium_mg_total) || 0;
      return a;
    }, { kcal: 0, p: 0, c: 0, f: 0, fiber: 0, sodium: 0 });
    avg = {
      kcal: Math.round(sum.kcal / dc), p: Math.round(sum.p / dc),
      c: Math.round(sum.c / dc), f: Math.round(sum.f / dc),
      fiber: Math.round(sum.fiber / dc), sodium: Math.round(sum.sodium / dc),
    };
    const kcalTarget = (goals?.daily_kcal as number | undefined) ?? 0;
    const pTarget = (goals?.protein_g as number | undefined) ?? 0;
    const adh = kcalTarget > 0
      ? ` Adherencia kcal: ${Math.round((avg.kcal / kcalTarget) * 100)}% de la meta (${kcalTarget}).`
      : '';
    const pAdh = pTarget > 0
      ? ` Proteina: ${avg.p}g vs meta ${pTarget}g (${Math.round((avg.p / pTarget) * 100)}%).`
      : '';
    nutritionBlock =
      `Dias con registro: ${nutritionDays}. Promedio diario: ${avg.kcal} kcal, ` +
      `${avg.p}g proteina, ${avg.c}g carbos, ${avg.f}g grasa, ${avg.fiber}g fibra, ` +
      `${avg.sodium}mg sodio.${adh}${pAdh}`;
  }

  // ── GATE de actividad mínima: no generar reportes vacíos/inútiles ──────────
  const hasEnoughData =
    checkinCount >= 2 || sessionCount >= 4 || nutritionDays >= 8;
  if (!hasEnoughData) {
    return { generated: false, reason: 'insufficient_data' };
  }

  // ── Conversaciones post-entreno (solo Premium) ─────────────────────────────
  let postWorkoutConvoBlock = 'sin conversaciones post-entreno este mes';
  if (isPremium) {
    const { data: pwMsgs } = await supabase
      .from('ai_trainer_messages')
      .select('role, content')
      .eq('user_id', userId)
      .eq('message_type', 'post_workout')
      .gte('created_at', monthStart)
      .lt('created_at', monthEnd)
      .order('created_at')
      .limit(60);
    const pw = (pwMsgs ?? []) as Array<{ role: string; content: string }>;
    if (pw.length > 0) {
      postWorkoutConvoBlock = pw
        .map((m) => `${m.role === 'assistant' ? cfg.trainer_name : 'Usuario'}: ${m.content}`)
        .join('\n');
    }
  }

  // ── Stats deterministas (tarjetas en la UI) ────────────────────────────────
  const stats = {
    month: monthIso,
    checkins: checkinCount,
    training: {
      sessions: sessionCount,
      total_sets: setRows.length,
      total_volume_kg: Math.round(totalVolume),
      top_exercises: topExercisesArr.slice(0, 5).map((v) => ({
        name: v.name, sets: v.sets, max_kg: v.maxW,
        progressed: v.maxW > v.firstW,
      })),
    },
    nutrition: {
      days_logged: nutritionDays,
      avg_kcal: avg.kcal, avg_protein: avg.p, avg_carbs: avg.c,
      avg_fat: avg.f, avg_fiber: avg.fiber, avg_sodium: avg.sodium,
      target_kcal: (goals?.daily_kcal as number | undefined) ?? null,
      target_protein: (goals?.protein_g as number | undefined) ?? null,
      kcal_adherence_pct: goals?.daily_kcal && avg.kcal
        ? Math.round((avg.kcal / (goals.daily_kcal as number)) * 100) : null,
      protein_adherence_pct: goals?.protein_g && avg.p
        ? Math.round((avg.p / (goals.protein_g as number)) * 100) : null,
    },
  };

  const system = trainerPersona(cfg) +
    `\n\nObjetivo del usuario: ${profile.fitness_goal ?? 'sin definir'}.` +
    (isPremium
      ? `\n\nEres su entrenador personal y entregas el REPORTE MENSUAL COMPLETO con datos reales (entrenamiento, nutricion con adherencia, conversaciones post-entreno y check-ins). Usa numeros concretos, no generalidades.
Devuelve el reporte en MARKDOWN con estas secciones (usa "## " para cada titulo, exactamente estos nombres):
## Resumen del mes
3-4 oraciones con lo esencial.
## Entrenamiento
Volumen, progreso de cargas, patrones y constancia (cita sesiones y kg reales).
## Nutricion
Adherencia al registro, kcal y macros promedio vs su meta (cita los %).
## Lo que conversamos
Energia, recuperacion, animo y dudas que surgieron post-entreno (si no hubo, dilo en 1 linea).
## Plan para el proximo mes
3-5 bullets accionables y especificos.
## Cierre
1-2 oraciones motivadoras alineadas a su objetivo y tono.
400-600 palabras, parrafos cortos.`
      : `\n\nEntregas un RESUMEN MENSUAL de coach para usuario Plus, con datos reales (entrenamiento y nutricion). Devuelve MARKDOWN con estas secciones (usa "## "):
## Resumen del mes
2-3 oraciones citando sesiones y/o adherencia nutricional real.
## Que mejorar
2-3 bullets accionables para el proximo mes.
## Cierre
1 oracion motivadora.
Total 130-200 palabras.`);

  const userPrompt = `DATOS DEL MES (${monthIso})

[Entrenamiento]
${trainingBlock}

[Nutricion]
${nutritionBlock}
${isPremium ? `\n[Conversaciones post-entreno]\n${postWorkoutConvoBlock}\n` : ''}
[Check-ins semanales]
${checkinBlock}`;

  let content: string;
  try {
    content = await chat({
      model: isPremium ? 'gpt-4o' : 'gpt-4o-mini',
      temperature: 0.6,
      maxTokens: isPremium ? 1200 : 420,
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
    stats,
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
    // Validamos contra el MISMO service_role_key del vault que envía el cron
    // (vía RPC), tolerando desajustes con la env auto-inyectada (rotación).
    const auth = req.headers.get('Authorization') ?? '';
    let authorized = auth === `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`;
    if (!authorized) {
      const { data: ok } = await supabase.rpc('is_cron_authorized', { p_auth: auth });
      authorized = ok === true;
    }
    if (!authorized) return errorResponse('Forbidden', 403);

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
