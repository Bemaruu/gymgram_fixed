-- Match Mode 1v1: el RPC de envio de desafio ahora exige follow mutuo
-- (amigo = te sigue y lo sigues), igual que la UI.
create or replace function public.send_match_challenge(p_challenged_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
begin
  if v_uid is null then raise exception 'auth required'; end if;
  if v_uid = p_challenged_id then raise exception 'cannot challenge yourself'; end if;

  -- Debe haber follow mutuo (amistad real).
  if not exists (
    select 1 from follows where follower_id = v_uid and following_id = p_challenged_id
  ) or not exists (
    select 1 from follows where follower_id = p_challenged_id and following_id = v_uid
  ) then
    raise exception 'must be mutual followers to challenge';
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
