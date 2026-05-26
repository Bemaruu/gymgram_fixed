-- Ingredient-level nutrition (MyFitnessPal-style).
-- Recipes carry a structured ingredient list; macros are DERIVED from each
-- ingredient's per-100g data in custom_foods. Stored aggregate macros remain
-- as a fallback only. meal_items persists the per-ingredient breakdown.

alter table public.ai_meal_templates
  add column if not exists ingredientes_estructurados jsonb not null default '[]'::jsonb;

alter table public.meal_items
  add column if not exists components jsonb not null default '[]'::jsonb;

comment on column public.ai_meal_templates.ingredientes_estructurados is
  'Array of {"food": name_normalized, "g": base_grams}. Macros derived from custom_foods at generation time.';
comment on column public.meal_items.components is
  'Persisted per-ingredient breakdown: array of {name, grams, units, calories, protein, carbs, fats}.';
