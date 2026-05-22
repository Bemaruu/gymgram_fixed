-- Mensajes del chat con el entrenador IA (Premium).
-- message_type diferencia chat libre, respuestas post-workout y check-in semanal.

create table if not exists public.ai_trainer_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','assistant')),
  content text not null,
  message_type text not null default 'chat'
    check (message_type in ('chat','post_workout','weekly_checkin')),
  created_at timestamptz not null default now()
);

create index if not exists ai_trainer_messages_user_date_idx
  on public.ai_trainer_messages (user_id, created_at desc);

alter table public.ai_trainer_messages enable row level security;

drop policy if exists "ai_trainer_messages: select own" on public.ai_trainer_messages;
create policy "ai_trainer_messages: select own"
  on public.ai_trainer_messages
  for select
  using (auth.uid() = user_id);

drop policy if exists "ai_trainer_messages: insert own user role" on public.ai_trainer_messages;
create policy "ai_trainer_messages: insert own user role"
  on public.ai_trainer_messages
  for insert
  with check (auth.uid() = user_id and role = 'user');

-- mensajes 'assistant' los inserta la edge function via service_role.
