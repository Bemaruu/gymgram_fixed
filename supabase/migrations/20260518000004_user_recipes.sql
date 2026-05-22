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
