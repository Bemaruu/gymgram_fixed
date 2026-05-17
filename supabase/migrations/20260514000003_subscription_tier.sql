-- Subscription tier para profiles (free / plus / premium)
-- Decision: usamos trigger BEFORE UPDATE para proteger los campos sensibles,
-- ya que la policy "profiles: update own" existente permite cualquier columna.
-- Reescribir esa policy con un USING+WITH CHECK con OLD/NEW no es posible en
-- Postgres (FOR UPDATE no expone OLD en WITH CHECK), por lo que la opcion mas
-- segura y minima invasiva es bloquear via trigger ante non-service-role.

alter table public.profiles
  add column if not exists subscription_tier text not null default 'free'
  check (subscription_tier in ('free','plus','premium'));

alter table public.profiles
  add column if not exists subscription_expires_at timestamptz;

-- Trigger que bloquea cambios a campos protegidos cuando el rol actual no es
-- service_role (es decir, viene del cliente con anon/authenticated key).
create or replace function public.prevent_subscription_field_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := current_setting('request.jwt.claim.role', true);
begin
  if coalesce(v_role, '') <> 'service_role' then
    if new.subscription_tier is distinct from old.subscription_tier then
      raise exception 'subscription_tier no se puede modificar desde el cliente';
    end if;
    if new.subscription_expires_at is distinct from old.subscription_expires_at then
      raise exception 'subscription_expires_at no se puede modificar desde el cliente';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_subscription_fields on public.profiles;
create trigger trg_protect_subscription_fields
before update on public.profiles
for each row
execute function public.prevent_subscription_field_changes();
