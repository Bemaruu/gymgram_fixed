-- Dedup de workout_logs duplicados por (user_id, logged_at) + indice unico
-- para prevenir que el patron check-then-insert no atomico vuelva a duplicar.
--
-- Origen del bug (2026-06-15): _ensureWorkoutLogId disparaba inserts
-- concurrentes con taps rapidos. logWorkoutExecution hacia SELECT-entonces-
-- INSERT sin atomicidad y sin constraint unico -> varias filas del mismo dia.
-- Esos duplicados rompian maybeSingle() (lanza con >1 fila) y bloqueaban el
-- marcado de ejercicios.

BEGIN;

-- 1) Mapa de duplicados: por cada (user_id, logged_at) se conserva la fila con
--    mas set_logs asociados; desempate determinista por id.
CREATE TEMP TABLE _wl_dedup ON COMMIT DROP AS
WITH ranked AS (
  SELECT
    wl.id,
    wl.user_id,
    wl.logged_at,
    row_number() OVER (
      PARTITION BY wl.user_id, wl.logged_at
      ORDER BY
        (SELECT count(*) FROM set_logs sl WHERE sl.workout_log_id = wl.id) DESC,
        wl.id ASC
    ) AS rn
  FROM workout_logs wl
)
SELECT
  r.id  AS dup_id,
  r.rn,
  first_value(r.id) OVER (
    PARTITION BY r.user_id, r.logged_at ORDER BY r.rn
  ) AS keep_id
FROM ranked r;

-- 2) Reasignar al canonical cualquier set_logs colgando de un duplicado
--    (normalmente 0 filas: los sets ya apuntaban al log devuelto).
UPDATE set_logs sl
SET workout_log_id = d.keep_id
FROM _wl_dedup d
WHERE sl.workout_log_id = d.dup_id
  AND d.rn > 1;

-- 3) Borrar las filas duplicadas (rn > 1).
DELETE FROM workout_logs wl
USING _wl_dedup d
WHERE wl.id = d.dup_id
  AND d.rn > 1;

-- 4) Indice unico: a partir de ahora la BD garantiza 1 log por usuario/dia.
--    Un segundo INSERT concurrente fallara en vez de duplicar.
CREATE UNIQUE INDEX IF NOT EXISTS workout_logs_user_day_uidx
  ON workout_logs (user_id, logged_at);

COMMIT;
