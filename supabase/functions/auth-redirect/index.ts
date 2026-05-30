// Intermediate redirect page for GymGram password reset.
// Uses Android Intent URL format (intent://) which reliably opens a sideloaded APK
// by package name, bypassing Chrome's ERR_UNKNOWN_URL_SCHEME on custom schemes.
Deno.serve((req) => {
  const url = new URL(req.url);
  const tokenHash = url.searchParams.get('token_hash') ?? '';
  const type = url.searchParams.get('type') ?? 'recovery';

  // Custom URI scheme URL (fallback for non-Android / iOS future use)
  const customUrl = tokenHash
    ? `com.gymgram.app://password-reset?token_hash=${encodeURIComponent(tokenHash)}&type=${encodeURIComponent(type)}`
    : `com.gymgram.app://password-reset`;

  // Android Intent URL: explicitly targets package com.gymgram.app.
  // Chrome uses this to open the sideloaded APK even without Play Store.
  // Format: intent://HOST?QUERY#Intent;scheme=SCHEME;package=PKG;S.browser_fallback_url=URL;end
  const query = tokenHash
    ? `token_hash=${encodeURIComponent(tokenHash)}&type=${encodeURIComponent(type)}`
    : '';
  const intentHost = `password-reset${query ? '?' + query : ''}`;
  const fallbackEncoded = encodeURIComponent('https://qnrpyaoyzecjbryejccm.supabase.co/functions/v1/auth-redirect?not_installed=1');
  const intentUrl = `intent://${intentHost}#Intent;scheme=com.gymgram.app;package=com.gymgram.app;S.browser_fallback_url=${fallbackEncoded};end`;

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
  <a class="btn" href="${intentUrl}">Abrir GymGram</a>
  <p class="note">Toca el botón para continuar en la app.</p>
</body>
</html>`;

  return new Response(html, {
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
});
