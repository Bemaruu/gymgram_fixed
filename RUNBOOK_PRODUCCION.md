# Runbook — 3 pasos finales para 10/10 en producción

Todo el trabajo de código, base de datos y edge functions está **completo, desplegado y
verificado** (flutter analyze 0, tests +23, advisors 0 ERROR, RLS optimizado, 5
funciones IA ACTIVE). Quedan **3 acciones que solo tú puedes hacer** porque requieren
credenciales / hardware / billing que un agente no posee. Aquí están exactas.

---

## 1. Activar Leaked Password Protection (~1 min) — ⏸️ DIFERIDO (requiere plan Pro)

> Estado (2026-05-24): el dueño lo deja pendiente hasta pagar Supabase Pro.
> Está bajo **Authentication → Providers → Email**, sección Password. El toggle
> solo aparece con plan Pro. Mientras tanto, en esa misma pantalla SÍ se puede
> (plan Free) subir min length a 8+ y exigir mayúsculas/minúsculas/dígitos/símbolos.


Bloquea contraseñas filtradas (HaveIBeenPwned). No hay API en el MCP para esto.

1. Entra a https://supabase.com/dashboard/project/qnrpyaoyzecjbryejccm/auth/providers
2. Sección **Auth → Policies / Password** (o **Authentication → Settings**).
3. Activa **"Leaked password protection"** (toggle).
4. Si pide plan Pro: **Settings → Billing → Upgrade**. (Nota: en planes recientes
   suele estar disponible sin Pro; prueba primero el toggle.)
5. Verifica: el advisor de seguridad dejará de mostrar
   `auth_leaked_password_protection`.

---

## 2. QA en dispositivo real (~30 min) — ✅ HECHO (verificado por el dueño, 2026-05-24)

El backend nuevo ya está verificado a nivel DB; falta validar la UI en un teléfono.

```bash
flutter pub get
flutter run --release \
  --dart-define-from-file=dart_defines.json \
  --dart-define=SUPABASE_URL=https://qnrpyaoyzecjbryejccm.supabase.co
```

Checklist de los flujos nuevos:
- [ ] **Ajustes → Comunidad → Invita amigos**: ver tu código, copiar, compartir,
      contador. En una 2ª cuenta nueva: canjear el código → "¡Código canjeado!".
- [ ] **Buscar** (sin escribir): aparece "Sugerencias para ti" con botón Seguir.
- [ ] Plan de nutrición se genera y registra comidas (anillo de macros).
- [ ] Rutina del día, completar ejercicios, registrar peso (ranked).
- [ ] Premium: chat con el coach IA responde; tras 800 llamadas/mes → 429
      "Monthly AI limit reached" (tope nuevo).

---

## 3. iOS + RevenueCat en tiendas (varias horas) — ⏸️ DIFERIDO (requiere cuentas pagadas)

> Estado (2026-05-24): pendiente hasta tener Apple Developer ($99/año) y Google
> Play Console ($25). Retomar cuando estén las cuentas.


Requiere tu **Apple Developer** ($99/año) y **Google Play Console** ($25).

### iOS
1. Corregir Bundle ID en Xcode (`Runner → Signing & Capabilities`) al definitivo.
2. App Check: registrar el bundle con **DeviceCheck** en Firebase Console.
3. Certificados/perfiles de aprovisionamiento en developer.apple.com.
4. Crear la app en **App Store Connect**.

### RevenueCat (pagos)
1. Crear productos IAP en App Store Connect y Google Play Console.
2. En RevenueCat: vincular ambas tiendas, crear entitlements `plus` / `premium`.
3. Configurar el webhook → Edge Function `revenuecat-webhook` (ya desplegada).
4. Probar compras en sandbox (Apple) y testing track (Google).

Ver memoria del proyecto: `project_ios_pendientes`, `project_pagos_revenuecat`.

---

## Estado verificable hoy (sin tu intervención)
| Check | Resultado |
|---|---|
| `flutter analyze` | 0 issues |
| `flutter test` | +23 passed |
| Supabase security advisors | 0 ERROR |
| `auth_rls_initplan` | 0 (140 optimizadas) |
| FKs sin índice | 0 |
| Edge functions IA (tope de costo) | 5/5 ACTIVE, 0 errores en logs |
| Referidos (backend) | verificado en DB (códigos únicos, RPCs, índice) |
