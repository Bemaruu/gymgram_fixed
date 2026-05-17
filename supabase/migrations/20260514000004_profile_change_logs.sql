-- Log de cambios de campos restringidos por cuota anual (fitness_goal, training_location).
-- Usado por ChangeQuotaService para limitar a 4 cambios/anio a usuarios free.

create table if not exists public.profile_change_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  field text not null check (field in ('fitness_goal','training_location')),
  old_value text,
  new_value text,
  changed_at timestamptz not null default now()
);

create index if not exists profile_change_logs_user_year_idx
  on public.profile_change_logs (user_id, field, changed_at);

alter table public.profile_change_logs enable row level security;

drop policy if exists "profile_change_logs: select own" on public.profile_change_logs;
create policy "profile_change_logs: select own"
  on public.profile_change_logs
  for select
  using (auth.uid() = user_id);

drop policy if exists "profile_change_logs: insert own" on public.profile_change_logs;
create policy "profile_change_logs: insert own"
  on public.profile_change_logs
  for insert
  with check (auth.uid() = user_id);

-- UPDATE / DELETE: ninguna policy => prohibido para el cliente.
