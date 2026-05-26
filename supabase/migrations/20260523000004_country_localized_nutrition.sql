-- Country-aware nutrition personalization.
-- Keeps current Chile data as the default while allowing country-specific
-- recipes, food relevance and Open Food Facts localization.

alter table public.profiles
  add column if not exists country_code text not null default 'CL';

alter table public.user_onboarding_data
  add column if not exists country_code text not null default 'CL';

alter table public.custom_foods
  add column if not exists country_relevance text[] default array['CL'];

alter table public.profiles
  drop constraint if exists profiles_country_code_chk;
alter table public.profiles
  add constraint profiles_country_code_chk
  check (country_code ~ '^[A-Z]{2}$');

alter table public.user_onboarding_data
  drop constraint if exists user_onboarding_data_country_code_chk;
alter table public.user_onboarding_data
  add constraint user_onboarding_data_country_code_chk
  check (country_code ~ '^[A-Z]{2}$');

create index if not exists idx_profiles_country_code
  on public.profiles(country_code);

create index if not exists idx_user_onboarding_data_country_code
  on public.user_onboarding_data(country_code);

create index if not exists idx_ai_meal_templates_pais_origen
  on public.ai_meal_templates(pais_origen);

create index if not exists idx_custom_foods_country_relevance
  on public.custom_foods using gin(country_relevance);
