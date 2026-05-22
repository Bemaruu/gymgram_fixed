// FCM HTTP v1 — sign a service-account JWT and POST a notification.
// Mirrors the logic in send-push-notification/index.ts but reusable.

const FCM_PROJECT_ID = Deno.env.get('FCM_PROJECT_ID') ?? 'gymgram-6e226';
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');

let cachedToken: { token: string; exp: number } | null = null;

async function getAccessToken(): Promise<string> {
  if (!FCM_SERVICE_ACCOUNT_JSON) {
    throw new Error('FCM_SERVICE_ACCOUNT_JSON not set');
  }
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp > now + 60) return cachedToken.token;

  const sa = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const signingInput = `${encode(header)}.${encode(payload)}`;
  const keyBody = (sa.private_key as string)
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
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${signingInput}.${sigB64}`;
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!tokenRes.ok) {
    throw new Error(`OAuth2 token error: ${await tokenRes.text()}`);
  }
  const data = await tokenRes.json();
  cachedToken = { token: data.access_token, exp: now + (data.expires_in ?? 3600) };
  return cachedToken.token;
}

export type FcmSendInput = {
  fcmToken: string;
  title: string;
  body: string;
  data?: Record<string, string>;
};

/** Sends one push notification via FCM HTTP v1. Returns true on success. */
export async function sendPush(input: FcmSendInput): Promise<boolean> {
  let accessToken: string;
  try {
    accessToken = await getAccessToken();
  } catch (e) {
    console.error('FCM token error:', e);
    return false;
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: input.fcmToken,
          notification: { title: input.title, body: input.body },
          data: input.data ?? {},
        },
      }),
    },
  );
  if (!res.ok) {
    console.error('FCM send error:', await res.text());
    return false;
  }
  return true;
}

/** Lookup the user's FCM token and send a push. No-op if not found. */
export async function pushToUser(
  supabase: {
    from: (t: string) => {
      select: (s: string) => {
        eq: (k: string, v: string) => {
          maybeSingle: () => Promise<{ data: { fcm_token: string } | null }>;
        };
      };
    };
  },
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> {
  try {
    const { data: row } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('user_id', userId)
      .maybeSingle();
    if (!row?.fcm_token) return;
    await sendPush({ fcmToken: row.fcm_token, title, body, data });
  } catch (e) {
    console.error('pushToUser error:', e);
  }
}
