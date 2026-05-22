-- Reportes mensuales generados por IA.
-- Plus: GPT-4o mini (basico). Premium: GPT-4o (completo). Un reporte por usuario/mes.

create table if not exists public.ai_monthly_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  month date not null,
  tier_at_generation text not null check (tier_at_generation in ('plus','premium')),
  summary_type text not null check (summary_type in ('plus_basic','premium_full')),
  content text not null,
  generated_at timestamptz not null default now(),
  unique(user_id, month)
);

create index if not exists ai_monthly_summaries_user_month_idx
  on public.ai_monthly_summaries (user_id, month desc);

alter table public.ai_monthly_summaries enable row level security;

drop policy if exists "ai_monthly_summaries: select own" on public.ai_monthly_summaries;
create policy "ai_monthly_summaries: select own"
  on public.ai_monthly_summaries
  for select
  using (auth.uid() = user_id);

-- insert/update/delete: solo service_role (edge function genera el reporte).
