-- ===== PRE-REQS =====
-- 1) custom_foods + seed (idempotente)
-- ExtensiÃ³n para bÃºsqueda por trigrama
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.custom_foods (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name                TEXT NOT NULL,
    name_normalized     TEXT NOT NULL,
    category            TEXT NOT NULL,
    serving_description TEXT,
    serving_grams       NUMERIC(6,1) DEFAULT 100,
    kcal_per_100g       NUMERIC(7,2) NOT NULL,
    protein_per_100g    NUMERIC(6,2) NOT NULL DEFAULT 0,
    carbs_per_100g      NUMERIC(6,2) NOT NULL DEFAULT 0,
    fat_per_100g        NUMERIC(6,2) NOT NULL DEFAULT 0,
    fiber_per_100g      NUMERIC(6,2) NOT NULL DEFAULT 0,
    source              TEXT DEFAULT 'USDA',
    country_relevance   TEXT[] DEFAULT ARRAY['CL'],
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_custom_foods_name_trgm
    ON public.custom_foods USING GIN (name_normalized gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_custom_foods_name_trgm_orig
    ON public.custom_foods USING GIN (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_custom_foods_category
    ON public.custom_foods (category);

ALTER TABLE public.custom_foods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "custom_foods_select_authenticated" ON public.custom_foods;
CREATE POLICY "custom_foods_select_authenticated" ON public.custom_foods FOR SELECT TO authenticated USING (true);


DO $mig$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.custom_foods LIMIT 1) THEN
    INSERT INTO public.custom_foods (
    name, name_normalized, category,
    serving_description, serving_grams,
    kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g,
    source, country_relevance
) VALUES
('Arroz blanco cocido','arroz blanco cocido','Cereales','1 taza cocida',195,130,2.7,28.2,0.3,0.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Arroz integral cocido','arroz integral cocido','Cereales','1 taza cocida',195,111,2.6,22.8,0.9,1.8,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pan marraqueta','pan marraqueta','Cereales','1 unidad (90g)',90,275,9.0,53.0,2.5,2.0,'INTA',ARRAY['CL']),
('Pan de molde blanco','pan de molde blanco','Cereales','1 rebanada (25g)',25,265,8.5,50.0,3.2,2.3,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pan integral','pan integral','Cereales','1 rebanada (30g)',30,247,9.0,43.0,3.4,6.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pasta cocida (espagueti)','pasta cocida espagueti','Cereales','1 taza cocida',140,158,5.8,30.9,0.9,1.8,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Fideos tallarines cocidos','fideos tallarines cocidos','Cereales','1 taza cocida',140,156,5.5,30.4,0.9,1.5,'USDA',ARRAY['CL','AR']),
('Avena cocida','avena cocida','Cereales','1 taza cocida',234,71,2.5,12.0,1.4,1.7,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Quinoa cocida','quinoa cocida','Cereales','1 taza cocida',185,120,4.4,21.3,1.9,2.8,'USDA',ARRAY['CL','AR','PE','CO']),
('Maiz cocido','maiz cocido','Cereales','1 choclo mediano',90,96,3.4,20.9,1.5,2.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Harina de trigo','harina de trigo','Cereales','1 taza (120g)',120,364,10.3,76.3,1.0,2.7,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Galletas de agua','galletas de agua','Cereales','5 galletas (30g)',30,418,8.0,74.0,9.8,2.0,'INTA',ARRAY['CL','AR']),
('Tortilla de maiz','tortilla de maiz','Cereales','1 tortilla (30g)',30,218,5.7,45.9,2.5,6.3,'USDA',ARRAY['MX','CO','PE']),
('Tortilla de trigo','tortilla de trigo','Cereales','1 tortilla (45g)',45,312,8.8,53.7,7.1,3.0,'USDA',ARRAY['MX','CL','AR']),
('Cous cous cocido','cous cous cocido','Cereales','1 taza cocida',157,112,3.8,23.2,0.2,1.4,'USDA',ARRAY['CL','AR']),
('Mote (trigo cocido)','mote trigo cocido','Cereales','1 taza cocida',200,122,4.1,25.4,0.9,2.2,'INTA',ARRAY['CL','PE']),
('Porotos granados cocidos','porotos granados cocidos','Cereales','1 taza cocida',180,127,8.0,22.6,0.8,7.0,'INTA',ARRAY['CL']),
('Pan hallulla','pan hallulla','Cereales','1 unidad (60g)',60,285,8.5,55.0,3.5,2.0,'INTA',ARRAY['CL']),
('Tostadas integrales','tostadas integrales','Cereales','2 tostadas (20g)',20,350,12.0,60.0,5.0,8.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pan pita integral','pan pita integral','Cereales','1 unidad (57g)',57,266,9.5,53.0,1.8,5.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pechuga de pollo a la plancha','pechuga de pollo a la plancha','Proteinas','1 pechuga mediana (120g)',120,165,31.0,0.0,3.6,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Muslo de pollo cocido','muslo de pollo cocido','Proteinas','1 muslo sin piel (85g)',85,185,27.0,0.0,8.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pollo entero cocido','pollo entero cocido','Proteinas','100g porcion',100,215,29.0,0.0,10.8,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Carne de vacuno magra cocida','carne de vacuno magra cocida','Proteinas','100g porcion',100,215,31.0,0.0,9.5,0.0,'USDA',ARRAY['CL','AR','CO','PE']),
('Carne molida cocida','carne molida cocida','Proteinas','100g porcion',100,250,28.0,0.0,14.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Lomo de cerdo cocido','lomo de cerdo cocido','Proteinas','100g porcion',100,185,29.0,0.0,7.2,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Filete de cerdo','filete de cerdo','Proteinas','100g porcion',100,195,28.0,0.0,8.5,0.0,'USDA',ARRAY['CL','AR','MX']),
('Tocino/Panceta cocida','tocino panceta cocida','Proteinas','3 lonchas (30g)',30,541,37.0,1.4,42.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Salchicha de cerdo','salchicha de cerdo','Proteinas','1 unidad (50g)',50,296,13.0,2.4,25.8,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Huevo entero cocido','huevo entero cocido','Proteinas','1 huevo grande (50g)',50,155,12.6,1.1,10.6,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Clara de huevo cocida','clara de huevo cocida','Proteinas','1 clara grande (33g)',33,52,10.9,0.7,0.2,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Yema de huevo','yema de huevo','Proteinas','1 yema (17g)',17,322,16.0,3.6,26.5,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Atun en agua escurrido','atun en agua escurrido','Proteinas','1 lata escurrida (130g)',130,116,25.5,0.0,1.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Salmon cocido','salmon cocido','Proteinas','1 filete (100g)',100,208,28.0,0.0,10.0,0.0,'USDA',ARRAY['CL','PE']),
('Merluza cocida','merluza cocida','Proteinas','1 filete (120g)',120,90,18.8,0.0,1.4,0.0,'INTA',ARRAY['CL','AR','PE']),
('Reineta cocida','reineta cocida','Proteinas','1 filete (100g)',100,105,19.5,0.0,2.8,0.0,'INTA',ARRAY['CL']),
('Congrio cocido','congrio cocido','Proteinas','1 porcion (120g)',120,112,21.0,0.0,2.5,0.0,'INTA',ARRAY['CL','PE']),
('Camarones cocidos','camarones cocidos','Proteinas','100g porcion',100,99,24.0,0.0,0.3,0.0,'USDA',ARRAY['CL','MX','CO','PE']),
('Sardinas en aceite','sardinas en aceite','Proteinas','1 lata (90g)',90,208,24.6,0.0,11.5,0.0,'USDA',ARRAY['CL','AR','PE']),
('Jamon de pavo','jamon de pavo','Proteinas','2 lonchas (50g)',50,107,16.5,1.5,3.5,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Jamon de cerdo','jamon de cerdo','Proteinas','2 lonchas (50g)',50,145,18.0,1.5,7.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Longaniza cocida','longaniza cocida','Proteinas','1 unidad (60g)',60,310,16.0,2.0,26.0,0.0,'INTA',ARRAY['CL','AR']),
('Chorizo cocido','chorizo cocido','Proteinas','1 unidad (60g)',60,325,15.0,2.5,27.5,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Carne de cordero cocida','carne de cordero cocida','Proteinas','100g porcion',100,258,25.0,0.0,16.5,0.0,'USDA',ARRAY['CL','AR','PE']),
('Higado de pollo','higado de pollo','Proteinas','100g porcion',100,167,24.5,0.9,6.5,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Higado de vacuno','higado de vacuno','Proteinas','100g porcion',100,175,29.0,3.9,5.0,0.0,'USDA',ARRAY['CL','AR','CO','PE']),
('Pavo a la plancha','pavo a la plancha','Proteinas','100g porcion',100,170,29.0,0.0,5.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pollo rostizado','pollo rostizado','Proteinas','100g porcion',100,239,27.0,0.0,13.8,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Carne asada parrilla','carne asada parrilla','Proteinas','100g porcion',100,220,28.5,0.0,11.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Albondigas de carne','albondigas de carne','Proteinas','3 unidades (90g)',90,235,18.0,8.0,14.5,0.5,'LATINFOODS',ARRAY['CL','AR','MX','CO','PE']),
('Porotos negros cocidos','porotos negros cocidos','Legumbres','1 taza cocida',172,132,8.9,23.7,0.5,8.7,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Porotos blancos cocidos','porotos blancos cocidos','Legumbres','1 taza cocida',179,139,9.7,25.1,0.4,10.5,'USDA',ARRAY['CL','AR','CO','PE']),
('Lentejas cocidas','lentejas cocidas','Legumbres','1 taza cocida',198,116,9.0,20.1,0.4,7.9,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Garbanzos cocidos','garbanzos cocidos','Legumbres','1 taza cocida',164,164,8.9,27.4,2.6,7.6,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Arvejas cocidas','arvejas cocidas','Legumbres','1 taza cocida',160,81,5.4,14.4,0.4,5.1,'USDA',ARRAY['CL','AR','CO','PE']),
('Habas cocidas','habas cocidas','Legumbres','1 taza cocida',170,110,7.9,19.7,0.4,9.0,'USDA',ARRAY['CL','AR','PE']),
('Soja/Soya cocida','soja soya cocida','Legumbres','1 taza cocida',172,173,16.6,9.9,9.0,5.2,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Edamame','edamame','Legumbres','1 taza',155,121,11.9,8.9,5.2,5.2,'USDA',ARRAY['CL','AR','MX']),
('Porotos colorados cocidos','porotos colorados cocidos','Legumbres','1 taza cocida',177,127,8.7,22.8,0.5,7.4,'USDA',ARRAY['CL','AR','CO','PE']),
('Porotos pintos cocidos','porotos pintos cocidos','Legumbres','1 taza cocida',171,143,9.0,26.8,0.7,7.7,'USDA',ARRAY['CL','MX','CO','PE']),
('Leche entera','leche entera','Lacteos','1 vaso (250ml)',250,61,3.2,4.8,3.3,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Leche descremada','leche descremada','Lacteos','1 vaso (250ml)',250,34,3.4,5.0,0.1,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Leche semidescremada','leche semidescremada','Lacteos','1 vaso (250ml)',250,46,3.3,4.9,1.6,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Yogur natural entero','yogur natural entero','Lacteos','1 pote (200g)',200,61,3.5,4.7,3.3,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Yogur natural descremado','yogur natural descremado','Lacteos','1 pote (200g)',200,56,4.0,7.7,0.4,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Yogur griego','yogur griego','Lacteos','1 pote (150g)',150,97,9.0,3.6,5.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Queso gauda','queso gauda','Lacteos','1 loncha (30g)',30,356,25.0,2.2,27.4,0.0,'INTA',ARRAY['CL','AR']),
('Queso mantecoso','queso mantecoso','Lacteos','1 porcion (30g)',30,380,22.0,1.5,32.0,0.0,'INTA',ARRAY['CL']),
('Queso fresco/cottage','queso fresco cottage','Lacteos','1 porcion (100g)',100,98,11.1,3.4,4.3,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Queso parmesano rallado','queso parmesano rallado','Lacteos','2 cdas (15g)',15,431,38.5,3.2,28.6,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Mantequilla','mantequilla','Lacteos','1 cucharadita (5g)',5,717,0.9,0.1,81.1,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Crema de leche','crema de leche','Lacteos','2 cdas (30ml)',30,345,2.0,2.8,37.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Leche condensada','leche condensada','Lacteos','2 cdas (30g)',30,321,7.9,54.4,8.7,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Queso crema','queso crema','Lacteos','1 porcion (30g)',30,342,6.0,4.1,34.4,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Helado de vainilla','helado de vainilla','Lacteos','1 bola (100g)',100,207,3.5,23.6,11.0,0.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Platano/Banana','platano banana','Frutas','1 unidad mediana (120g)',120,89,1.1,22.8,0.3,2.6,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Manzana','manzana','Frutas','1 unidad mediana (180g)',180,52,0.3,13.8,0.2,2.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Naranja','naranja','Frutas','1 unidad mediana (130g)',130,47,0.9,11.8,0.1,2.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pera','pera','Frutas','1 unidad mediana (180g)',180,57,0.4,15.2,0.1,3.1,'USDA',ARRAY['CL','AR','CO','PE']),
('Uva','uva','Frutas','1 taza (150g)',150,69,0.7,18.1,0.2,0.9,'USDA',ARRAY['CL','AR','PE']),
('Sandia','sandia','Frutas','1 tajada (300g)',300,30,0.6,7.6,0.2,0.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Melon','melon','Frutas','1 tajada (150g)',150,34,0.8,8.2,0.2,0.9,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Frutilla/Fresa','frutilla fresa','Frutas','1 taza (150g)',150,32,0.7,7.7,0.3,2.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Kiwi','kiwi','Frutas','1 unidad (75g)',75,61,1.1,14.7,0.5,3.0,'USDA',ARRAY['CL','AR']),
('Durazno/Melocoton','durazno melocoton','Frutas','1 unidad mediana (150g)',150,39,0.9,9.5,0.3,1.5,'USDA',ARRAY['CL','AR','CO','PE']),
('Ciruela','ciruela','Frutas','1 unidad (66g)',66,46,0.7,11.4,0.3,1.4,'USDA',ARRAY['CL','AR','PE']),
('Mango','mango','Frutas','1 taza (165g)',165,60,0.8,15.0,0.4,1.6,'USDA',ARRAY['CL','MX','CO','PE']),
('Pina/Anana','pina anana','Frutas','1 taza (165g)',165,50,0.5,13.1,0.1,1.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Limon','limon','Frutas','1 unidad (58g)',58,29,1.1,9.3,0.3,2.8,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Palta/Aguacate','palta aguacate','Frutas','1/2 unidad (100g)',100,160,2.0,8.5,14.7,6.7,'USDA',ARRAY['CL','MX','CO','PE']),
('Frambuesa','frambuesa','Frutas','1 taza (123g)',123,52,1.2,11.9,0.7,6.5,'USDA',ARRAY['CL','AR']),
('Arandano','arandano','Frutas','1 taza (148g)',148,57,0.7,14.5,0.3,2.4,'USDA',ARRAY['CL','AR']),
('Mandarina','mandarina','Frutas','1 unidad (88g)',88,53,0.8,13.3,0.3,1.8,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Papaya','papaya','Frutas','1 taza (140g)',140,43,0.5,10.8,0.3,1.7,'USDA',ARRAY['CL','MX','CO','PE']),
('Maracuya/Granadilla','maracuya granadilla','Frutas','1 unidad (35g)',35,97,2.2,23.4,0.7,10.4,'USDA',ARRAY['CL','CO','PE','MX']),
('Tomate','tomate','Verduras','1 tomate mediano (123g)',123,18,0.9,3.9,0.2,1.2,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Lechuga','lechuga','Verduras','1 taza (47g)',47,15,1.4,2.9,0.2,1.3,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Zanahoria','zanahoria','Verduras','1 zanahoria (61g)',61,41,0.9,9.6,0.2,2.8,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Cebolla','cebolla','Verduras','1/2 cebolla (80g)',80,40,1.1,9.3,0.1,1.7,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Ajo','ajo','Verduras','1 diente (3g)',3,149,6.4,33.1,0.5,2.1,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Brocoli','brocoli','Verduras','1 taza (91g)',91,34,2.8,6.6,0.4,2.6,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Coliflor','coliflor','Verduras','1 taza (107g)',107,25,1.9,5.3,0.1,2.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Espinaca','espinaca','Verduras','1 taza cruda (30g)',30,23,2.9,3.6,0.4,2.2,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pepino','pepino','Verduras','1/2 pepino (150g)',150,15,0.7,3.6,0.1,0.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pimenton rojo','pimenton rojo','Verduras','1 unidad (120g)',120,31,1.0,6.0,0.3,2.1,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Pimenton verde','pimenton verde','Verduras','1 unidad (120g)',120,20,0.9,4.6,0.2,1.7,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Repollo/Col','repollo col','Verduras','1 taza (89g)',89,25,1.3,5.8,0.1,2.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Zapallo/Calabaza','zapallo calabaza','Verduras','1 taza cocida (245g)',245,26,1.0,6.5,0.1,0.5,'USDA',ARRAY['CL','AR','CO','PE']),
('Papa/Patata cocida','papa patata cocida','Verduras','1 papa mediana (150g)',150,77,2.0,17.5,0.1,2.2,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Camote/Batata cocida','camote batata cocida','Verduras','1 unidad mediana (130g)',130,86,1.6,20.1,0.1,3.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Acelga','acelga','Verduras','1 taza cocida (175g)',175,20,1.9,4.1,0.1,1.6,'USDA',ARRAY['CL','AR','CO','PE']),
('Apio','apio','Verduras','1 tallo (40g)',40,16,0.7,3.0,0.2,1.6,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Champinon','champinon','Verduras','1 taza (70g)',70,22,3.1,3.3,0.3,1.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Choclo/Maiz dulce','choclo maiz dulce','Verduras','1 choclo (90g)',90,86,3.2,18.7,1.4,2.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Betarraga/Remolacha','betarraga remolacha','Verduras','1 taza cocida (170g)',170,44,1.7,9.6,0.2,2.0,'USDA',ARRAY['CL','AR','CO','PE']),
('Aceite de oliva','aceite de oliva','Grasas','1 cucharada (14g)',14,884,0.0,0.0,100.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Aceite vegetal/canola','aceite vegetal canola','Grasas','1 cucharada (14g)',14,884,0.0,0.0,100.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Mantequilla de mani','mantequilla de mani','Grasas','2 cucharadas (32g)',32,588,25.0,20.0,50.0,6.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Nueces','nueces','Grasas','1/4 taza (30g)',30,654,15.2,13.7,65.2,6.7,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Almendras','almendras','Grasas','1/4 taza (30g)',30,579,21.2,21.6,49.9,12.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Semillas de chia','semillas de chia','Grasas','2 cucharadas (28g)',28,486,16.5,42.1,30.7,34.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Semillas de linaza','semillas de linaza','Grasas','2 cucharadas (21g)',21,534,18.3,28.9,42.2,27.3,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Mani tostado sin sal','mani tostado sin sal','Grasas','1/4 taza (37g)',37,567,25.8,16.1,49.2,8.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Leche de almendras sin azucar','leche de almendras sin azucar','Bebidas','1 vaso (250ml)',250,17,0.6,0.3,1.5,0.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Jugo de naranja natural','jugo de naranja natural','Bebidas','1 vaso (250ml)',250,45,0.7,10.4,0.2,0.2,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Agua con gas','agua con gas','Bebidas','1 vaso (250ml)',250,0,0.0,0.0,0.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Te sin azucar','te sin azucar','Bebidas','1 taza (240ml)',240,1,0.0,0.3,0.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Cafe negro sin azucar','cafe negro sin azucar','Bebidas','1 taza (240ml)',240,2,0.3,0.0,0.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Mani tostado con sal','mani tostado con sal','Snacks','1 paquete (30g)',30,567,25.8,16.1,49.2,8.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Papas fritas de bolsa','papas fritas de bolsa','Snacks','1 bolsa (30g)',30,536,7.0,53.0,35.0,4.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Galletas Oreo','galletas oreo','Snacks','3 galletas (34g)',34,480,4.7,70.0,20.0,1.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Barra de cereal','barra de cereal','Snacks','1 barra (25g)',25,370,4.0,73.0,7.0,2.0,'LATINFOODS',ARRAY['CL','AR','MX','CO','PE']),
('Chocolate de leche','chocolate de leche','Snacks','1 cuadro (10g)',10,535,7.7,59.4,29.7,3.4,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Miel','miel','Snacks','1 cucharada (21g)',21,304,0.3,82.4,0.0,0.2,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Azucar blanca','azucar blanca','Snacks','1 cucharadita (4g)',4,387,0.0,100.0,0.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Azucar morena','azucar morena','Snacks','1 cucharadita (4g)',4,380,0.0,98.1,0.0,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Mermelada de fresa','mermelada de fresa','Snacks','1 cucharada (20g)',20,250,0.4,65.0,0.1,0.6,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Ketchup','ketchup','Snacks','1 cucharada (17g)',17,112,1.7,26.8,0.2,0.3,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Mayonesa','mayonesa','Snacks','1 cucharada (15g)',15,680,1.0,2.5,74.9,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Manjar/Dulce de leche','manjar dulce de leche','Snacks','1 cucharada (25g)',25,321,7.0,55.4,8.0,0.0,'INTA',ARRAY['CL','AR']),
('Empanada de pino al horno','empanada de pino al horno','Preparaciones','1 unidad (160g)',160,295,13.5,32.0,11.5,1.5,'INTA',ARRAY['CL','AR']),
('Empanada de queso','empanada de queso','Preparaciones','1 unidad (130g)',130,320,12.0,35.0,14.5,1.2,'INTA',ARRAY['CL','AR']),
('Cazuela de pollo','cazuela de pollo','Preparaciones','1 plato (400g)',400,95,8.5,10.0,2.0,1.8,'LATINFOODS',ARRAY['CL']),
('Cazuela de vacuno','cazuela de vacuno','Preparaciones','1 plato (400g)',400,110,9.5,10.5,3.5,1.8,'LATINFOODS',ARRAY['CL']),
('Charquican','charquican','Preparaciones','1 plato (300g)',300,145,9.0,18.0,4.5,3.0,'INTA',ARRAY['CL','PE']),
('Porotos con riendas','porotos con riendas','Preparaciones','1 plato (300g)',300,165,9.5,25.0,3.5,7.0,'INTA',ARRAY['CL']),
('Lentejas guisadas','lentejas guisadas','Preparaciones','1 plato (300g)',300,130,9.0,20.5,2.5,7.5,'LATINFOODS',ARRAY['CL','AR','MX','CO','PE']),
('Estofado de pollo','estofado de pollo','Preparaciones','1 plato (350g)',350,125,15.0,9.0,3.5,1.5,'LATINFOODS',ARRAY['CL','AR','PE']),
('Arroz con leche','arroz con leche','Preparaciones','1 porcion (200g)',200,130,3.5,24.0,3.0,0.3,'LATINFOODS',ARRAY['CL','AR','MX','CO','PE']),
('Sopaipilla','sopaipilla','Preparaciones','1 unidad (50g)',50,290,4.5,38.0,13.0,1.5,'INTA',ARRAY['CL']),
('Sopaipilla pasada','sopaipilla pasada','Preparaciones','1 unidad (60g)',60,265,4.0,45.0,8.0,1.2,'INTA',ARRAY['CL']),
('Mote con huesillos','mote con huesillos','Preparaciones','1 vaso (300ml)',300,110,1.5,26.0,0.3,1.0,'INTA',ARRAY['CL']),
('Ensalada chilena','ensalada chilena','Preparaciones','1 porcion (150g)',150,45,1.0,7.0,1.5,1.5,'INTA',ARRAY['CL']),
('Pebre','pebre','Preparaciones','2 cucharadas (40g)',40,35,0.8,5.5,1.0,1.0,'INTA',ARRAY['CL']),
('Humitas','humitas','Preparaciones','1 humita (150g)',150,155,3.5,25.0,4.5,2.5,'INTA',ARRAY['CL','PE']),
('Tamales chilenos','tamales chilenos','Preparaciones','1 tamal (200g)',200,185,8.0,24.0,6.5,2.0,'INTA',ARRAY['CL']),
('Pastel de choclo','pastel de choclo','Preparaciones','1 porcion (250g)',250,190,12.5,20.0,7.0,2.5,'INTA',ARRAY['CL']),
('Guatita','guatita','Preparaciones','1 plato (300g)',300,155,14.0,10.0,6.5,1.5,'INTA',ARRAY['CL']),
('Prietas/Morcilla','prietas morcilla','Preparaciones','1 unidad (80g)',80,378,16.5,2.0,33.0,0.0,'INTA',ARRAY['CL','AR']),
('Arrollado de chancho','arrollado de chancho','Preparaciones','1 porcion (80g)',80,240,18.0,1.5,18.0,0.0,'INTA',ARRAY['CL']),
('Caldo de pollo','caldo de pollo','Preparaciones','1 taza (240ml)',240,18,2.0,1.5,0.5,0.0,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Sopa de fideos','sopa de fideos','Preparaciones','1 plato (300ml)',300,65,2.5,12.0,1.0,0.5,'LATINFOODS',ARRAY['CL','AR','MX','CO','PE']),
('Pure de papas','pure de papas','Preparaciones','1 porcion (200g)',200,113,2.5,18.5,4.5,1.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Papas fritas caseras','papas fritas caseras','Preparaciones','1 porcion (150g)',150,312,3.4,39.8,15.0,3.5,'USDA',ARRAY['CL','AR','MX','CO','PE']),
('Noquis','noquis','Preparaciones','1 plato (200g)',200,130,3.5,26.0,1.5,1.0,'LATINFOODS',ARRAY['CL','AR']),
('Milanesa de pollo','milanesa de pollo','Preparaciones','1 unidad (150g)',150,230,24.0,10.0,10.0,0.5,'LATINFOODS',ARRAY['CL','AR','CO','PE']),
('Milanesa de carne','milanesa de carne','Preparaciones','1 unidad (150g)',150,255,25.0,10.0,13.0,0.5,'LATINFOODS',ARRAY['CL','AR','CO','PE']),
('Taco de pollo','taco de pollo','Preparaciones','1 taco armado (130g)',130,220,15.0,22.0,8.0,2.0,'LATINFOODS',ARRAY['MX','CL']),
('Burrito de frijoles','burrito de frijoles','Preparaciones','1 burrito (220g)',220,218,10.0,33.0,5.5,5.0,'LATINFOODS',ARRAY['MX','CL']),
('Completo/Hotdog','completo hotdog','Preparaciones','1 completo (180g)',180,310,11.5,32.0,15.5,1.5,'INTA',ARRAY['CL']);

  END IF;
END
$mig$;

-- 2) subscription_tier columna + trigger
-- Subscription tier para profiles (free / plus / premium)
-- Decision: usamos trigger BEFORE UPDATE para proteger los campos sensibles,
-- ya que la policy "profiles: update own" existente permite cualquier columna.
-- Reescribir esa policy con un USING+WITH CHECK con OLD/NEW no es posible en
-- Postgres (FOR UPDATE no expone OLD en WITH CHECK), por lo que la opcion mas
-- segura y minima invasiva es bloquear via trigger ante non-service-role.

alter table public.profiles
  add column if not exists subscription_tier text not null default 'free'
  check (subscription_tier in ('free','plus','premium'));

alter table public.profiles
  add column if not exists subscription_expires_at timestamptz;

-- Trigger que bloquea cambios a campos protegidos cuando el rol actual no es
-- service_role (es decir, viene del cliente con anon/authenticated key).
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
  end if;
  return new;
end;
$$;

drop trigger if exists trg_protect_subscription_fields on public.profiles;
create trigger trg_protect_subscription_fields
before update on public.profiles
for each row
execute function public.prevent_subscription_field_changes();


-- 3) profile_change_logs base
-- Log de cambios de campos restringidos por cuota anual (fitness_goal, training_location).
-- Usado por ChangeQuotaService para limitar a 4 cambios/anio a usuarios free.

create table if not exists public.profile_change_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  field text not null check (field in ('fitness_goal','training_location')),
  old_value text,
  new_value text,
  changed_at timestamptz not null default now()
);

create index if not exists profile_change_logs_user_year_idx
  on public.profile_change_logs (user_id, field, changed_at);

alter table public.profile_change_logs enable row level security;

drop policy if exists "profile_change_logs: select own" on public.profile_change_logs;
create policy "profile_change_logs: select own"
  on public.profile_change_logs
  for select
  using (auth.uid() = user_id);

drop policy if exists "profile_change_logs: insert own" on public.profile_change_logs;
create policy "profile_change_logs: insert own"
  on public.profile_change_logs
  for insert
  with check (auth.uid() = user_id);

-- UPDATE / DELETE: ninguna policy => prohibido para el cliente.


-- ===== MIS 12 NUEVAS =====
-- 20260518000001_water_logs.sql
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


-- 20260518000002_nutrition_goals.sql
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


-- 20260518000003_user_dietary_restrictions.sql
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


-- 20260518000004_user_recipes.sql
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


-- 20260518000005_ai_weekly_checkins.sql
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


-- 20260518000006_workout_feedback.sql
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


-- 20260518000007_ai_monthly_summaries.sql
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


-- 20260518000008_ai_trainer_config.sql
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


-- 20260518000009_ai_trainer_messages.sql
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


-- 20260518000010_profile_change_logs_routine_ai.sql
-- Agrega 'routine_ai_change' al check constraint de profile_change_logs.field.
-- Permite contar regeneraciones del plan IA dentro de la cuota anual combinada.

alter table public.profile_change_logs
  drop constraint if exists profile_change_logs_field_check;

alter table public.profile_change_logs
  add constraint profile_change_logs_field_check
  check (field in ('fitness_goal','training_location','routine_ai_change'));


-- 20260518000011_subscription_variant.sql
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


-- 20260518000012_monthly_report_cron.sql
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


