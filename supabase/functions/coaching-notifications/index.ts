import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Dispatcher de notificaciones de acompañamiento.
// Lo invoca pg_cron cada hora (con bearer service_role). Para cada usuario
// elegible calcula su hora LOCAL (vía tz_offset_minutes) y decide si enviar
// una notificación según su coaching_style y su actividad reciente.
//
// Reglas de cadencia (confirmadas con producto):
//   gentle  -> tope 1/día. Mañana motivacional ~ algunas veces/semana.
//              Nudge no_workout solo si lleva 4+ días sin entrenar.
//   balanced-> tope 2/día. Mañana motivacional diaria + nudges (2+ días).
//   strict  -> tope 3/día. Mañana + noche motivacional + nudges agresivos.
// Una sola notificación por usuario por corrida (la de mayor prioridad).

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const HOUR = 3600_000;
const DAY = 86_400_000;

// Horas locales objetivo por slot.
const SLOT_MORNING = 8;
const SLOT_FOOD = 13;
const SLOT_INACTIVITY = 19;
const SLOT_NIGHT = 21;

type Candidate = {
  user_id: string;
  coaching_style: 'gentle' | 'balanced' | 'strict';
  tz_offset_minutes: number;
  last_workout: string | null;
  last_food: string | null;
  last_open: string | null;
  sent_24h: number;
  last_morning: string | null;
  last_evening: string | null;
  last_no_workout: string | null;
  last_no_food: string | null;
  last_inactive_app: string | null;
};

type Category =
  | 'morning_motivation'
  | 'evening_motivation'
  | 'no_workout'
  | 'no_food_log'
  | 'inactive_app';

const DAILY_CAP = { gentle: 1, balanced: 2, strict: 3 } as const;

function daysSinceDate(d: string | null, nowMs: number): number {
  if (!d) return 9999;
  // d es 'YYYY-MM-DD'. Comparar a medianoche UTC del día.
  const t = Date.parse(d + 'T00:00:00Z');
  if (Number.isNaN(t)) return 9999;
  return Math.floor((nowMs - t) / DAY);
}

function daysSinceTs(ts: string | null, nowMs: number): number {
  if (!ts) return 9999;
  const t = Date.parse(ts);
  if (Number.isNaN(t)) return 9999;
  return Math.floor((nowMs - t) / DAY);
}

function sentWithin(ts: string | null, hours: number, nowMs: number): boolean {
  if (!ts) return false;
  const t = Date.parse(ts);
  if (Number.isNaN(t)) return false;
  return nowMs - t < hours * HOUR;
}

// Devuelve la categoría a enviar para esta corrida, o null.
function decide(c: Candidate, localHour: number, nowMs: number): Category | null {
  const style = c.coaching_style;
  if (c.sent_24h >= DAILY_CAP[style]) return null;

  const dWorkout = daysSinceDate(c.last_workout, nowMs);
  const dFoodToday = daysSinceDate(c.last_food, nowMs); // 0 = comió hoy (UTC aprox)
  const dOpen = daysSinceTs(c.last_open, nowMs);

  if (style === 'gentle') {
    if (localHour === SLOT_MORNING && !sentWithin(c.last_morning, 40, nowMs)) {
      // "de vez en cuando": ~40% de las mañanas elegibles.
      if (Math.random() < 0.4) return 'morning_motivation';
    }
    if (localHour === SLOT_INACTIVITY && dWorkout >= 4 &&
        !sentWithin(c.last_no_workout, 72, nowMs)) {
      return 'no_workout';
    }
    return null;
  }

  if (style === 'balanced') {
    if (localHour === SLOT_MORNING && !sentWithin(c.last_morning, 20, nowMs)) {
      return 'morning_motivation';
    }
    if (localHour === SLOT_FOOD && dFoodToday >= 2 &&
        !sentWithin(c.last_no_food, 48, nowMs)) {
      return 'no_food_log';
    }
    if (localHour === SLOT_INACTIVITY) {
      if (dWorkout >= 2 && !sentWithin(c.last_no_workout, 48, nowMs)) {
        return 'no_workout';
      }
      if (dOpen >= 3 && !sentWithin(c.last_inactive_app, 72, nowMs)) {
        return 'inactive_app';
      }
    }
    return null;
  }

  // strict
  if (localHour === SLOT_MORNING && !sentWithin(c.last_morning, 18, nowMs)) {
    return 'morning_motivation';
  }
  if (localHour === SLOT_FOOD && dFoodToday >= 1 &&
      !sentWithin(c.last_no_food, 24, nowMs)) {
    return 'no_food_log';
  }
  if (localHour === SLOT_INACTIVITY) {
    if (dWorkout >= 1 && !sentWithin(c.last_no_workout, 24, nowMs)) {
      return 'no_workout';
    }
    if (dOpen >= 2 && !sentWithin(c.last_inactive_app, 48, nowMs)) {
      return 'inactive_app';
    }
  }
  if (localHour === SLOT_NIGHT && !sentWithin(c.last_evening, 18, nowMs)) {
    return 'evening_motivation';
  }
  return null;
}

function slotName(localHour: number): string {
  if (localHour === SLOT_MORNING) return 'morning';
  if (localHour === SLOT_FOOD) return 'midday';
  if (localHour === SLOT_INACTIVITY) return 'evening_check';
  if (localHour === SLOT_NIGHT) return 'night';
  return 'other';
}

serve(async (req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // Solo el cron puede dispararlo. Validamos el bearer contra el MISMO
  // service_role_key guardado en vault que envía el cron (vía RPC), para no
  // depender de que la env auto-inyectada coincida con la copia del vault
  // (una rotación de llaves dejaba esto en 401 y mataba las notificaciones).
  const auth = req.headers.get('Authorization') ?? '';
  let authorized = auth === `Bearer ${SERVICE_ROLE_KEY}`;
  if (!authorized) {
    const { data: ok } = await supabase.rpc('is_cron_authorized', { p_auth: auth });
    authorized = ok === true;
  }
  if (!authorized) {
    return new Response('Unauthorized', { status: 401 });
  }

  const nowMs = Date.now();

  const { data: candidates, error } = await supabase
    .rpc('coaching_notification_candidates');

  if (error) {
    return new Response(`RPC error: ${error.message}`, { status: 500 });
  }

  const rows = (candidates ?? []) as Candidate[];

  // Cache de plantillas por (category|tone) para no re-consultar.
  const tplCache = new Map<string, { id: string; title: string; body: string }[]>();
  async function pickTemplate(category: Category, tone: string) {
    const key = `${category}|${tone}`;
    let list = tplCache.get(key);
    if (!list) {
      const { data } = await supabase
        .from('notification_templates')
        .select('id,title,body')
        .eq('active', true)
        .eq('category', category)
        .in('tone', [tone, 'any']);
      list = (data ?? []) as { id: string; title: string; body: string }[];
      tplCache.set(key, list);
    }
    if (list.length === 0) return null;
    return list[Math.floor(Math.random() * list.length)];
  }

  let sent = 0;
  let considered = 0;

  for (const c of rows) {
    const localMs = nowMs + c.tz_offset_minutes * 60_000;
    const localHour = new Date(localMs).getUTCHours();

    const category = decide(c, localHour, nowMs);
    if (!category) continue;
    considered++;

    const tpl = await pickTemplate(category, c.coaching_style);
    if (!tpl) continue;

    // Enviar push reutilizando send-push-notification.
    const pushRes = await fetch(
      `${SUPABASE_URL}/functions/v1/send-push-notification`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({
          user_id: c.user_id,
          title: tpl.title,
          body: tpl.body,
        }),
      },
    );

    // Solo registramos en el log si el push salió (200). Si el usuario no tiene
    // token (404) no contamos el envío para no quemar cupos en vano.
    if (pushRes.ok) {
      sent++;
      await supabase.from('notification_dispatch_log').insert({
        user_id: c.user_id,
        category,
        template_id: tpl.id,
        slot: slotName(localHour),
      });
    }
  }

  return new Response(
    JSON.stringify({ ok: true, candidates: rows.length, considered, sent }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
