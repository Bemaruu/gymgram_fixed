-- Match Mode 1v1 (duelo competitivo entre amigos).
-- Parte del modo Ranked (solo Plus/Premium, gating en cliente).
-- RP se canaliza por el pilar "challenge" para no romper recalculate_user_rank.

-- ---------------------------------------------------------------------------
-- 1. Flag de ejercicios elegibles para partida (clasicos/populares, medibles).
-- ---------------------------------------------------------------------------
alter table public.exercises
  add column if not exists is_match_eligible boolean not null default false;

update public.exercises set is_match_eligible = true where id in (
  'a1b2c3d4-0001-4001-8001-000000000001', -- Press de Banca
  'a1b2c3d4-0001-4001-8001-000000000002', -- Press Inclinado con Barra
  'a1b2c3d4-0001-4001-8001-000000000003', -- Press de Banca con Mancuernas
  'a1b2c3d4-0001-4001-8001-000000000010', -- Sentadilla con Barra
  'a1b2c3d4-0001-4001-8001-000000000011', -- Prensa de Piernas
  'a1b2c3d4-0001-4001-8001-000000000012', -- Peso Muerto
  'a1b2c3d4-0001-4001-8001-000000000013', -- Peso Muerto Rumano
  'a1b2c3d4-0001-4001-8001-000000000021', -- Remo con Barra
  'a1b2c3d4-0001-4001-8001-000000000022', -- Jalon al Pecho
  'a1b2c3d4-0001-4001-8001-000000000023', -- Remo Sentado en Polea
  'a1b2c3d4-0001-4001-8001-000000000030', -- Press Militar con Barra
  'a1b2c3d4-0001-4001-8001-000000000031', -- Press de Hombros con Mancuernas
  'a1b2c3d4-0001-4001-8001-000000000040', -- Curl de Biceps con Barra
  'a1b2c3d4-0001-4001-8001-000000000041', -- Curl de Biceps con Mancuernas
  'a1b2c3d4-0001-4001-8001-000000000043', -- Extension de Triceps en Polea
  'a1b2c3d4-0001-4001-8001-000000000050', -- Extension de Cuadriceps
  'a1b2c3d4-0001-4001-8001-000000000051'  -- Curl Femoral
);

-- ---------------------------------------------------------------------------
-- 2. Tablas
-- ---------------------------------------------------------------------------
create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  season_id uuid references public.ranked_seasons(id) on delete set null,
  player_a uuid not null references public.profiles(id) on delete cascade, -- retador
  player_b uuid not null references public.profiles(id) on delete cascade, -- retado
  status text not null default 'active' check (status in ('active','finished','abandoned')),
  current_round int not null default 1,
  current_turn text not null default 'a' check (current_turn in ('a','b')),
  wins_a int not null default 0,
  wins_b int not null default 0,
  winner_id uuid references public.profiles(id) on delete set null,
  rp_delta_a int,
  rp_delta_b int,
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.match_challenges (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references public.profiles(id) on delete cascade,
  challenged_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','cancelled')),
  match_id uuid references public.matches(id) on delete set null,
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint match_challenges_no_self check (challenger_id <> challenged_id)
);

create table if not exists public.match_rounds (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches(id) on delete cascade,
  round_number int not null,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  weight_a numeric, reps_a int, score_a numeric,
  weight_b numeric, reps_b int, score_b numeric,
  round_winner text check (round_winner in ('a','b','tie')),
  unique (match_id, round_number)
);

create index if not exists idx_match_challenges_challenged on public.match_challenges(challenged_id, status);
create index if not exists idx_match_challenges_challenger on public.match_challenges(challenger_id, status);
create index if not exists idx_matches_player_a on public.matches(player_a, status);
create index if not exists idx_matches_player_b on public.matches(player_b, status);
create index if not exists idx_match_rounds_match on public.match_rounds(match_id);

-- Payload completo en UPDATE para Realtime.
alter table public.matches replica identity full;
alter table public.match_rounds replica identity full;

-- ---------------------------------------------------------------------------
-- 3. Helpers internos
-- ---------------------------------------------------------------------------
create or replace function public._match_tier_index(p_tier text)
returns int language sql immutable as $$
  select case p_tier
    when 'hierro' then 0
    when 'bronce' then 1
    when 'plata' then 2
    when 'oro' then 3
    when 'platino' then 4
    when 'diamante' then 5
    when 'inmortal' then 6
    else 0 end;
$$;

-- RP en juego segun diferencia de tier (rival - propio).
create or replace function public._match_rp_delta(p_my_idx int, p_rival_idx int, p_won boolean)
returns int language sql immutable as $$
  select case
    when p_won then
      case
        when (p_rival_idx - p_my_idx) >= 2 then 45
        when (p_rival_idx - p_my_idx) = 1 then 30
        when (p_rival_idx - p_my_idx) = 0 then 20
        when (p_rival_idx - p_my_idx) = -1 then 12
        else 6
      end
    else
      case
        when (p_rival_idx - p_my_idx) >= 2 then -8
        when (p_rival_idx - p_my_idx) = 1 then -15
        when (p_rival_idx - p_my_idx) = 0 then -20
        when (p_rival_idx - p_my_idx) = -1 then -30
        else -45
      end
  end;
$$;

-- Peso corporal vigente del usuario (con fallbacks).
create or replace function public._match_bodyweight(p_user_id uuid)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select weight_kg from weight_logs where user_id = p_user_id order by logged_at desc nulls last limit 1),
    (select weight_kg from nutrition_profiles where user_id = p_user_id),
    (select weight_kg from body_metrics_history where user_id = p_user_id order by recorded_at desc nulls last limit 1),
    75
  );
$$;

-- Aplica el delta de RP al pilar challenge y recalcula el rank.
create or replace function public._match_apply_rp(p_user_id uuid, p_delta int)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into user_ranked_profile (user_id, challenge_score)
  values (p_user_id, greatest(0, p_delta))
  on conflict (user_id) do update
    set challenge_score = greatest(0, coalesce(user_ranked_profile.challenge_score, 0) + p_delta);
  perform recalculate_user_rank(p_user_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. RPC: enviar desafio
-- ---------------------------------------------------------------------------
create or replace function public.send_match_challenge(p_challenged_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if v_uid = p_challenged_id then raise exception 'cannot challenge yourself'; end if;

  -- Debe seguir al retado (relacion de amistad/seguimiento).
  if not exists (
    select 1 from follows where follower_id = v_uid and following_id = p_challenged_id
  ) then
    raise exception 'must follow user to challenge';
  end if;

  -- Evitar desafios pendientes duplicados entre el mismo par.
  if exists (
    select 1 from match_challenges
    where status = 'pending'
      and ((challenger_id = v_uid and challenged_id = p_challenged_id)
        or (challenger_id = p_challenged_id and challenged_id = v_uid))
  ) then
    raise exception 'pending challenge already exists';
  end if;

  insert into match_challenges (challenger_id, challenged_id)
  values (v_uid, p_challenged_id)
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. RPC: responder desafio (acepta -> crea partida + 5 rondas)
-- ---------------------------------------------------------------------------
create or replace function public.respond_to_challenge(p_challenge_id uuid, p_accept boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_ch match_challenges%rowtype;
  v_match_id uuid;
  v_season_id uuid;
  v_ex record;
  v_round int := 1;
begin
  if v_uid is null then raise exception 'auth required'; end if;

  select * into v_ch from match_challenges where id = p_challenge_id for update;
  if not found then raise exception 'challenge not found'; end if;
  if v_ch.challenged_id <> v_uid then raise exception 'not your challenge'; end if;
  if v_ch.status <> 'pending' then raise exception 'challenge already resolved'; end if;

  if not p_accept then
    update match_challenges set status = 'rejected', responded_at = now() where id = p_challenge_id;
    return null;
  end if;

  select id into v_season_id from ranked_seasons where is_active = true
    order by start_date desc limit 1;

  insert into matches (season_id, player_a, player_b, current_round, current_turn)
  values (v_season_id, v_ch.challenger_id, v_ch.challenged_id, 1, 'a')
  returning id into v_match_id;

  -- 5 ejercicios aleatorios unicos del pool elegible.
  for v_ex in
    select id from exercises where is_match_eligible = true order by random() limit 5
  loop
    insert into match_rounds (match_id, round_number, exercise_id)
    values (v_match_id, v_round, v_ex.id);
    v_round := v_round + 1;
  end loop;

  if v_round <= 5 then
    -- Pool insuficiente: aborta limpio.
    raise exception 'not enough eligible exercises';
  end if;

  update match_challenges
    set status = 'accepted', responded_at = now(), match_id = v_match_id
    where id = p_challenge_id;

  return v_match_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. RPC: registrar resultado de la ronda actual
-- ---------------------------------------------------------------------------
create or replace function public.submit_match_round(p_match_id uuid, p_weight numeric, p_reps int)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_m matches%rowtype;
  v_slot text;          -- 'a' o 'b' (lado del jugador actual)
  v_bw numeric;
  v_score numeric;
  v_r match_rounds%rowtype;
  v_both boolean;
  v_winner text;
  v_idx_a int; v_idx_b int;
  v_tier_a text; v_tier_b text;
  v_d_a int; v_d_b int;
  v_final_winner uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if p_weight is null or p_weight <= 0 or p_weight > 1000 then raise exception 'invalid weight'; end if;
  if p_reps is null or p_reps < 1 or p_reps > 100 then raise exception 'invalid reps'; end if;

  select * into v_m from matches where id = p_match_id for update;
  if not found then raise exception 'match not found'; end if;
  if v_m.status <> 'active' then raise exception 'match not active'; end if;

  if v_uid = v_m.player_a then v_slot := 'a';
  elsif v_uid = v_m.player_b then v_slot := 'b';
  else raise exception 'not a participant'; end if;

  if v_m.current_turn <> v_slot then raise exception 'not your turn'; end if;

  select * into v_r from match_rounds
    where match_id = p_match_id and round_number = v_m.current_round for update;
  if not found then raise exception 'round not found'; end if;

  v_bw := _match_bodyweight(v_uid);
  if v_bw is null or v_bw <= 0 then v_bw := 75; end if;
  -- Epley relativo al peso corporal.
  v_score := round((p_weight * (1 + p_reps / 30.0)) / v_bw * 100, 2);

  if v_slot = 'a' then
    update match_rounds set weight_a = p_weight, reps_a = p_reps, score_a = v_score
      where id = v_r.id;
  else
    update match_rounds set weight_b = p_weight, reps_b = p_reps, score_b = v_score
      where id = v_r.id;
  end if;

  -- Releer la ronda para saber si ambos registraron.
  select * into v_r from match_rounds where id = v_r.id;
  v_both := v_r.score_a is not null and v_r.score_b is not null;

  if not v_both then
    -- Pasa el turno al rival.
    update matches set current_turn = case when v_slot = 'a' then 'b' else 'a' end
      where id = p_match_id;
    return;
  end if;

  -- Ambos registraron: definir ganador de ronda.
  if v_r.score_a > v_r.score_b then v_winner := 'a';
  elsif v_r.score_b > v_r.score_a then v_winner := 'b';
  else v_winner := 'tie'; end if;

  update match_rounds set round_winner = v_winner where id = v_r.id;

  if v_winner = 'a' then v_m.wins_a := v_m.wins_a + 1;
  elsif v_winner = 'b' then v_m.wins_b := v_m.wins_b + 1; end if;

  -- Fin de partida: alguien llega a 3, o se jugaron las 5 rondas.
  if v_m.wins_a >= 3 or v_m.wins_b >= 3 or v_m.current_round >= 5 then
    select current_tier into v_tier_a from user_ranked_profile where user_id = v_m.player_a;
    select current_tier into v_tier_b from user_ranked_profile where user_id = v_m.player_b;
    v_idx_a := _match_tier_index(coalesce(v_tier_a, 'hierro'));
    v_idx_b := _match_tier_index(coalesce(v_tier_b, 'hierro'));

    if v_m.wins_a > v_m.wins_b then v_final_winner := v_m.player_a;
    elsif v_m.wins_b > v_m.wins_a then v_final_winner := v_m.player_b;
    else
      -- Empate en rondas: desempata por suma de scores.
      if (select coalesce(sum(score_a),0) from match_rounds where match_id = p_match_id)
         >= (select coalesce(sum(score_b),0) from match_rounds where match_id = p_match_id)
      then v_final_winner := v_m.player_a; else v_final_winner := v_m.player_b; end if;
    end if;

    if v_final_winner = v_m.player_a then
      v_d_a := _match_rp_delta(v_idx_a, v_idx_b, true);
      v_d_b := _match_rp_delta(v_idx_b, v_idx_a, false);
    else
      v_d_a := _match_rp_delta(v_idx_a, v_idx_b, false);
      v_d_b := _match_rp_delta(v_idx_b, v_idx_a, true);
    end if;

    update matches set
        status = 'finished',
        wins_a = v_m.wins_a, wins_b = v_m.wins_b,
        winner_id = v_final_winner,
        rp_delta_a = v_d_a, rp_delta_b = v_d_b,
        finished_at = now()
      where id = p_match_id;

    perform _match_apply_rp(v_m.player_a, v_d_a);
    perform _match_apply_rp(v_m.player_b, v_d_b);
    return;
  end if;

  -- Siguiente ronda: el primero alterna (impar -> a, par -> b).
  update matches set
      wins_a = v_m.wins_a, wins_b = v_m.wins_b,
      current_round = v_m.current_round + 1,
      current_turn = case when ((v_m.current_round + 1) % 2) = 1 then 'a' else 'b' end
    where id = p_match_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. RPC: abandonar (el otro gana de inmediato)
-- ---------------------------------------------------------------------------
create or replace function public.forfeit_match(p_match_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_m matches%rowtype;
  v_winner uuid;
  v_idx_a int; v_idx_b int;
  v_tier_a text; v_tier_b text;
  v_d_a int; v_d_b int;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  select * into v_m from matches where id = p_match_id for update;
  if not found then raise exception 'match not found'; end if;
  if v_m.status <> 'active' then raise exception 'match not active'; end if;
  if v_uid <> v_m.player_a and v_uid <> v_m.player_b then raise exception 'not a participant'; end if;

  v_winner := case when v_uid = v_m.player_a then v_m.player_b else v_m.player_a end;

  select current_tier into v_tier_a from user_ranked_profile where user_id = v_m.player_a;
  select current_tier into v_tier_b from user_ranked_profile where user_id = v_m.player_b;
  v_idx_a := _match_tier_index(coalesce(v_tier_a, 'hierro'));
  v_idx_b := _match_tier_index(coalesce(v_tier_b, 'hierro'));

  if v_winner = v_m.player_a then
    v_d_a := _match_rp_delta(v_idx_a, v_idx_b, true);
    v_d_b := _match_rp_delta(v_idx_b, v_idx_a, false);
  else
    v_d_a := _match_rp_delta(v_idx_a, v_idx_b, false);
    v_d_b := _match_rp_delta(v_idx_b, v_idx_a, true);
  end if;

  update matches set
      status = 'abandoned', winner_id = v_winner,
      rp_delta_a = v_d_a, rp_delta_b = v_d_b, finished_at = now()
    where id = p_match_id;

  perform _match_apply_rp(v_m.player_a, v_d_a);
  perform _match_apply_rp(v_m.player_b, v_d_b);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. RLS
-- ---------------------------------------------------------------------------
alter table public.matches enable row level security;
alter table public.match_challenges enable row level security;
alter table public.match_rounds enable row level security;

drop policy if exists matches_select on public.matches;
create policy matches_select on public.matches for select
  using (auth.uid() = player_a or auth.uid() = player_b);

drop policy if exists match_challenges_select on public.match_challenges;
create policy match_challenges_select on public.match_challenges for select
  using (auth.uid() = challenger_id or auth.uid() = challenged_id);

drop policy if exists match_rounds_select on public.match_rounds;
create policy match_rounds_select on public.match_rounds for select
  using (exists (
    select 1 from matches m
    where m.id = match_rounds.match_id
      and (m.player_a = auth.uid() or m.player_b = auth.uid())
  ));

-- Escritura solo via RPC (SECURITY DEFINER). Sin policies de insert/update/delete.

grant execute on function public.send_match_challenge(uuid) to authenticated;
grant execute on function public.respond_to_challenge(uuid, boolean) to authenticated;
grant execute on function public.submit_match_round(uuid, numeric, int) to authenticated;
grant execute on function public.forfeit_match(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Realtime
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.matches;
alter publication supabase_realtime add table public.match_rounds;
alter publication supabase_realtime add table public.match_challenges;
