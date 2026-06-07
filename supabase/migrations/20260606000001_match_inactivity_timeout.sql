-- Match 1v1 — inactividad por turno.
-- Si el jugador del current_turn no envía su marca en 7 minutos,
-- el rival puede reclamar victoria por inactividad (= forfeit del inactivo).
-- El timestamp del turno se auto-actualiza via trigger en cualquier UPDATE
-- que cambie current_turn o current_round (y en el INSERT inicial).

-- 1. Columna turn_started_at
alter table public.matches
  add column if not exists turn_started_at timestamptz not null default now();

-- Backfill defensivo para partidas activas que existieran sin el campo.
update public.matches
  set turn_started_at = coalesce(turn_started_at, now())
  where turn_started_at is null;

-- 2. Trigger que mantiene turn_started_at sincronizado con cada cambio de turno/ronda
create or replace function public._match_set_turn_started_at()
returns trigger language plpgsql as $$
begin
  if TG_OP = 'INSERT' then
    new.turn_started_at := now();
  elsif (old.current_turn is distinct from new.current_turn)
     or (old.current_round is distinct from new.current_round) then
    new.turn_started_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists match_set_turn_started_at on public.matches;
create trigger match_set_turn_started_at
  before insert or update on public.matches
  for each row execute function public._match_set_turn_started_at();

-- 3. RPC: reclamar victoria por inactividad
-- Solo el rival del jugador inactivo puede reclamarla, y solo si pasaron
-- al menos 420s (7 min) desde el inicio del turno actual.
-- Retorna true si el match cambió a 'abandoned' efectivamente.
create or replace function public.timeout_match(p_match_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_m matches%rowtype;
  v_inactive_uid uuid;
  v_winner_uid uuid;
  v_tier_a text; v_tier_b text;
  v_idx_a int; v_idx_b int;
  v_d_a int; v_d_b int;
  v_timeout_secs constant int := 420;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  select * into v_m from matches where id = p_match_id for update;
  if not found then raise exception 'match not found'; end if;
  if v_m.status <> 'active' then return false; end if;
  if v_uid <> v_m.player_a and v_uid <> v_m.player_b then
    raise exception 'not a participant';
  end if;
  if v_m.turn_started_at is null then return false; end if;
  if (now() - v_m.turn_started_at) < make_interval(secs => v_timeout_secs) then
    return false;
  end if;

  v_inactive_uid := case when v_m.current_turn = 'a' then v_m.player_a else v_m.player_b end;
  v_winner_uid := case when v_inactive_uid = v_m.player_a then v_m.player_b else v_m.player_a end;

  -- El inactivo no puede autoaplicarse el timeout (debe seguir compitiendo o usar forfeit).
  if v_uid = v_inactive_uid then return false; end if;

  select current_tier into v_tier_a from user_ranked_profile where user_id = v_m.player_a;
  select current_tier into v_tier_b from user_ranked_profile where user_id = v_m.player_b;
  v_idx_a := _match_tier_index(coalesce(v_tier_a, 'hierro'));
  v_idx_b := _match_tier_index(coalesce(v_tier_b, 'hierro'));

  if v_winner_uid = v_m.player_a then
    v_d_a := _match_rp_delta(v_idx_a, v_idx_b, true);
    v_d_b := _match_rp_delta(v_idx_b, v_idx_a, false);
  else
    v_d_a := _match_rp_delta(v_idx_a, v_idx_b, false);
    v_d_b := _match_rp_delta(v_idx_b, v_idx_a, true);
  end if;

  update matches set
      status = 'abandoned', winner_id = v_winner_uid,
      rp_delta_a = v_d_a, rp_delta_b = v_d_b, finished_at = now()
    where id = p_match_id;

  perform _match_apply_rp(v_m.player_a, v_d_a);
  perform _match_apply_rp(v_m.player_b, v_d_b);
  return true;
end;
$$;

grant execute on function public.timeout_match(uuid) to authenticated;
