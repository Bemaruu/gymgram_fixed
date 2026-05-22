-- Feedback post-entreno (solo Premium).
-- El usuario responde tras completar workout. Edge function genera ai_response (GPT-4o).

create table if not exists public.workout_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  workout_completed_at timestamptz not null default now(),
  user_response text not null,
  ai_response text,
  ai_responded_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists workout_feedback_user_date_idx
  on public.workout_feedback (user_id, workout_completed_at desc);

alter table public.workout_feedback enable row level security;

drop policy if exists "workout_feedback: select own" on public.workout_feedback;
create policy "workout_feedback: select own"
  on public.workout_feedback
  for select
  using (auth.uid() = user_id);

drop policy if exists "workout_feedback: insert own" on public.workout_feedback;
create policy "workout_feedback: insert own"
  on public.workout_feedback
  for insert
  with check (auth.uid() = user_id);

-- ai_response solo se actualiza desde service_role (edge function).
-- update/delete: no permitido desde cliente.
