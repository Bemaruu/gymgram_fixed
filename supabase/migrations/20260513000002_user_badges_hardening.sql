-- Protege user_badges contra falsificacion de progreso desde el cliente.
-- Antes: authenticated podia hacer INSERT/UPDATE con cualquier valor (progress, earned_at).
-- Ahora: solo RPCs SECURITY DEFINER pueden insertar/actualizar progreso.
--        El cliente solo puede modificar is_featured y featured_order (vitrina).

DROP POLICY IF EXISTS "select_all"  ON public.user_badges;
DROP POLICY IF EXISTS "insert_own"  ON public.user_badges;
DROP POLICY IF EXISTS "update_own"  ON public.user_badges;
DROP POLICY IF EXISTS "delete_own"  ON public.user_badges;

-- SELECT: cualquier autenticado puede ver medallas (feed social)
CREATE POLICY "user_badges: select authenticated"
  ON public.user_badges FOR SELECT TO authenticated USING (true);

-- Revocar acceso directo de escritura
REVOKE INSERT, DELETE ON public.user_badges FROM authenticated;

-- UPDATE solo para las columnas de vitrina (is_featured, featured_order)
REVOKE UPDATE ON public.user_badges FROM authenticated;
GRANT UPDATE (is_featured, featured_order) ON public.user_badges TO authenticated;

CREATE POLICY "user_badges: update featured own"
  ON public.user_badges FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);

-- ── RPC: otorgar medalla (reemplaza awardBadge del cliente) ───────────────────
CREATE OR REPLACE FUNCTION public.award_badge(p_user_id uuid, p_badge_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF auth.uid() <> p_user_id THEN RAISE EXCEPTION 'Forbidden'; END IF;

  INSERT INTO public.user_badges (user_id, badge_id, earned_at, progress)
  VALUES (p_user_id, p_badge_id, now(), 1.0)
  ON CONFLICT (user_id, badge_id) DO NOTHING;
END;
$$;
GRANT EXECUTE ON FUNCTION public.award_badge(uuid, text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.award_badge(uuid, text) FROM anon, public;

-- ── RPC: actualizar progreso parcial ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_badge_progress(
  p_user_id uuid,
  p_badge_id text,
  p_progress float8
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF auth.uid() <> p_user_id THEN RAISE EXCEPTION 'Forbidden'; END IF;
  IF p_progress < 0 OR p_progress >= 1 THEN RAISE EXCEPTION 'Invalid progress'; END IF;

  INSERT INTO public.user_badges (user_id, badge_id, progress, earned_at)
  VALUES (p_user_id, p_badge_id, p_progress, now())
  ON CONFLICT (user_id, badge_id) DO UPDATE
    SET progress = EXCLUDED.progress;
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_badge_progress(uuid, text, float8) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.update_badge_progress(uuid, text, float8) FROM anon, public;
