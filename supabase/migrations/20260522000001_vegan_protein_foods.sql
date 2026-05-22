-- Alimentos veganos densos en proteína para custom_foods.
-- Motivo: las dietas veganas no alcanzaban el objetivo de proteína porque las
-- legumbres dan poca proteína por caloría. Tofu/tempeh/soya/lupino/proteína en
-- polvo permiten al generador armar planes veganos que cierran proteína sin
-- dispararse en carbohidratos. Categoría 'Legumbres' para que el pool de
-- proteína vegetal del generador los tome automáticamente.

INSERT INTO public.custom_foods (
    name, name_normalized, category,
    serving_description, serving_grams,
    kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g,
    source, country_relevance
)
SELECT v.name, v.name_normalized, v.category, v.serving_description,
       v.serving_grams, v.kcal, v.prot, v.carb, v.fat, v.fiber,
       v.source, v.country
FROM (VALUES
  ('Tofu firme','tofu firme','Legumbres','1 porcion (120g)',120.0,144.0,17.3,2.8,8.7,2.3,'USDA',ARRAY['CL','AR','MX','CO','PE']),
  ('Tempeh','tempeh','Legumbres','1 porcion (100g)',100.0,192.0,20.3,7.6,10.8,1.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
  ('Soya texturizada hidratada','soya texturizada hidratada','Legumbres','1 porcion (100g)',100.0,130.0,16.0,10.0,1.0,6.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
  ('Lupino/Chocho cocido','lupino chocho cocido','Legumbres','1 porcion (100g)',100.0,116.0,15.6,9.9,2.9,2.8,'USDA',ARRAY['CL','PE']),
  ('Proteina vegetal en polvo','proteina vegetal en polvo','Legumbres','1 scoop (30g)',30.0,375.0,78.0,8.0,5.0,3.0,'USDA',ARRAY['CL','AR','MX','CO','PE'])
) AS v(name, name_normalized, category, serving_description, serving_grams,
       kcal, prot, carb, fat, fiber, source, country)
WHERE NOT EXISTS (
  SELECT 1 FROM public.custom_foods c WHERE c.name = v.name
);
