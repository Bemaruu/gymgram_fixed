import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { serviceClient } from '../_shared/supabase.ts';

// ---------------------------------------------------------------------------
// Webhook de RevenueCat -> actualiza el tier de suscripcion en `profiles`.
//
// Antes de desplegar, configura el secreto en Supabase Dashboard ->
// Project Settings -> Edge Functions -> Secrets:
//   REVENUECAT_WEBHOOK_AUTH  — un token secreto que tu eliges. Debe coincidir
//     EXACTAMENTE con el header "Authorization" que pongas en RevenueCat
//     Dashboard -> Project -> Integrations -> Webhooks.
//
// El appUserID de RevenueCat == el user id de Supabase (lo fija el cliente en
// PurchaseService). Por eso event.app_user_id nos da directo el id del perfil.
//
// Convencion de entitlements en RevenueCat: "plus" y "premium".
// Convencion de product ids (fallback): que contengan "plus" o "premium".
// ---------------------------------------------------------------------------

const WEBHOOK_AUTH = Deno.env.get('REVENUECAT_WEBHOOK_AUTH');

type Tier = 'free' | 'plus' | 'premium';

interface RcEvent {
  type: string;
  app_user_id?: string;
  original_app_user_id?: string;
  product_id?: string;
  entitlement_ids?: string[];
  expiration_at_ms?: number;
  // Para PRODUCT_CHANGE: el producto al que cambia en la proxima renovacion.
  new_product_id?: string;
}

function tierFromEvent(ev: RcEvent): Tier | null {
  const ents = ev.entitlement_ids ?? [];
  if (ents.includes('premium')) return 'premium';
  if (ents.includes('plus')) return 'plus';
  const p = (ev.product_id ?? '').toLowerCase();
  if (p.includes('premium')) return 'premium';
  if (p.includes('plus')) return 'plus';
  return null;
}

function variantFromProduct(productId: string | undefined): string | null {
  const p = (productId ?? '').toLowerCase();
  if (p.includes('founder')) return 'founder';
  if (p.includes('launch')) return 'launch';
  return null;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  // Falla cerrado: si el secreto no esta configurado, la funcion no acepta nada.
  // Esto evita que alguien que descubra la URL pueda otorgarse un plan.
  if (!WEBHOOK_AUTH) {
    return new Response('Webhook not configured', { status: 503 });
  }
  const auth = req.headers.get('Authorization');
  if (auth !== WEBHOOK_AUTH) {
    return new Response('Unauthorized', { status: 401 });
  }

  let payload: { event?: RcEvent };
  try {
    payload = await req.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  const ev = payload.event;
  if (!ev) return new Response('No event', { status: 400 });

  // Eventos de prueba de RevenueCat: responder 200 sin tocar nada.
  if (ev.type === 'TEST') {
    return new Response(JSON.stringify({ ok: true, test: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const uid = ev.app_user_id ?? ev.original_app_user_id;
  if (!uid) return new Response('No app_user_id', { status: 400 });

  const supa = serviceClient();
  const expiresAt = ev.expiration_at_ms
    ? new Date(ev.expiration_at_ms).toISOString()
    : null;
  const tier = tierFromEvent(ev);
  const variant = variantFromProduct(ev.product_id);

  // Tipos que dan/mantienen acceso pagado: fijamos el tier y limpiamos cualquier
  // cambio agendado.
  const ACTIVE = new Set([
    'INITIAL_PURCHASE',
    'RENEWAL',
    'PRODUCT_CHANGE',
    'UNCANCELLATION',
    'SUBSCRIPTION_EXTENDED',
    'NON_RENEWING_PURCHASE',
  ]);

  let update: Record<string, unknown> | null = null;

  if (ACTIVE.has(ev.type) && tier) {
    update = {
      subscription_tier: tier,
      subscription_expires_at: expiresAt,
      subscription_period_end: expiresAt,
      pending_tier: null,
    };
    if (variant) update.subscription_variant = variant;
  } else if (ev.type === 'CANCELLATION') {
    // El usuario desactivo la renovacion automatica: conserva el plan hasta el
    // fin del periodo. Agendamos la baja a Free al vencer.
    update = {
      pending_tier: 'free',
      subscription_period_end: expiresAt,
    };
  } else if (ev.type === 'EXPIRATION') {
    // La suscripcion ya vencio de verdad: baja a Free.
    update = {
      subscription_tier: 'free',
      subscription_expires_at: expiresAt,
      pending_tier: null,
    };
  } else {
    // BILLING_ISSUE, TRANSFER, SUBSCRIPTION_PAUSED, etc.: no cambiamos el tier
    // (periodo de gracia / casos a manejar manualmente). Respondemos 200 para
    // que RevenueCat no reintente en bucle.
    return new Response(JSON.stringify({ ok: true, ignored: ev.type }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { error } = await supa.from('profiles').update(update).eq('id', uid);
  if (error) {
    console.error('revenuecat-webhook update error', error);
    return new Response(`DB error: ${error.message}`, { status: 500 });
  }

  return new Response(JSON.stringify({ ok: true, type: ev.type, tier }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
