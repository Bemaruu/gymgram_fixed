-- Objetivos nutricionales calculados/configurados por usuario.
-- Un registro por usuario (unique). Recalcular cuando cambia peso u objetivo.

create table if not exists public.nutrition_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  daily_kcal integer not null,
  protein_g integer not null,
  carbs_g integer not null,
  fat_g integer not null,
  meals_per_day smallint not null default 4,
  recalc_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.nutrition_goals enable row level security;

drop policy if exists "nutrition_goals: select own" on public.nutrition_goals;
create policy "nutrition_goals: select own"
  on public.nutrition_goals
  for select
  using (auth.uid() = user_id);

drop policy if exists "nutrition_goals: insert own" on public.nutrition_goals;
create policy "nutrition_goals: insert own"
  on public.nutrition_goals
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "nutrition_goals: update own" on public.nutrition_goals;
create policy "nutrition_goals: update own"
  on public.nutrition_goals
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "nutrition_goals: delete own" on public.nutrition_goals;
create policy "nutrition_goals: delete own"
  on public.nutrition_goals
  for delete
  using (auth.uid() = user_id);
