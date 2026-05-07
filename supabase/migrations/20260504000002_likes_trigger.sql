-- Trigger para mantener likes_count sincronizado automáticamente
create or replace function public.sync_post_likes_count()
returns trigger language plpgsql security definer as $$
begin
  if tg_op = 'INSERT' then
    update posts set likes_count = likes_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_sync_likes_count on public.likes;
create trigger trg_sync_likes_count
  after insert or delete on public.likes
  for each row execute function public.sync_post_likes_count();

-- Sincronizar conteos existentes con la realidad
update public.posts p
set likes_count = (select count(*) from public.likes l where l.post_id = p.id);
