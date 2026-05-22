-- Tabla water_logs requerida por WaterService (lib/services/water_service.dart).
-- Un registro por usuario por dia, upsert con onConflict(user_id, target_date).

create table if not exists public.water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_date date not null default current_date,
  glasses_count smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, target_date)
);

create index if not exists water_logs_user_date_idx
  on public.water_logs (user_id, target_date desc);

alter table public.water_logs enable row level security;

drop policy if exists "water_logs: select own" on public.water_logs;
create policy "water_logs: select own"
  on public.water_logs
  for select
  using (auth.uid() = user_id);

drop policy if exists "water_logs: insert own" on public.water_logs;
create policy "water_logs: insert own"
  on public.water_logs
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "water_logs: update own" on public.water_logs;
create policy "water_logs: update own"
  on public.water_logs
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "water_logs: delete own" on public.water_logs;
create policy "water_logs: delete own"
  on public.water_logs
  for delete
  using (auth.uid() = user_id);
