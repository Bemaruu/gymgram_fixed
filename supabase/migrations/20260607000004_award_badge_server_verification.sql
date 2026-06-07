-- ============================================================
-- HARDENING: award_badge con verificación de criterio en servidor
-- (auditoría 2026-06-07)
--
-- ANTES: award_badge confiaba en el cliente y otorgaba CUALQUIER medalla a
-- progress=1.0 con solo validar auth.uid()==p_user_id → un usuario podía
-- auto-otorgarse todas las medallas. Hueco de integridad/trampa.
--
-- AHORA: la RPC verifica el criterio real contra las tablas de datos antes de
-- otorgar. El cliente sigue llamándola igual (optimista) — solo que el servidor
-- es la fuente de verdad. Comportamiento:
--   - criterio cumplido        → otorga (upsert progress=1.0)
--   - criterio NO cumplido     → return silencioso (no otorga, sin error)
--   - medalla no auto-otorgable → return silencioso
--   - fallo de auth            → RAISE
--
-- Medallas con foto (renacido/conquistador/runner) NO pasan por aquí: las
-- otorga la edge function verify-medal-photo con service_role (upsert directo).
-- Medallas de evento/manual/no implementadas (full_mode, unido, precision_total,
-- control_total, obsidiana_mental, neon_vital) no tienen criterio auto-verificable
-- → se ignoran (nunca se otorgaban legítimamente por esta vía).
-- ============================================================

CREATE OR REPLACE FUNCTION public.award_badge(p_user_id uuid, p_badge_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ok     boolean := false;
  v_n      int;
  v_streak int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF auth.uid() <> p_user_id THEN RAISE EXCEPTION 'Forbidden'; END IF;

  -- Idempotente: si ya la tiene ganada, nada que hacer (evita recomputar en
  -- eventos de alta frecuencia como set_logged).
  IF EXISTS (
    SELECT 1 FROM public.user_badges
    WHERE user_id = p_user_id AND badge_id = p_badge_id AND progress >= 1.0
  ) THEN
    RETURN;
  END IF;

  -- ── Verificación de criterio (fuente de verdad en el servidor) ──
  CASE p_badge_id

    WHEN 'primer_paso' THEN
      v_ok := true;  -- cuenta creada == usuario autenticado

    WHEN 'beta_exclusiva' THEN
      v_ok := true;  -- participante de la beta

    WHEN 'perfil_completo' THEN
      SELECT (
        username     IS NOT NULL AND length(btrim(username)) > 0 AND
        full_name    IS NOT NULL AND length(btrim(full_name)) > 0 AND
        age          IS NOT NULL AND
        gender       IS NOT NULL AND length(btrim(gender)) > 0 AND
        weight       IS NOT NULL AND
        height       IS NOT NULL AND
        fitness_goal IS NOT NULL AND length(btrim(fitness_goal)) > 0
      ) INTO v_ok
      FROM public.profiles WHERE id = p_user_id;

    WHEN 'primera_rutina' THEN
      v_ok := EXISTS (SELECT 1 FROM public.workout_logs WHERE user_id = p_user_id);

    WHEN 'primera_publicacion' THEN
      v_ok := EXISTS (SELECT 1 FROM public.posts WHERE user_id = p_user_id);

    WHEN 'social_inicial' THEN
      SELECT count(*) INTO v_n FROM public.likes WHERE user_id = p_user_id;
      v_ok := v_n >= 5;

    WHEN 'evolucion_visible' THEN
      SELECT count(*) INTO v_n FROM public.weight_logs WHERE user_id = p_user_id;
      v_ok := v_n >= 5;

    WHEN 'enfocado' THEN
      SELECT count(DISTINCT log_date) INTO v_n FROM public.food_logs WHERE user_id = p_user_id;
      v_ok := v_n >= 5;

    WHEN 'rompe_limites' THEN
      v_ok := EXISTS (SELECT 1 FROM public.user_strength_records WHERE user_id = p_user_id);

    WHEN 'inspiracion' THEN
      SELECT coalesce(max(likes_count), 0) INTO v_n FROM public.posts WHERE user_id = p_user_id;
      v_ok := v_n >= 50;

    WHEN 'referente' THEN
      SELECT count(*) INTO v_n FROM public.follows WHERE following_id = p_user_id;
      v_ok := v_n >= 20;

    WHEN 'embajador' THEN
      SELECT count(*) INTO v_n FROM public.profiles WHERE referred_by = p_user_id;
      v_ok := v_n >= 3;

    WHEN 'disciplinado' THEN
      SELECT count(DISTINCT logged_at) INTO v_n FROM public.workout_logs WHERE user_id = p_user_id;
      v_ok := v_n >= 10;

    WHEN 'bestia' THEN
      SELECT count(DISTINCT logged_at) INTO v_n FROM public.workout_logs WHERE user_id = p_user_id;
      v_ok := v_n >= 50;

    WHEN 'maquina' THEN
      -- ~280 kcal estimadas por día entrenado (mismo cálculo que el cliente).
      SELECT count(DISTINCT logged_at) INTO v_n FROM public.workout_logs WHERE user_id = p_user_id;
      v_ok := (v_n * 280) >= 10000;

    WHEN 'siete_dias_activo', 'ritmo_constante', 'inquebrantable', 'cobalto_core', 'mente_y_cuerpo' THEN
      -- Racha máxima de días consecutivos entrenados (gaps & islands).
      WITH d AS (
        SELECT DISTINCT logged_at AS day FROM public.workout_logs WHERE user_id = p_user_id
      ), g AS (
        SELECT day, (day - (row_number() OVER (ORDER BY day))::int) AS grp FROM d
      ), s AS (
        SELECT count(*) AS cnt FROM g GROUP BY grp
      )
      SELECT coalesce(max(cnt), 0) INTO v_streak FROM s;
      v_ok := v_streak >= CASE p_badge_id
                WHEN 'siete_dias_activo' THEN 7
                WHEN 'ritmo_constante'   THEN 14
                WHEN 'inquebrantable'    THEN 30
                WHEN 'cobalto_core'      THEN 60
                WHEN 'mente_y_cuerpo'    THEN 90
              END;

    WHEN 'hidratado' THEN
      WITH d AS (
        SELECT DISTINCT target_date AS day FROM public.water_logs
        WHERE user_id = p_user_id AND glasses_count > 0
      ), g AS (
        SELECT day, (day - (row_number() OVER (ORDER BY day))::int) AS grp FROM d
      ), s AS (
        SELECT count(*) AS cnt FROM g GROUP BY grp
      )
      SELECT coalesce(max(cnt), 0) INTO v_streak FROM s;
      v_ok := v_streak >= 7;

    WHEN 'mas_fuerte' THEN
      -- 3 incrementos de peso en un mismo ejercicio (máx por día, cronológico).
      WITH daily AS (
        SELECT exercise_name, logged_at::date AS day, max(weight_kg) AS w
        FROM public.set_logs
        WHERE user_id = p_user_id AND weight_kg IS NOT NULL AND exercise_name IS NOT NULL
        GROUP BY exercise_name, logged_at::date
      ), seq AS (
        SELECT exercise_name, w,
               lag(w) OVER (PARTITION BY exercise_name ORDER BY day) AS prev_w
        FROM daily
      ), inc AS (
        SELECT exercise_name,
               count(*) FILTER (WHERE prev_w IS NOT NULL AND w > prev_w) AS increases
        FROM seq GROUP BY exercise_name
      )
      SELECT coalesce(max(increases), 0) INTO v_n FROM inc;
      v_ok := v_n >= 3;

    ELSE
      -- Medallas no auto-otorgables por esta vía (foto/evento/manual/no impl.).
      RETURN;
  END CASE;

  IF NOT coalesce(v_ok, false) THEN
    RETURN;  -- criterio no cumplido: no se otorga (silencioso).
  END IF;

  INSERT INTO public.user_badges (user_id, badge_id, earned_at, progress)
  VALUES (p_user_id, p_badge_id, now(), 1.0)
  ON CONFLICT (user_id, badge_id) DO UPDATE
    SET progress  = 1.0,
        earned_at = CASE
          WHEN public.user_badges.progress < 1.0 THEN now()
          ELSE public.user_badges.earned_at
        END;
END;
$$;
