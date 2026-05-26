-- ============================================================
-- auth_rls_initplan — envuelve auth.uid()/auth.role() como (select ...) en TODAS
-- las políticas RLS de public. Postgres evalúa el subselect 1 vez por query en
-- vez de 1 vez por fila → gran ganancia a escala. Semánticamente idéntico
-- (recomendación oficial de Supabase). Idempotente: salta lo ya envuelto.
-- Transaccional: si una sola política falla, revierte todo. (2026-05-24)
-- ============================================================
DO $$
DECLARE
  r record;
  nq text;
  nc text;
  stmt text;
BEGIN
  FOR r IN
    SELECT schemaname, tablename, policyname, qual, with_check
    FROM pg_policies
    WHERE schemaname = 'public'
      AND ((qual ILIKE '%auth.uid()%'  AND qual NOT ILIKE '%select auth.uid()%')
        OR (with_check ILIKE '%auth.uid()%' AND with_check NOT ILIKE '%select auth.uid()%')
        OR (qual ILIKE '%auth.role()%' AND qual NOT ILIKE '%select auth.role()%')
        OR (with_check ILIKE '%auth.role()%' AND with_check NOT ILIKE '%select auth.role()%'))
  LOOP
    nq := r.qual;
    nc := r.with_check;

    IF nq IS NOT NULL THEN
      IF nq ILIKE '%auth.uid()%'  AND nq NOT ILIKE '%select auth.uid()%'  THEN nq := replace(nq, 'auth.uid()',  '(select auth.uid())');  END IF;
      IF nq ILIKE '%auth.role()%' AND nq NOT ILIKE '%select auth.role()%' THEN nq := replace(nq, 'auth.role()', '(select auth.role())'); END IF;
    END IF;
    IF nc IS NOT NULL THEN
      IF nc ILIKE '%auth.uid()%'  AND nc NOT ILIKE '%select auth.uid()%'  THEN nc := replace(nc, 'auth.uid()',  '(select auth.uid())');  END IF;
      IF nc ILIKE '%auth.role()%' AND nc NOT ILIKE '%select auth.role()%' THEN nc := replace(nc, 'auth.role()', '(select auth.role())'); END IF;
    END IF;

    stmt := format('ALTER POLICY %I ON %I.%I', r.policyname, r.schemaname, r.tablename);
    IF nq IS NOT NULL THEN stmt := stmt || ' USING (' || nq || ')'; END IF;
    IF nc IS NOT NULL THEN stmt := stmt || ' WITH CHECK (' || nc || ')'; END IF;
    EXECUTE stmt;
  END LOOP;
END $$;
