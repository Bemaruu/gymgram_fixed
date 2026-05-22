-- ============================================================
-- 20260518000001_water_logs.sql
-- ============================================================
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



-- ============================================================
-- 20260518000002_nutrition_goals.sql
-- ============================================================
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



-- ============================================================
-- 20260518000003_user_dietary_restrictions.sql
-- ============================================================
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



-- ============================================================
-- 20260518000004_user_recipes.sql
-- ============================================================
-- Recetas creadas por usuarios + ingredientes + recetas guardadas.
-- Las publicas se ven en el perfil. Free puede publicar maximo 5 (chequeado en cliente
-- via RecipeService.canPublishMore() y en politicas RLS no se limita por cuota).

-- ============================================================================
-- user_recipes
-- ============================================================================

create table if not exists public.user_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  servings numeric(4,1) not null default 1,
  prep_time_min integer,
  image_url text,
  instructions text,
  is_public boolean not null default false,
  saves_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists user_recipes_user_idx on public.user_recipes (user_id, created_at desc);
create index if not exists user_recipes_public_idx on public.user_recipes (is_public, created_at desc) where is_public = true;

alter table public.user_recipes enable row level security;

drop policy if exists "user_recipes: select public or own" on public.user_recipes;
create policy "user_recipes: select public or own"
  on public.user_recipes
  for select
  using (is_public = true or auth.uid() = user_id);

drop policy if exists "user_recipes: insert own" on public.user_recipes;
create policy "user_recipes: insert own"
  on public.user_recipes
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_recipes: update own" on public.user_recipes;
create policy "user_recipes: update own"
  on public.user_recipes
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_recipes: delete own" on public.user_recipes;
create policy "user_recipes: delete own"
  on public.user_recipes
  for delete
  using (auth.uid() = user_id);

-- ============================================================================
-- user_recipe_ingredients
-- ============================================================================

create table if not exists public.user_recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.user_recipes(id) on delete cascade,
  food_id uuid references public.custom_foods(id) on delete set null,
  food_name_manual text,
  grams numeric(7,2) not null,
  created_at timestamptz not null default now(),
  check (food_id is not null or food_name_manual is not null)
);

create index if not exists user_recipe_ingredients_recipe_idx
  on public.user_recipe_ingredients (recipe_id);

alter table public.user_recipe_ingredients enable row level security;

drop policy if exists "recipe_ingredients: select if recipe visible" on public.user_recipe_ingredients;
create policy "recipe_ingredients: select if recipe visible"
  on public.user_recipe_ingredients
  for select
  using (
    exists (
      select 1 from public.user_recipes r
      where r.id = recipe_id
        and (r.is_public = true or r.user_id = auth.uid())
    )
  );

drop policy if exists "recipe_ingredients: insert if recipe own" on public.user_recipe_ingredients;
create policy "recipe_ingredients: insert if recipe own"
  on public.user_recipe_ingredients
  for insert
  with check (
    exists (
      select 1 from public.user_recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  );

drop policy if exists "recipe_ingredients: update if recipe own" on public.user_recipe_ingredients;
create policy "recipe_ingredients: update if recipe own"
  on public.user_recipe_ingredients
  for update
  using (
    exists (
      select 1 from public.user_recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.user_recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  );

drop policy if exists "recipe_ingredients: delete if recipe own" on public.user_recipe_ingredients;
create policy "recipe_ingredients: delete if recipe own"
  on public.user_recipe_ingredients
  for delete
  using (
    exists (
      select 1 from public.user_recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  );

-- ============================================================================
-- saved_recipes
-- ============================================================================

create table if not exists public.saved_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recipe_id uuid not null references public.user_recipes(id) on delete cascade,
  saved_at timestamptz not null default now(),
  unique(user_id, recipe_id)
);

create index if not exists saved_recipes_user_idx on public.saved_recipes (user_id, saved_at desc);

alter table public.saved_recipes enable row level security;

drop policy if exists "saved_recipes: select own" on public.saved_recipes;
create policy "saved_recipes: select own"
  on public.saved_recipes
  for select
  using (auth.uid() = user_id);

drop policy if exists "saved_recipes: insert own" on public.saved_recipes;
create policy "saved_recipes: insert own"
  on public.saved_recipes
  for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.user_recipes r
      where r.id = recipe_id and r.is_public = true
    )
  );

drop policy if exists "saved_recipes: delete own" on public.saved_recipes;
create policy "saved_recipes: delete own"
  on public.saved_recipes
  for delete
  using (auth.uid() = user_id);

-- ============================================================================
-- Trigger: mantener saves_count en user_recipes
-- ============================================================================

create or replace function public.bump_recipe_saves_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.user_recipes
       set saves_count = saves_count + 1
     where id = new.recipe_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.user_recipes
       set saves_count = greatest(saves_count - 1, 0)
     where id = old.recipe_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_saved_recipes_count_ins on public.saved_recipes;
create trigger trg_saved_recipes_count_ins
  after insert on public.saved_recipes
  for each row execute function public.bump_recipe_saves_count();

drop trigger if exists trg_saved_recipes_count_del on public.saved_recipes;
create trigger trg_saved_recipes_count_del
  after delete on public.saved_recipes
  for each row execute function public.bump_recipe_saves_count();



-- ============================================================
-- 20260518000005_ai_weekly_checkins.sql
-- ============================================================
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



-- ============================================================
-- 20260518000006_workout_feedback.sql
-- ============================================================
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



-- ============================================================
-- 20260518000007_ai_monthly_summaries.sql
-- ============================================================
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



-- ============================================================
-- 20260518000008_ai_trainer_config.sql
-- ============================================================
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



-- ============================================================
-- 20260518000009_ai_trainer_messages.sql
-- ============================================================
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



-- ============================================================
-- 20260518000010_profile_change_logs_routine_ai.sql
-- ============================================================
-- Agrega 'routine_ai_change' al check constraint de profile_change_logs.field.
-- Permite contar regeneraciones del plan IA dentro de la cuota anual combinada.

alter table public.profile_change_logs
  drop constraint if exists profile_change_logs_field_check;

alter table public.profile_change_logs
  add constraint profile_change_logs_field_check
  check (field in ('fitness_goal','training_location','routine_ai_change'));



-- ============================================================
-- 20260518000011_subscription_variant.sql
-- ============================================================
-- Variante del plan: normal | launch | founder.
-- launch y founder son precios promocionales mas baratos.
-- Protegido por el mismo trigger que subscription_tier (solo service_role lo cambia).

alter table public.profiles
  add column if not exists subscription_variant text not null default 'normal'
  check (subscription_variant in ('normal','launch','founder'));

-- Extender trigger existente para incluir subscription_variant.
create or replace function public.prevent_subscription_field_changes()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text := current_setting('request.jwt.claim.role', true);
begin
  if coalesce(v_role, '') <> 'service_role' then
    if new.subscription_tier is distinct from old.subscription_tier then
      raise exception 'subscription_tier no se puede modificar desde el cliente';
    end if;
    if new.subscription_expires_at is distinct from old.subscription_expires_at then
      raise exception 'subscription_expires_at no se puede modificar desde el cliente';
    end if;
    if new.subscription_variant is distinct from old.subscription_variant then
      raise exception 'subscription_variant no se puede modificar desde el cliente';
    end if;
  end if;
  return new;
end;
$$;



-- ============================================================
-- 20260518000012_monthly_report_cron.sql
-- ============================================================
-- pg_cron schedule para invocar la edge function `generate-monthly-report`
-- el dia 1 de cada mes a las 03:00 UTC.
--
-- Requiere:
--   1. Extensiones `pg_cron`, `pg_net` y `supabase_vault` habilitadas
--      (dashboard -> Database -> Extensions).
--   2. Dos secrets en Vault:
--        select vault.create_secret('https://<ref>.supabase.co', 'project_url');
--        select vault.create_secret('<service-role-key>', 'service_role_key');
--      Se configuran via SQL Editor antes de aplicar esta migracion.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Borrar schedule previo si existiera (idempotente)
do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname = 'generate-monthly-report-cron';
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;
end $$;

-- Agendar: dia 1 de cada mes a las 03:00 UTC
select cron.schedule(
  'generate-monthly-report-cron',
  '0 3 1 * *',
  $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name = 'project_url')
           || '/functions/v1/generate-monthly-report',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' ||
        (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key')
    ),
    body := jsonb_build_object('batch', true)
  );
  $cron$
);



