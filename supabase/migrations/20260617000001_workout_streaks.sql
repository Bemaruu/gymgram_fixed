-- ─────────────────────────────────────────────────────────────────────────────
-- Sistema de rachas de entrenamiento (consciente de días de descanso)
--
-- Regla central: la racha cuenta días de entrenamiento programados completados.
-- Un día de DESCANSO programado (un día sin rutina en available_days) NO suma a
-- la racha pero TAMPOCO la rompe. Solo se rompe si se salta un día de
-- entrenamiento programado sin registrar workout.
--
-- La racha se RECALCULA por completo desde workout_logs en cada actualización
-- (no hay estado incremental que pueda desincronizarse). workout_logs por
-- usuario está acotado, así que es barato y siempre consistente.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.user_streaks (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  current_streak    int  not null default 0,
  best_streak       int  not null default 0,
  last_workout_date date,
  freeze_tokens     int  not null default 0,   -- reservado para fase 2 (Protector de Racha)
  total_workouts    int  not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

alter table public.user_streaks enable row level security;

-- Lectura pública: la racha se muestra en perfiles de otros usuarios.
drop policy if exists "user_streaks_select_all" on public.user_streaks;
create policy "user_streaks_select_all"
  on public.user_streaks for select using (true);

-- Sin políticas de INSERT/UPDATE/DELETE: solo las RPC SECURITY DEFINER escriben.
revoke insert, update, delete on public.user_streaks from anon, authenticated;

-- ── Recálculo rest-aware ─────────────────────────────────────────────────────
-- Reconstruye la racha de un usuario desde workout_logs. SECURITY DEFINER e
-- interna (no expuesta a clientes): solo la invoca bump_workout_streak con el
-- uid autenticado.
create or replace function public._recompute_user_streak(
  p_uid uuid,
  p_today date
)
returns public.user_streaks
language plpgsql
security definer
set search_path = public
as $$
declare
  v_days      date[];            -- días distintos con workout, ascendente
  v_ad        text[];            -- available_days del onboarding
  v_train     boolean[] := array[true,true,true,true,true,true,true]; -- L..D (isodow 1..7)
  v_sched     boolean := false;  -- ¿tiene horario definido?
  v_spanish   text[] := array['lunes','martes','miercoles','jueves','viernes','sabado','domingo'];
  v_n         int;
  v_i         int;
  v_run       int;
  v_best      int := 0;
  v_current   int := 0;
  v_last      date;
  v_row       public.user_streaks;
  d           date;
  v_linked    boolean;
  v_alive     boolean;
begin
  -- Horario de entrenamiento (acepta índices '0'..'6' lunes-primero y legacy en español).
  select available_days into v_ad
    from public.user_onboarding_data
   where user_id = p_uid
   order by created_at desc
   limit 1;

  if v_ad is not null and array_length(v_ad, 1) is not null then
    v_sched := true;
    for v_i in 0..6 loop
      -- v_train es 1-indexado por isodow: índice 1 = lunes ... 7 = domingo.
      v_train[v_i + 1] := (v_i::text = any(v_ad)) or (v_spanish[v_i + 1] = any(v_ad));
    end loop;
  end if;
  -- Sin horario => se asume entrenamiento todos los días (cualquier falta rompe).

  -- Días con workout (distintos), ascendente, acotado.
  select array_agg(dd order by dd) into v_days
  from (
    select distinct logged_at as dd
    from public.workout_logs
    where user_id = p_uid
    order by logged_at
    limit 400
  ) s;

  v_n := coalesce(array_length(v_days, 1), 0);

  if v_n = 0 then
    -- Sin workouts: deja/crea fila en cero, conservando freeze_tokens.
    insert into public.user_streaks (user_id, current_streak, best_streak,
                                     last_workout_date, total_workouts, updated_at)
    values (p_uid, 0, 0, null, 0, now())
    on conflict (user_id) do update
      set current_streak = 0, best_streak = greatest(public.user_streaks.best_streak, 0),
          last_workout_date = null, total_workouts = 0, updated_at = now()
    returning * into v_row;
    return v_row;
  end if;

  v_last := v_days[v_n];

  -- ── best_streak: cadena máxima histórica rest-aware ──
  v_run := 1; v_best := 1;
  for v_i in 2..v_n loop
    -- ¿enlazadas v_days[v_i-1] (más antigua) y v_days[v_i] (más nueva)?
    -- Enlazadas si no hay día de entrenamiento saltado estrictamente entre ambas.
    v_linked := true;
    d := v_days[v_i - 1] + 1;
    while d < v_days[v_i] loop
      if (not v_sched or v_train[extract(isodow from d)::int]) and not (d = any(v_days)) then
        v_linked := false;
        exit;
      end if;
      d := d + 1;
    end loop;

    if v_linked then v_run := v_run + 1; else v_run := 1; end if;
    if v_run > v_best then v_best := v_run; end if;
  end loop;

  -- ── current_streak: cadena viva que termina en el último workout ──
  -- Viva = no se saltó ningún día de entrenamiento entre el último workout y hoy.
  v_alive := true;
  if v_last < p_today then
    d := v_last + 1;
    while d < p_today loop
      if (not v_sched or v_train[extract(isodow from d)::int]) and not (d = any(v_days)) then
        v_alive := false;
        exit;
      end if;
      d := d + 1;
    end loop;
  end if;

  if not v_alive then
    v_current := 0;
  else
    v_current := 1;
    v_i := v_n;
    while v_i > 1 loop
      v_linked := true;
      d := v_days[v_i - 1] + 1;
      while d < v_days[v_i] loop
        if (not v_sched or v_train[extract(isodow from d)::int]) and not (d = any(v_days)) then
          v_linked := false;
          exit;
        end if;
        d := d + 1;
      end loop;
      if v_linked then v_current := v_current + 1; v_i := v_i - 1; else exit; end if;
    end loop;
  end if;

  insert into public.user_streaks (user_id, current_streak, best_streak,
                                   last_workout_date, total_workouts, updated_at)
  values (p_uid, v_current, greatest(v_best, v_current), v_last, v_n, now())
  on conflict (user_id) do update
    set current_streak    = excluded.current_streak,
        best_streak       = greatest(public.user_streaks.best_streak, excluded.best_streak),
        last_workout_date = excluded.last_workout_date,
        total_workouts    = excluded.total_workouts,
        updated_at        = now()
  returning * into v_row;

  return v_row;
end;
$$;

-- Postgres concede EXECUTE a PUBLIC por defecto: hay que revocar de PUBLIC, no
-- solo de anon/authenticated. _recompute recibe uid como parámetro y es SECURITY
-- DEFINER, así que NO debe ser invocable vía REST por nadie (solo la llama
-- internamente bump_workout_streak con el uid autenticado).
revoke all on function public._recompute_user_streak(uuid, date) from public;

-- ── RPC pública: recalcula la racha del usuario autenticado ──────────────────
-- p_local_date = "hoy" en hora LOCAL del dispositivo (evita el bug de TZ del
-- servidor en UTC). Se llama tras registrar el workout del día.
create or replace function public.bump_workout_streak(
  p_local_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_today     date;
  v_old_best  int;
  v_row       public.user_streaks;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Autoridad: fecha local del cliente, acotada para evitar fechas futuras absurdas.
  v_today := least(coalesce(p_local_date, current_date), current_date + 1);

  select best_streak into v_old_best from public.user_streaks where user_id = v_uid;

  v_row := public._recompute_user_streak(v_uid, v_today);

  return jsonb_build_object(
    'current_streak',    v_row.current_streak,
    'best_streak',       v_row.best_streak,
    'last_workout_date', v_row.last_workout_date,
    'freeze_tokens',     v_row.freeze_tokens,
    'total_workouts',    v_row.total_workouts,
    'is_new_record',     (v_row.current_streak > 0
                          and v_row.current_streak >= v_row.best_streak
                          and v_row.current_streak > coalesce(v_old_best, 0))
  );
end;
$$;

revoke all on function public.bump_workout_streak(date) from public;
grant execute on function public.bump_workout_streak(date) to authenticated;

-- ── Backfill: inicializa rachas de usuarios con historial existente ──────────
do $$
declare r record;
begin
  for r in select distinct user_id from public.workout_logs loop
    perform public._recompute_user_streak(r.user_id, current_date);
  end loop;
end $$;
