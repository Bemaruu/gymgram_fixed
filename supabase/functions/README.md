# Edge Functions (GymGram IA)

Funciones Deno desplegadas en Supabase Edge Runtime. Implementan la capa IA del
proyecto via RAG sobre `exercise_catalog` y `custom_foods`.

## Funciones

| Funcion                       | Modelo OpenAI    | Disparador            | Plan minimo |
| ----------------------------- | ---------------- | --------------------- | ----------- |
| `generate-routine`            | gpt-4o-mini      | On-demand (Flutter)   | Free        |
| `generate-nutrition-plan`     | gpt-4o-mini      | On-demand (Flutter)   | Free        |
| `ai-trainer-chat`             | gpt-4o-mini      | On-demand (Flutter)   | Premium     |
| `post-workout-ai-response`    | gpt-4o-mini      | On-demand tras feedback | Premium   |
| `weekly-checkin-response`     | gpt-4o-mini      | On-demand tras checkin  | Plus      |
| `generate-monthly-report`     | mini / gpt-4o    | pg_cron (dia 1, 03:00 UTC) + on-demand | Plus |

Las 6 funciones comparten utilidades en `_shared/`:
- `cors.ts` — headers + helpers de respuesta
- `supabase.ts` — `serviceClient()` y `getAuthedUser(req)`
- `openai.ts` — wrapper minimal de Chat Completions
- `fcm.ts` — FCM HTTP v1 (mismo flujo que `send-push-notification`)
- `prompts.ts` — persona del coach segun tono, contexto del perfil

## Configuracion de secrets (una sola vez)

```bash
# Desde la raiz del repo (requiere supabase CLI logueada al proyecto)
supabase secrets set OPENAI_API_KEY=sk-...

# FCM (ya estaba para send-push-notification; reusar mismos secrets)
supabase secrets set FCM_PROJECT_ID=gymgram-6e226
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat firebase-service-account.json)"
```

`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` ya estan disponibles por defecto en
edge functions, no hace falta setearlos.

## Configuracion de pg_cron (una sola vez)

La migracion `20260518000012_monthly_report_cron.sql` agenda la generacion
mensual, pero necesita dos GUCs configurados en la base:

```sql
ALTER DATABASE postgres SET app.supabase_url = 'https://<project-ref>.supabase.co';
ALTER DATABASE postgres SET app.service_role_key = '<service-role-key>';
```

Ejecutar una vez en el SQL Editor del dashboard de Supabase. Si la base se
reinicia, los GUCs persisten porque estan en `ALTER DATABASE`.

Tambien hay que habilitar las extensiones via dashboard (Database → Extensions):
- `pg_cron`
- `pg_net`

(La migracion intenta `create extension if not exists`, pero en Supabase Cloud
los superuser-only extensions a veces requieren toggle manual.)

## Deploy

```bash
# Desde supabase/
supabase functions deploy generate-routine
supabase functions deploy generate-nutrition-plan
supabase functions deploy ai-trainer-chat
supabase functions deploy post-workout-ai-response
supabase functions deploy weekly-checkin-response
supabase functions deploy generate-monthly-report

# O todas a la vez:
supabase functions deploy
```

## Test local (opcional)

```bash
supabase functions serve ai-trainer-chat --env-file ./.env.local

# Con .env.local conteniendo:
# OPENAI_API_KEY=sk-...
# SUPABASE_URL=...
# SUPABASE_SERVICE_ROLE_KEY=...
# SUPABASE_ANON_KEY=...
# FCM_PROJECT_ID=gymgram-6e226
# FCM_SERVICE_ACCOUNT_JSON={"type":"service_account",...}
```

Probar con un JWT real:
```bash
curl -X POST http://localhost:54321/functions/v1/ai-trainer-chat \
  -H "Authorization: Bearer <user-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"content":"Como bajo grasa abdominal?"}'
```

## RLS interactions

- `ai_trainer_messages` con `role='assistant'` esta bloqueado por RLS para usuarios.
  Solo service_role (edge function) puede insertarlos. El cliente Flutter NO debe
  intentar insertar respuestas; si la edge function falla, hay fallback local que
  intentara insertar el assistant pero ese path queda silenciosamente bloqueado
  por RLS (debugPrint en consola, no se muestra al usuario).
- `workout_feedback.ai_response` se actualiza solo desde service_role.
- `ai_monthly_summaries` solo lectura para usuarios; insert/update solo service_role.
- `subscription_tier` y `subscription_variant` protegidos por trigger
  `prevent_subscription_field_changes`.

## Modelo de costos (estimado, sin tope duro)

Con RAG corto, los outputs son pocos cientos de tokens. A precios actuales OpenAI:
- Free user: ~1 generate-routine + 1 generate-nutrition-plan al onboarding =
  ~$0.001 USD/usuario.
- Plus: + 4 weekly-checkins/mes + 1 monthly_report = ~$0.005/usuario/mes.
- Premium: + ~20 post-workout (mini) + chat libre (mini) + monthly report gpt-4o
  = ~$0.02-0.04/usuario/mes.

gpt-4o se usa en UN solo lugar: el informe mensual Premium (1x/mes, datos reales
de entrenamiento + nutricion + conversaciones post-entreno + check-ins). Todo lo
frecuente (post-entreno, chat, check-in) corre en gpt-4o-mini.

Tope hard: IMPLEMENTADO (2026-05-24). `_shared/usage.ts` registra cada
invocación en `ai_usage_events` y aplica un cap mensual global por usuario
(`GLOBAL_MONTHLY_CAP = 800`) en las 5 funciones on-demand (generate-routine,
generate-nutrition-plan, ai-trainer-chat, post-workout-ai-response,
weekly-checkin-response). Si se supera → 429 sin pegarle a OpenAI. Es una red de
seguridad contra abuso/scripts; las cuotas finas (10 msg/día, cambios anuales
4/8/12) siguen vigentes. **DESPLEGADO a producción el 2026-05-24** (las 5
funciones ACTIVE, tabla `ai_usage_events` migrada). Sin errores en logs.
