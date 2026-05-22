-- Restricciones dieteticas del usuario (alergias, intolerancias, preferencias).
-- Usado por la IA nutricional para filtrar alimentos en custom_foods.

create table if not exists public.user_dietary_restrictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  restriction_type text not null check (restriction_type in ('allergy','intolerance','preference')),
  value text not null,
  created_at timestamptz not null default now()
);

create index if not exists user_dietary_restrictions_user_idx
  on public.user_dietary_restrictions (user_id);

alter table public.user_dietary_restrictions enable row level security;

drop policy if exists "user_dietary_restrictions: select own" on public.user_dietary_restrictions;
create policy "user_dietary_restrictions: select own"
  on public.user_dietary_restrictions
  for select
  using (auth.uid() = user_id);

drop policy if exists "user_dietary_restrictions: insert own" on public.user_dietary_restrictions;
create policy "user_dietary_restrictions: insert own"
  on public.user_dietary_restrictions
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_dietary_restrictions: update own" on public.user_dietary_restrictions;
create policy "user_dietary_restrictions: update own"
  on public.user_dietary_restrictions
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_dietary_restrictions: delete own" on public.user_dietary_restrictions;
create policy "user_dietary_restrictions: delete own"
  on public.user_dietary_restrictions
  for delete
  using (auth.uid() = user_id);
