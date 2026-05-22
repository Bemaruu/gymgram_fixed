-- Check-in semanal del usuario (Plus + Premium).
-- week_start = lunes de la semana, garantiza un solo check-in/semana via unique.

create table if not exists public.ai_weekly_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null,
  response text not null,
  created_at timestamptz not null default now(),
  unique(user_id, week_start)
);

create index if not exists ai_weekly_checkins_user_week_idx
  on public.ai_weekly_checkins (user_id, week_start desc);

alter table public.ai_weekly_checkins enable row level security;

drop policy if exists "ai_weekly_checkins: select own" on public.ai_weekly_checkins;
create policy "ai_weekly_checkins: select own"
  on public.ai_weekly_checkins
  for select
  using (auth.uid() = user_id);

drop policy if exists "ai_weekly_checkins: insert own" on public.ai_weekly_checkins;
create policy "ai_weekly_checkins: insert own"
  on public.ai_weekly_checkins
  for insert
  with check (auth.uid() = user_id);

-- update/delete: no permitido desde cliente
