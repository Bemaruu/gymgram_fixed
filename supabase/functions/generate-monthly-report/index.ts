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

  const isPremium = tier === 'premium';
  const monthEndDate = next.toISOString().slice(0, 10);

  const checkinBlock = (checkins ?? [])
    .map((c, i) => `Semana ${i + 1} (${c.week_start}): ${c.response}`)
    .join('\n') || 'sin check-ins esta vez';

  // ===== Datos completos del mes (solo Premium: alimentan el informe gpt-4o) =====
  let trainingBlock = 'sin datos de entrenamiento este mes';
  let nutritionBlock = 'sin registros de alimentacion este mes';
  let postWorkoutConvoBlock = 'sin conversaciones post-entreno este mes';

  if (isPremium) {
    // 1) Entrenamientos: sesiones (workout_logs) + series (set_logs)
    const { data: wlogs } = await supabase
      .from('workout_logs')
      .select('id')
      .eq('user_id', userId)
      .gte('logged_at', monthIso)
      .lt('logged_at', monthEndDate);
    const sessionCount = (wlogs ?? []).length;

    const { data: sets } = await supabase
      .from('set_logs')
      .select('exercise_name, movement_pattern, weight_kg, reps, logged_at')
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

    if (setRows.length > 0) {
      let totalVolume = 0;
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
      const topExercises = Object.entries(byExercise)
        .sort((a, b) => b[1].sets - a[1].sets)
        .slice(0, 6)
        .map(([name, v]) =>
          `- ${name}: ${v.sets} sets, ` +
          (v.maxW > v.firstW
            ? `subio de ${v.firstW} a ${v.maxW} kg`
            : `carga max ${v.maxW} kg`)
        )
        .join('\n');
      const patternText = Object.entries(byPattern)
        .sort((a, b) => b[1] - a[1])
        .map(([p, n]) => `${p}: ${n}`)
        .join(', ');
      trainingBlock =
        `Sesiones: ${sessionCount}. Series totales: ${setRows.length}. ` +
        `Volumen total: ${Math.round(totalVolume)} kg.\n` +
        `Ejercicios mas trabajados:\n${topExercises}\n` +
        `Distribucion por patron de movimiento: ${patternText}.`;
    } else if (sessionCount > 0) {
      trainingBlock = `Sesiones registradas: ${sessionCount} (sin detalle de series).`;
    }

    // 2) Nutricion: food_logs del mes (promedios diarios reales)
    const { data: foods } = await supabase
      .from('food_logs')
      .select('log_date, kcal_total, protein_total, carbs_total, fat_total')
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
    }>;
    if (foodRows.length > 0) {
      const days = new Set(foodRows.map((f) => f.log_date));
      const dayCount = days.size || 1;
      const sum = foodRows.reduce(
        (a, f) => {
          a.kcal += Number(f.kcal_total) || 0;
          a.p += Number(f.protein_total) || 0;
          a.c += Number(f.carbs_total) || 0;
          a.f += Number(f.fat_total) || 0;
          return a;
        },
        { kcal: 0, p: 0, c: 0, f: 0 },
      );
      nutritionBlock =
        `Dias con registro: ${days.size}. Promedio diario: ` +
        `${Math.round(sum.kcal / dayCount)} kcal, ` +
        `${Math.round(sum.p / dayCount)}g proteina, ` +
        `${Math.round(sum.c / dayCount)}g carbohidratos, ` +
        `${Math.round(sum.f / dayCount)}g grasa.`;
    }

    // 3) Conversaciones post-entreno: Q&A coach<->usuario (ai_trainer_messages)
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
        .map((m) =>
          `${m.role === 'assistant' ? cfg.trainer_name : 'Usuario'}: ${m.content}`
        )
        .join('\n');
    }
  }

  const system = trainerPersona(cfg) +
    `\n\nObjetivo del usuario: ${profile.fitness_goal ?? 'sin definir'}.` +
    (isPremium
      ? `\n\nEres su entrenador personal y vas a entregar el REPORTE MENSUAL COMPLETO. Tienes datos reales de entrenamiento, nutricion, las conversaciones post-entreno y los check-ins. Usalos con numeros concretos. Estructura:
1) Resumen del mes (3-4 oraciones).
2) Analisis de entrenamiento: volumen, progreso de cargas, patrones trabajados y constancia.
3) Analisis nutricional: adherencia al registro, calorias y macros promedio vs su objetivo.
4) Lo que surgio en las conversaciones post-entreno (energia, recuperacion, animo, dudas recurrentes).
5) Recomendaciones concretas para el proximo mes (3-5 bullets accionables).
6) Cierre motivador alineado a su objetivo y tono.
Se especifico, cita los numeros reales y evita generalidades. 400-650 palabras, parrafos cortos, sin titulos exagerados.`
      : `\n\nGenera un RESUMEN MENSUAL BREVE de coach. 2 parrafos cortos: como fue el mes y un consejo accionable para el proximo. Total 90-140 palabras.`);

  const userPrompt = isPremium
    ? `DATOS DEL MES (${monthIso})

[Entrenamiento]
${trainingBlock}

[Nutricion]
${nutritionBlock}

[Conversaciones post-entreno]
${postWorkoutConvoBlock}

[Check-ins semanales]
${checkinBlock}`
    : `Check-ins del mes:\n${checkinBlock}`;

  let content: string;
  try {
    content = await chat({
      model: isPremium ? 'gpt-4o' : 'gpt-4o-mini',
      temperature: 0.65,
      maxTokens: isPremium ? 1100 : 280,
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
