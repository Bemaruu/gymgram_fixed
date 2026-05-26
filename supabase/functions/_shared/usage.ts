// usage.ts — tope duro de costo IA por usuario/mes (safety net).
//
// Registra cada invocación en ai_usage_events (vía service role) y lanza
// UsageCapError si el usuario superó el cap del mes calendario. No reemplaza a
// las cuotas finas (cambios anuales, 10 msg/día de chat): es una red de
// seguridad contra abuso/scripts que dispararían costo de OpenAI sin control.

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Cap global mensual de TODAS las llamadas IA por usuario. Generoso: un Premium
// intensivo (≈310 chat + 60 post-entreno + 4 check-ins + algunas generaciones)
// ronda 380/mes, así que 800 nunca afecta a un usuario legítimo y corta el
// abuso a tiempo.
export const GLOBAL_MONTHLY_CAP = 800;

export class UsageCapError extends Error {
  constructor(public used: number, public cap: number) {
    super(`Monthly AI usage cap reached (${used}/${cap})`);
    this.name = 'UsageCapError';
  }
}

/**
 * Verifica el cap mensual y registra el evento. Llamar antes de pegarle a OpenAI.
 * Lanza UsageCapError si ya se alcanzó el cap (responder 429 en el handler).
 */
export async function enforceMonthlyCap(
  supabase: SupabaseClient,
  userId: string,
  fn: string,
  cap: number = GLOBAL_MONTHLY_CAP,
): Promise<void> {
  const start = new Date();
  start.setUTCDate(1);
  start.setUTCHours(0, 0, 0, 0);

  const { count } = await supabase
    .from('ai_usage_events')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .gte('created_at', start.toISOString());

  const used = count ?? 0;
  if (used >= cap) throw new UsageCapError(used, cap);

  await supabase.from('ai_usage_events').insert({ user_id: userId, fn });
}
