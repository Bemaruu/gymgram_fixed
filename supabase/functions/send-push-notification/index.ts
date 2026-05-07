import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// TODO: Before deploying, set these secrets in Supabase Dashboard →
// Project Settings → Edge Functions → Secrets:
//   FCM_PROJECT_ID   — your Firebase project ID (e.g. "gymgram-6e226")
//   FCM_SERVICE_ACCOUNT_JSON — full JSON string of the service account key
//     downloaded from: Firebase Console → Project Settings →
//     Service accounts → Generate new private key
//
// The FCM HTTP v1 API requires a short-lived OAuth2 access token derived
// from that service account. The helper below fetches it at runtime.

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID') ?? 'gymgram-6e226';
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');

async function getFcmAccessToken(): Promise<string> {
  if (!FCM_SERVICE_ACCOUNT_JSON) {
    throw new Error('FCM_SERVICE_ACCOUNT_JSON secret is not set. See TODO in index.ts.');
  }
  const serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);

  // Build a signed JWT for the Google OAuth2 token endpoint
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const signingInput = `${encode(header)}.${encode(payload)}`;

  // Import the private key from the service account
  const pemKey = serviceAccount.private_key as string;
  const keyBody = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binaryKey = Uint8Array.from(atob(keyBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${signingInput}.${signatureB64}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const err = await tokenRes.text();
    throw new Error(`Failed to get FCM access token: ${err}`);
  }

  const { access_token } = await tokenRes.json();
  return access_token as string;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let body: { user_id: string; title: string; body: string };
  try {
    body = await req.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  const { user_id, title, body: msgBody } = body;
  if (!user_id || !title || !msgBody) {
    return new Response('Missing user_id, title or body', { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Fetch the FCM token for this user
  const { data: profile, error } = await supabase
    .from('profiles')
    .select('fcm_token')
    .eq('id', user_id)
    .single();

  if (error || !profile?.fcm_token) {
    return new Response('No FCM token for user', { status: 404 });
  }

  let accessToken: string;
  try {
    accessToken = await getFcmAccessToken();
  } catch (e) {
    return new Response(String(e), { status: 500 });
  }

  const fcmRes = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: profile.fcm_token,
          notification: { title, body: msgBody },
        },
      }),
    },
  );

  if (!fcmRes.ok) {
    const err = await fcmRes.text();
    return new Response(`FCM error: ${err}`, { status: 502 });
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
