-- Soporte para downgrades y cancelaciones agendadas al fin del periodo pagado.
--
-- Reglas de negocio:
-- - Upgrade Plus -> Premium: inmediato, requiere cobro (debe hacerse server-side
--   via service_role despues de validar pago real). No se permite desde cliente.
-- - Downgrade Premium -> Plus: agendado, se aplica al cumplirse subscription_period_end.
-- - Cancelacion Plus/Premium -> Free: agendada, se aplica al cumplirse subscription_period_end.
-- - El usuario puede revertir un cambio pendiente mientras este vigente.
--
-- pending_tier:
--   null  -> no hay cambio agendado
--   'plus' -> downgrade a plus al period_end (solo aplicable si tier actual es premium)
--   'free' -> cancelacion a free al period_end
--   'premium' -> no aplicable (los upgrades son inmediatos)
--
-- subscription_period_end:
--   Fecha en que termina el periodo actualmente pagado. Cuando un job/edge function
--   procesa el vencimiento aplica el pending_tier.

alter table public.profiles
  add column if not exists pending_tier text
  check (pending_tier is null or pending_tier in ('free','plus'));

alter table public.profiles
  add column if not exists subscription_period_end timestamptz;

-- Re-crear trigger: permite que el CLIENTE solo modifique pending_tier siguiendo
-- reglas de downgrade/cancel. Bloquea cualquier otro cambio de campos protegidos.
create or replace function public.prevent_subscription_field_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := current_setting('request.jwt.claim.role', true);
  v_is_service boolean := coalesce(v_role, '') = 'service_role';
begin
  if v_is_service then
    return new;
  end if;

  -- Campos siempre protegidos desde cliente:
  if new.subscription_tier is distinct from old.subscription_tier then
    raise exception 'subscription_tier no se puede modificar desde el cliente';
  end if;
  if new.subscription_expires_at is distinct from old.subscription_expires_at then
    raise exception 'subscription_expires_at no se puede modificar desde el cliente';
  end if;
  if new.subscription_variant is distinct from old.subscription_variant then
    raise exception 'subscription_variant no se puede modificar desde el cliente';
  end if;
  if new.subscription_period_end is distinct from old.subscription_period_end then
    raise exception 'subscription_period_end no se puede modificar desde el cliente';
  end if;

  -- pending_tier: permitido desde cliente solo en estos casos:
  --   * Setear a null (revertir cambio agendado): siempre OK.
  --   * Setear a 'free' (cancelacion): OK si tier actual es plus o premium.
  --   * Setear a 'plus' (downgrade): OK solo si tier actual es premium.
  -- Cualquier upgrade implicito (ej. pasar a 'premium') queda bloqueado.
  if new.pending_tier is distinct from old.pending_tier then
    if new.pending_tier is null then
      -- revertir cambio agendado, permitido
      return new;
    end if;
    if new.pending_tier = 'free' then
      if old.subscription_tier not in ('plus','premium') then
        raise exception 'cancelacion solo aplica a planes pagados';
      end if;
      return new;
    end if;
    if new.pending_tier = 'plus' then
      if old.subscription_tier <> 'premium' then
        raise exception 'downgrade a plus solo aplica desde premium';
      end if;
      return new;
    end if;
    raise exception 'pending_tier valor invalido para cambio desde cliente';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_protect_subscription_fields on public.profiles;
create trigger trg_protect_subscription_fields
before update on public.profiles
for each row
execute function public.prevent_subscription_field_changes();
