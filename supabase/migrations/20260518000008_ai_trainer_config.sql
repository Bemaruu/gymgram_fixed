-- Configuracion del entrenador IA personalizado (solo Premium).
-- nombre, avatar, tono y foco se eligen en el onboarding al activar Premium.

create table if not exists public.ai_trainer_config (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade unique,
  trainer_name text not null default 'Coach',
  avatar_id text not null default 'avatar_1'
    check (avatar_id in ('avatar_1','avatar_2','avatar_3','avatar_4')),
  tone text not null default 'motivador'
    check (tone in ('motivador','directo','relajado','exigente')),
  focus text not null default 'ambos'
    check (focus in ('entrenamiento','nutricion','ambos')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.ai_trainer_config enable row level security;

drop policy if exists "ai_trainer_config: select own" on public.ai_trainer_config;
create policy "ai_trainer_config: select own"
  on public.ai_trainer_config
  for select
  using (auth.uid() = user_id);

drop policy if exists "ai_trainer_config: insert own" on public.ai_trainer_config;
create policy "ai_trainer_config: insert own"
  on public.ai_trainer_config
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "ai_trainer_config: update own" on public.ai_trainer_config;
create policy "ai_trainer_config: update own"
  on public.ai_trainer_config
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
