-- ============================================================
-- Coaching notifications (acompañamiento por estilo)
-- Notificaciones de ánimo/motivación + nudges de inactividad
-- (no entrena / no registra comida / no se conecta) moduladas por
-- coaching_style del onboarding:
--   gentle  -> poco acompañamiento (tono suave, baja frecuencia)
--   balanced-> medio
--   strict  -> máximo (mañana + noche + nudges)
--   no_notifications -> nada
--
-- Arquitectura:
--   1) profiles.tz_offset_minutes: offset local del usuario (lo guarda la app)
--   2) notification_templates: pool de frases por categoría y tono
--   3) notification_dispatch_log: anti-repetición + tope diario por usuario
--   4) RPC coaching_notification_candidates(): 1 fila por usuario elegible
--      con señales de actividad ya calculadas (para el edge function)
--   5) pg_cron horario -> edge function `coaching-notifications`
-- Idempotente. Aditivo. No destruye datos.
-- ============================================================

-- 1) Offset de zona horaria por usuario (minutos respecto a UTC).
--    Lo escribe la app en cada apertura (capta DST). NULL => asume Chile (-180/-240).
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS tz_offset_minutes int;

-- ============================================================
-- 2) notification_templates
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_templates (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category   text NOT NULL CHECK (category IN
               ('morning_motivation','evening_motivation','no_workout',
                'no_food_log','inactive_app','generic_motivation')),
  tone       text NOT NULL DEFAULT 'any' CHECK (tone IN
               ('gentle','balanced','strict','any')),
  title      text NOT NULL,
  body       text NOT NULL,
  active     boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notif_templates_pick
  ON public.notification_templates(category, tone) WHERE active;

ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;
-- Sin políticas: solo service_role (edge function) lee. Clientes no necesitan acceso.

-- ============================================================
-- 3) notification_dispatch_log (anti-spam / dedupe)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notification_dispatch_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category    text NOT NULL,
  template_id uuid REFERENCES public.notification_templates(id) ON DELETE SET NULL,
  slot        text,
  sent_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notif_dispatch_user_time
  ON public.notification_dispatch_log(user_id, sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_dispatch_user_cat_time
  ON public.notification_dispatch_log(user_id, category, sent_at DESC);

ALTER TABLE public.notification_dispatch_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dispatch_log: select own" ON public.notification_dispatch_log;
CREATE POLICY "dispatch_log: select own"
  ON public.notification_dispatch_log FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
-- INSERT solo via service_role (sin política de insert).

-- ============================================================
-- 4) RPC: candidatos con señales de actividad ya resueltas
-- ============================================================
CREATE OR REPLACE FUNCTION public.coaching_notification_candidates()
RETURNS TABLE (
  user_id            uuid,
  coaching_style     text,
  tz_offset_minutes  int,
  last_workout       date,
  last_food          date,
  last_open          timestamptz,
  sent_24h           int,
  last_morning       timestamptz,
  last_evening       timestamptz,
  last_no_workout    timestamptz,
  last_no_food       timestamptz,
  last_inactive_app  timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    o.user_id,
    o.coaching_style,
    COALESCE(p.tz_offset_minutes, -180) AS tz_offset_minutes,
    w.last_workout,
    f.last_food,
    dt.updated_at AS last_open,
    COALESCE(dl.sent_24h, 0)::int AS sent_24h,
    dl.last_morning,
    dl.last_evening,
    dl.last_no_workout,
    dl.last_no_food,
    dl.last_inactive_app
  FROM public.user_onboarding_data o
  JOIN public.device_tokens dt ON dt.user_id = o.user_id
  JOIN public.profiles p       ON p.id = o.user_id
  LEFT JOIN LATERAL (
    SELECT max(logged_at) AS last_workout
    FROM public.workout_logs WHERE user_id = o.user_id
  ) w ON true
  LEFT JOIN LATERAL (
    SELECT max(log_date) AS last_food
    FROM public.food_logs WHERE user_id = o.user_id
  ) f ON true
  LEFT JOIN LATERAL (
    SELECT
      count(*) FILTER (WHERE sent_at > now() - interval '24 hours')          AS sent_24h,
      max(sent_at) FILTER (WHERE category = 'morning_motivation')            AS last_morning,
      max(sent_at) FILTER (WHERE category = 'evening_motivation')            AS last_evening,
      max(sent_at) FILTER (WHERE category = 'no_workout')                    AS last_no_workout,
      max(sent_at) FILTER (WHERE category = 'no_food_log')                   AS last_no_food,
      max(sent_at) FILTER (WHERE category = 'inactive_app')                  AS last_inactive_app
    FROM public.notification_dispatch_log
    WHERE user_id = o.user_id
  ) dl ON true
  WHERE o.coaching_style IN ('gentle','balanced','strict')
    AND COALESCE(o.notifications_enabled, true) = true;
$$;

REVOKE ALL ON FUNCTION public.coaching_notification_candidates() FROM public;
-- Solo service_role la ejecuta (desde el edge function).

-- ============================================================
-- 5) Seed de frases (idempotente: limpia y recarga)
-- ============================================================
DELETE FROM public.notification_templates;

INSERT INTO public.notification_templates (category, tone, title, body) VALUES
-- ── morning_motivation ─────────────────────────────────────
('morning_motivation','gentle','Buenos días ☀️','Hoy es un buen día para moverte un poquito. A tu ritmo, sin presión. 💙'),
('morning_motivation','gentle','Un nuevo día 🌱','Cada pequeño paso cuenta. Estás aquí, y eso ya es avanzar.'),
('morning_motivation','gentle','Hola 👋','Respira, sonríe y regálate un momento para ti hoy.'),
('morning_motivation','gentle','Buenos días ☕','No tiene que ser perfecto, solo tiene que empezar. Tú puedes.'),
('morning_motivation','gentle','Buen día 🌷','Hoy cuida de ti. Tu cuerpo y tu mente lo agradecerán.'),
('morning_motivation','balanced','¡A darlo todo hoy! 🔥','Empieza el día con energía. Tu próxima sesión te espera.'),
('morning_motivation','balanced','Nuevo día, nueva oportunidad 💥','Define tu meta de hoy y ve por ella. ¡Vamos!'),
('morning_motivation','balanced','Buenos días, crack 😎','La constancia construye resultados. Hoy suma un día más.'),
('morning_motivation','balanced','Despierta y brilla ✨','Tu cuerpo agradece cada entrenamiento. Haz que hoy cuente.'),
('morning_motivation','balanced','¡Arriba! 🌅','Un día más para acercarte a tu meta. Aprovéchalo.'),
('morning_motivation','strict','Arriba. Sin excusas. 💪','Los resultados no llegan solos. Hoy te toca a ti. Muévete.'),
('morning_motivation','strict','Es hora ⏰','Nadie va a entrenar por ti. Levántate y demuéstrate de qué estás hecho.'),
('morning_motivation','strict','Despierta, campeón 🥇','El que quiere, puede. Hoy no se negocia: a entrenar.'),
('morning_motivation','strict','Día de trabajo 🔨','La disciplina vence a la motivación. Cumple contigo mismo.'),
('morning_motivation','strict','De pie 🦁','Mientras descansas, alguien entrena. Hoy no te quedes atrás.'),
('morning_motivation','any','Buenos días 🌞','Hoy es tuyo. Hazlo contar.'),
-- ── evening_motivation ─────────────────────────────────────
('evening_motivation','strict','Cierra fuerte el día 🌙','¿Cumpliste contigo hoy? Mañana subimos la vara.'),
('evening_motivation','strict','Buen trabajo 💤','El músculo crece en la recuperación. Descansa y mañana, más.'),
('evening_motivation','strict','Antes de dormir 🌌','Lo que hiciste hoy define tu mañana. Orgullo o excusas: tú eliges.'),
('evening_motivation','strict','Balance del día 📊','Pregúntate si diste tu mejor versión. Mañana, otra oportunidad.'),
('evening_motivation','any','Buenas noches 🌙','Sea como haya sido tu día, mañana es una nueva oportunidad. Descansa.'),
('evening_motivation','any','Hora de descansar 😴','Dormir bien también es entrenar. Recarga energías.'),
('evening_motivation','gentle','Cierra el día tranquilo 🌜','Hiciste lo que pudiste, y eso basta. Descansa bien. 💙'),
-- ── no_workout ─────────────────────────────────────────────
('no_workout','gentle','Te extrañamos 💙','Hace unos días que no entrenas. Cuando quieras, aquí estamos.'),
('no_workout','gentle','¿Todo bien? 🌿','No has entrenado últimamente. Un ratito hoy puede sentar genial.'),
('no_workout','gentle','Sin prisa 🍃','Volver a entrenar siempre es posible. Da el primer paso hoy.'),
('no_workout','balanced','¿Retomamos? 💪','Llevas un par de días sin entrenar. Una sesión corta cuenta. ¡Vamos!'),
('no_workout','balanced','Tu rutina te espera 🏋️','No dejes que la racha se enfríe. Hoy es buen día para volver.'),
('no_workout','balanced','¡A moverse! 🏃','Tu cuerpo extraña el movimiento. Dale lo que necesita hoy.'),
('no_workout','strict','¿Y ese entrenamiento? 🤨','Ayer no entrenaste. Hoy no hay excusas. Tu yo del futuro lo agradecerá.'),
('no_workout','strict','La rutina no se hace sola 🔥','Llevas días parado. Levántate y cumple. La meta no espera.'),
('no_workout','strict','Sin entrenar otra vez ❌','Cada día que no entrenas, alguien más sí. Ponte las pilas.'),
('no_workout','strict','La excusa no suma 💢','Tu rutina lleva días esperando. Hoy se cumple. Sin peros.'),
-- ── no_food_log ────────────────────────────────────────────
('no_food_log','gentle','¿Qué comiste hoy? 🍎','No olvides registrar tus comidas. Te ayuda a conocerte mejor.'),
('no_food_log','gentle','Un recordatorio suave 🥑','Anotar lo que comes hoy puede ayudarte. Cuando puedas. 💙'),
('no_food_log','balanced','Registra tu comida 🥗','Llevas el día sin anotar. Mantener el registro marca la diferencia.'),
('no_food_log','balanced','¿Y tus comidas? 🍽️','No has registrado hoy. Anota lo que comes y toma el control.'),
('no_food_log','strict','No registraste nada 📋','Sin datos no hay progreso. Anota tus comidas de hoy. Ya.'),
('no_food_log','strict','Tu nutrición importa 🍗','Lo que no se mide, no se mejora. Registra lo que comiste.'),
-- ── inactive_app ───────────────────────────────────────────
('inactive_app','gentle','Te echamos de menos 💙','Hace días que no te vemos por aquí. Vuelve cuando quieras 😊'),
('inactive_app','gentle','¿Cómo estás? 🌷','Te extrañamos en GymGram. Tu espacio sigue aquí para ti.'),
('inactive_app','balanced','¡Cuánto tiempo! 👀','No te conectas hace varios días. Tu progreso te espera.'),
('inactive_app','balanced','Vuelve a GymGram 🏠','Han pasado unos días. Retoma tu camino, un paso a la vez.'),
('inactive_app','strict','¿Te rendiste? 😤','Días sin aparecer. Los campeones no abandonan. Vuelve y demuéstralo.'),
('inactive_app','strict','GymGram te espera 🔥','Llevas días desconectado. La meta sigue ahí. ¿Vas a ir por ella?'),
-- ── generic_motivation (reserva / variedad) ────────────────
('generic_motivation','any','Recuerda 💭','El progreso es progreso, por pequeño que sea. Sigue adelante.'),
('generic_motivation','any','Frase del día ✨','La disciplina es elegir entre lo que quieres ahora y lo que quieres más.'),
('generic_motivation','any','Motivación 🚀','No cuentes los días, haz que los días cuenten.'),
('generic_motivation','any','Ánimo 💪','El dolor es temporal, el orgullo es para siempre.'),
('generic_motivation','any','Tú puedes 🔥','Los límites están en tu mente, no en tu cuerpo.'),
('generic_motivation','any','Sigue 🌟','Un poco cada día te lleva lejos. No te detengas.');

-- ============================================================
-- 6) Cron horario -> edge function coaching-notifications
--    Corre cada hora; el edge function decide por hora LOCAL de cada usuario.
-- ============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    BEGIN
      PERFORM cron.unschedule('coaching-notifications-hourly');
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
    PERFORM cron.schedule(
      'coaching-notifications-hourly',
      '0 * * * *',
      $cron$
      SELECT net.http_post(
        url := (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'project_url')
               || '/functions/v1/coaching-notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' ||
            (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key')
        ),
        body := '{}'::jsonb
      );
      $cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron no disponible, se omite el schedule de coaching-notifications';
END $$;
