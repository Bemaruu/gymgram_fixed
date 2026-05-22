-- Variante del plan: normal | launch | founder.
-- launch y founder son precios promocionales mas baratos.
-- Protegido por el mismo trigger que subscription_tier (solo service_role lo cambia).

alter table public.profiles
  add column if not exists subscription_variant text not null default 'normal'
  check (subscription_variant in ('normal','launch','founder'));

-- Extender trigger existente para incluir subscription_variant.
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
    if new.subscription_variant is distinct from old.subscription_variant then
      raise exception 'subscription_variant no se puede modificar desde el cliente';
    end if;
  end if;
  return new;
end;
$$;
