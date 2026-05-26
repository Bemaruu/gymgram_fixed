-- Country-specific staple ingredients missing from the Chilean catalog, needed
-- so recipe ingredient lists resolve to real per-100g nutrition. Values are
-- per 100g as-eaten (cooked), USDA/standard references.

-- Unique name_normalized: guarantees the recipe ingredient index has no
-- collisions and makes seed inserts idempotent.
alter table public.custom_foods
  drop constraint if exists custom_foods_name_normalized_key;
alter table public.custom_foods
  add constraint custom_foods_name_normalized_key unique (name_normalized);

insert into public.custom_foods
  (name, name_normalized, category, serving_description, serving_grams,
   kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g,
   fiber_per_100g, source, country_relevance)
values
  ('Arepa de maíz', 'arepa', 'Cereales', '1 arepa', 120, 219, 4.7, 45.0, 2.3, 2.4, 'estimado', ARRAY['CO','VE']),
  ('Cachapa de maíz', 'cachapa', 'Cereales', '1 cachapa', 150, 210, 5.0, 40.0, 4.0, 2.0, 'estimado', ARRAY['VE']),
  ('Masa de maíz cocida', 'masa de maiz', 'Cereales', '1 porción', 120, 200, 4.5, 42.0, 2.5, 2.5, 'estimado', ARRAY['VE','CO','MX']),
  ('Yuca cocida', 'yuca', 'Verduras', '1 porción', 100, 112, 1.4, 27.0, 0.3, 1.8, 'estimado', ARRAY['CO','VE','PE']),
  ('Plátano verde cocido', 'platano verde', 'Verduras', '1 porción', 100, 122, 1.3, 32.0, 0.4, 2.3, 'estimado', ARRAY['CO','VE']),
  ('Nopales cocidos', 'nopales', 'Verduras', '1 porción', 80, 15, 1.3, 3.3, 0.1, 2.2, 'estimado', ARRAY['MX']),
  ('Pescado blanco cocido', 'pescado blanco', 'Proteinas', '1 filete', 150, 100, 21.0, 0.0, 1.5, 0.0, 'estimado', ARRAY['CL','AR','CO','PE','VE','ES','MX','GLOBAL']),
  ('Mariscos surtidos cocidos', 'mariscos surtidos', 'Proteinas', '1 porción', 120, 90, 18.0, 2.0, 1.0, 0.0, 'estimado', ARRAY['CL','PE','ES','VE','CO']),
  ('Pulpo cocido', 'pulpo', 'Proteinas', '1 porción', 120, 164, 30.0, 4.0, 2.0, 0.0, 'estimado', ARRAY['PE','ES']),
  ('Calamar cocido', 'calamar', 'Proteinas', '1 porción', 120, 92, 15.6, 3.1, 1.4, 0.0, 'estimado', ARRAY['ES']),
  ('Bacalao cocido', 'bacalao', 'Proteinas', '1 filete', 150, 105, 23.0, 0.0, 0.9, 0.0, 'estimado', ARRAY['ES']),
  ('Trucha cocida', 'trucha', 'Proteinas', '1 filete', 150, 190, 27.0, 0.0, 8.5, 0.0, 'estimado', ARRAY['AR']),
  ('Leche de coco', 'leche de coco', 'Grasas', '1/2 taza', 120, 230, 2.3, 6.0, 24.0, 2.2, 'estimado', ARRAY['CO','VE']),
  ('Mole poblano', 'mole poblano', 'Preparaciones', '1 porción salsa', 60, 250, 5.0, 20.0, 16.0, 4.0, 'estimado', ARRAY['MX'])
on conflict (name_normalized) do nothing;
