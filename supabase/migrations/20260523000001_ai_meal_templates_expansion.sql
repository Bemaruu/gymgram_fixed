-- Expansión del catálogo de recetas (ai_meal_templates) para GymGram.
-- 1) Normaliza el valor legacy 'mantenimiento' -> 'mantener' (raíz del bug que
--    ocultaba ~1/3 del catálogo a usuarios en mantención).
-- 2) Agrega recetas nuevas con foco en variedad vegetariana/vegana y opciones
--    livianas, usando el valor canónico 'mantener'.
-- Macros POR PORCIÓN SERVIDA (campo porcion_g). Fuente: estimaciones propias
-- calibradas con USDA FoodData Central.

-- ─── 1. Normalización de datos legacy ───────────────────────────────────────
update public.ai_meal_templates
set objetivo_recomendado = array_replace(objetivo_recomendado, 'mantenimiento', 'mantener')
where 'mantenimiento' = any(objetivo_recomendado);

-- ─── 2. Recetas nuevas (idempotente vía external_id único) ───────────────────
insert into public.ai_meal_templates
  (external_id, nombre, categoria_dificultad, modo_dieta, momento_dia,
   porcion_g, kcal, proteina_g, carbohidratos_g, grasas_g, fibra_g, sodio_mg,
   ingredientes_base, tags, objetivo_recomendado,
   costo_estimado_clp, nota_para_ia, source_url, confiabilidad)
values
  ('CL-046', 'Tofu salteado con arroz y verduras', 'Normal', 'Vegano', ARRAY['almuerzo','cena'],
   400, 540, 26, 70, 16, 8, 620,
   'tofu firme, arroz, brócoli, zanahoria, salsa de soya', ARRAY['vegano','alto_proteina','verduras'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   2200, 'Buena opción vegana alta en proteína; cuidar sodio de la soya.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-047', 'Lentejas guisadas con arroz y palta', 'Muy fácil', 'Vegano', ARRAY['almuerzo','cena'],
   430, 580, 23, 88, 14, 17, 640,
   'lentejas, arroz, palta, cebolla, zanahoria', ARRAY['vegano','legumbres','alto_fibra'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   1400, 'Económica, saciante y completa; combinación legumbre+cereal aporta proteína de calidad.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-048', 'Ensalada de garbanzos, tomate y palta', 'Muy fácil', 'Vegano', ARRAY['almuerzo','cena','colacion'],
   350, 460, 17, 48, 22, 12, 520,
   'garbanzos cocidos, tomate, palta, cebolla, aceite oliva', ARRAY['vegano','liviano','alto_fibra'], ARRAY['perder_grasa','mantener'],
   1900, 'Liviana y fresca; ideal para déficit con buena saciedad.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-049', 'Wrap vegetariano de huevo y verduras', 'Muy fácil', 'Vegetariano', ARRAY['almuerzo','colacion'],
   300, 480, 24, 46, 22, 6, 640,
   'tortilla integral, huevo, espinaca, tomate, queso', ARRAY['vegetariano','portable','alto_proteina'], ARRAY['perder_grasa','mantener'],
   1700, 'Práctico para llevar; sube proteína con clara extra si se busca volumen.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-050', 'Porotos negros con arroz y pico de gallo', 'Muy fácil', 'Vegano', ARRAY['almuerzo','cena'],
   420, 560, 21, 96, 8, 16, 600,
   'porotos negros, arroz, tomate, cebolla, cilantro', ARRAY['vegano','economico','alto_fibra'], ARRAY['mantener','ganar_musculo'],
   1300, 'Clásico latino económico; legumbre+cereal completa el perfil de aminoácidos.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-051', 'Quinoa con verduras salteadas y huevo', 'Normal', 'Vegetariano', ARRAY['almuerzo','cena'],
   380, 520, 24, 62, 18, 9, 540,
   'quinoa, zapallo italiano, pimentón, cebolla, huevo', ARRAY['vegetariano','alto_fibra'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   2400, 'Buena densidad nutricional; la quinoa aporta proteína vegetal completa.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-052', 'Pollo a la plancha con puré de zanahoria', 'Muy fácil', 'Casero / Normal', ARRAY['almuerzo','cena'],
   380, 470, 44, 32, 17, 6, 560,
   'pechuga de pollo, zanahoria, papa, aceite oliva', ARRAY['alto_proteina','liviano'], ARRAY['perder_grasa','mantener'],
   2200, 'Alta proteína y carbohidrato moderado; ideal para definición.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-053', 'Pescado al horno con papas y ensalada', 'Normal', 'Casero / Normal', ARRAY['almuerzo','cena'],
   400, 520, 40, 48, 16, 6, 580,
   'merluza o reineta, papas, lechuga, tomate, limón', ARRAY['alto_proteina','liviano','omega3'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   2600, 'Magro y completo; controlar aceite para mantener calorías bajas.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-054', 'Pavo con arroz integral y brócoli', 'Muy fácil', 'Casero / Normal', ARRAY['almuerzo','cena'],
   400, 560, 45, 62, 13, 7, 520,
   'pavo molido o filete, arroz integral, brócoli', ARRAY['alto_proteina','meal_prep'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   2700, 'Excelente para meal prep fitness; perfil limpio y alto en proteína.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-055', 'Tortilla de avena con plátano', 'Muy fácil', 'Vegetariano', ARRAY['desayuno','colacion','post_entreno'],
   260, 410, 18, 58, 11, 7, 220,
   'avena, huevo, plátano, leche, canela', ARRAY['vegetariano','pre_entreno','alto_fibra'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   1100, 'Buen desayuno o post-entreno; energía sostenida y proteína moderada.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-056', 'Pan integral con huevo revuelto y palta', 'Muy fácil', 'Vegetariano', ARRAY['desayuno','once'],
   240, 430, 20, 36, 24, 7, 540,
   'pan integral, huevo, palta, tomate', ARRAY['vegetariano','alto_proteina'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   1300, 'Desayuno equilibrado con grasas saludables; ajustar pan según objetivo.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-057', 'Bowl de yogur griego, granola y frutos rojos', 'Muy fácil', 'Vegetariano', ARRAY['desayuno','colacion'],
   300, 360, 22, 48, 9, 5, 120,
   'yogur griego, granola, frambuesa, arándano', ARRAY['vegetariano','alto_proteina','rapido'], ARRAY['perder_grasa','mantener'],
   2200, 'Colación alta en proteína; usar yogur sin azúcar para definición.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-058', 'Sándwich integral de pavo y queso', 'Muy fácil', 'Casero / Normal', ARRAY['almuerzo','colacion','once'],
   220, 420, 28, 42, 14, 5, 820,
   'pan integral, jamón de pavo, queso, lechuga, tomate', ARRAY['portable','alto_proteina','rapido'], ARRAY['perder_grasa','mantener'],
   1600, 'Rápido y portable; cuidar sodio del fiambre.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-059', 'Arroz con pollo al curry suave', 'Normal', 'Casero / Normal', ARRAY['almuerzo','cena'],
   400, 620, 42, 78, 16, 5, 700,
   'pollo, arroz, curry, leche de coco light, arvejas', ARRAY['alto_proteina','sabroso'], ARRAY['mantener','ganar_musculo'],
   2600, 'Variante sabrosa del clásico pollo-arroz; moderar leche de coco.', 'https://fdc.nal.usda.gov/', 'estimado'),
  ('CL-060', 'Fideos integrales con verduras y atún', 'Muy fácil', 'Casero / Normal', ARRAY['almuerzo','cena'],
   390, 580, 34, 82, 12, 9, 720,
   'fideos integrales, atún al agua, zapallo italiano, tomate', ARRAY['alto_proteina','economico','rapido'], ARRAY['perder_grasa','mantener','ganar_musculo'],
   1700, 'Rápida y proteica; cuidar sodio del atún en lata.', 'https://fdc.nal.usda.gov/', 'estimado')
on conflict (external_id) do nothing;
