-- Garantiza "un dia = una rutina personal activa" por usuario.
-- Antes no existia restriccion y el auto-guardado podia crear filas duplicadas
-- por (user_id, day_of_week), inflando el conteo de dias en el perfil.

-- 1) Limpieza idempotente: elimina rutinas personales activas duplicadas por
--    (user_id, day_of_week), conservando la de mas ejercicios (desempate: mas
--    reciente). En una DB nueva no hace nada. El FK routine_exercises ->
--    routines es ON DELETE CASCADE, asi que los ejercicios huerfanos se borran.
WITH ranked AS (
  SELECT r.id,
         row_number() OVER (
           PARTITION BY r.user_id, r.day_of_week
           ORDER BY (SELECT count(*) FROM public.routine_exercises re WHERE re.routine_id = r.id) DESC,
                    r.created_at DESC
         ) AS rn
  FROM public.routines r
  WHERE r.kind = 'personal' AND r.is_archived = false AND r.day_of_week IS NOT NULL
)
DELETE FROM public.routines
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- 2) Indice unico parcial: una sola rutina personal activa por usuario y dia.
CREATE UNIQUE INDEX IF NOT EXISTS routines_personal_active_day_unique
  ON public.routines(user_id, day_of_week)
  WHERE kind = 'personal' AND is_archived = false AND day_of_week IS NOT NULL;
