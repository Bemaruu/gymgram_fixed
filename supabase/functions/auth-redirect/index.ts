// Intermediate redirect page for GymGram password reset.
// iOS Safari bloquea custom schemes en redirects automaticos. Esta pagina
// muestra un boton para que el usuario tappee y dispare el scheme.
// Android: intent:// URL targets package com.gymgram.app to bypass Chrome's ERR_UNKNOWN_URL_SCHEME.
// iOS: custom scheme com.gymgram.fit:// (bundle distinto al Android).
Deno.serve((req) => {
  const url = new URL(req.url);
  // Supabase puede usar dos flujos:
  //   PKCE (default actual): ?code=AUTH_CODE  -> la app llama exchangeCodeForSession
  //   Legacy:                ?token_hash=...&type=recovery
  // Forward TODOS los params al deep link para que la app maneje cualquiera.
  const code = url.searchParams.get('code') ?? '';
  const tokenHash = url.searchParams.get('token_hash') ?? '';
  const type = url.searchParams.get('type') ?? 'recovery';

  const ua = req.headers.get('user-agent') ?? '';
  const isIOS = /iPhone|iPad|iPod/i.test(ua);

  // iOS scheme = com.gymgram.fit, Android scheme/package = com.gymgram.app
  const iosScheme = 'com.gymgram.fit';
  const androidScheme = 'com.gymgram.app';
  const androidPackage = 'com.gymgram.app';

  // Construir query preservando los params relevantes.
  const params: string[] = [];
  if (code) params.push(`code=${encodeURIComponent(code)}`);
  if (tokenHash) params.push(`token_hash=${encodeURIComponent(tokenHash)}`);
  if (type) params.push(`type=${encodeURIComponent(type)}`);
  const query = params.join('&');

  // iOS: deep link al custom scheme con los params para que la app exchange.
  const iosUrl = query
    ? `${iosScheme}://password-reset?${query}`
    : `${iosScheme}://password-reset`;

  // Android: intent URL con package + fallback.
  const intentHost = `password-reset${query ? '?' + query : ''}`;
  const fallbackEncoded = encodeURIComponent('https://qnrpyaoyzecjbryejccm.supabase.co/functions/v1/auth-redirect?not_installed=1');
  const intentUrl = `intent://${intentHost}#Intent;scheme=${androidScheme};package=${androidPackage};S.browser_fallback_url=${fallbackEncoded};end`;

  const openUrl = isIOS ? iosUrl : intentUrl;

  // If ?not_installed=1 → app truly not installed, show message
  if (url.searchParams.get('not_installed')) {
    return new Response(`<!DOCTYPE html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>GymGram</title><style>body{font-family:sans-serif;display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;background:#111827;color:#f9fafb;padding:24px;text-align:center}.logo{font-size:1.8rem;font-weight:800;color:#ff6b35;margin-bottom:16px}p{color:#9ca3af}</style></head><body><div class="logo">GymGram</div><p>Para restablecer tu contraseña necesitas tener GymGram instalada en tu dispositivo.</p></body></html>`,
      { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
  }

  const html = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>GymGram — Restablecer contraseña</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
         min-height:100vh;display:flex;flex-direction:column;align-items:center;
         justify-content:center;background:#111827;color:#f9fafb;padding:24px;text-align:center}
    .logo{font-size:1.8rem;font-weight:800;color:#ff6b35;letter-spacing:-.5px;margin-bottom:8px}
    .sub{font-size:.9rem;color:#9ca3af;margin-bottom:40px}
    .btn{display:inline-block;padding:16px 36px;background:#ff6b35;color:#fff;
         font-size:1rem;font-weight:700;border-radius:14px;text-decoration:none;
         box-shadow:0 4px 20px rgba(255,107,53,.4)}
    .btn:active{opacity:.85}
    .note{margin-top:20px;font-size:.78rem;color:#6b7280}
  </style>
</head>
<body>
  <div class="logo">GymGram</div>
  <div class="sub">Restablecer contraseña</div>
  <a class="btn" href="${openUrl}">Abrir GymGram</a>
  <p class="note">Toca el botón para continuar en la app.</p>
</body>
</html>`;

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
});
