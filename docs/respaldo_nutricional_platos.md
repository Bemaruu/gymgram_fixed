# Respaldo nutricional — catálogo de alimentos

Documento de respaldo para el catálogo `custom_foods` de GymGram. Lista fuentes,
niveles de confianza y pendientes de sign-off humano antes del piloto académico.

Última actualización: 2026-06-12.

## Estructura

`custom_foods` guarda macros por 100 g:
- `kcal_per_100g`, `protein_per_100g`, `carbs_per_100g`, `fat_per_100g`, `fiber_per_100g`
- `sodium_mg_per_100g`, `sugar_per_100g`, `sat_fat_per_100g` (agregadas 2026-06-12)
- `country_relevance text[]`, `popular_in text[]` (cotidianos por país)
- `ai_exclude_from_plan boolean` (bloqueados para el plan IA)
- `source text` — categoría de origen del dato

## Fuentes por familia

| Familia | `source` | Fuente real | Nivel de confianza |
|---|---|---|---|
| Frutas y verduras frescas | `USDA` | USDA FoodData Central (SR Legacy) | Alta — base reconocida internacionalmente |
| Cereales, legumbres genéricas, lácteos básicos | `USDA` | USDA FoodData Central | Alta |
| Pan local (marraqueta, hallulla, amasado), galletas de agua, manjar | `INTA` | Tabla de Composición de Alimentos INTA Universidad de Chile (3.ª ed., 2010) | Alta para CL |
| Recetas chilenas (cazuela, charquicán, porotos con riendas, pastel de choclo, humitas, mote con huesillos, sopaipillas, plateada) | `INTA` | Tablas INTA + reconstrucción por ingredientes promedio | Media-alta — receta-tipo, no medición lab |
| Recetas LATAM (lomo saltado, ají de gallina, ceviche, arroz chaufa, bandeja paisa, ajiaco, arepa, chilaquiles, mole, pozole, tamales, enchiladas) | `LATINFOODS` | Red LATINFOODS (FAO) + reconstrucción por ingredientes | Media — aproximación de receta promedio del país |
| Recetas argentinas/uruguayas (milanesa napolitana, suprema, ñoquis, lasagna, canelones, asado, choripán) | `LATINFOODS` | LATINFOODS + reconstrucción por ingredientes | Media — receta-tipo |
| Recetas españolas (tortilla, paella, gazpacho, bocadillo de jamón) | `USDA` | USDA + reconstrucción típica | Media |
| Marcas comerciales de bebidas (Coca-Cola, Pepsi, Sprite, Fanta, Monster, Red Bull, Powerade, Gatorade) | `LABEL` | Etiqueta nutricional oficial pública del producto | Alta — declaración del fabricante |
| Marcas comerciales de snacks (Snickers, KitKat, Twix, M&Ms, Pringles, Doritos, Cheetos, Tritón, Frac, Obsesión, Sahne Nuss, Calaf, Super 8, Sublime, Sahne Nuss, Chocman) | `LABEL` | Etiqueta nutricional oficial pública | Alta |
| Marcas lácteas (Soprole, Colun, Danone Activia) | `LABEL` | Etiqueta oficial | Alta |
| Marcas cereales (Corn Flakes, Zucaritas, Chocapic, Milo, Quaker) | `LABEL` | Etiqueta oficial | Alta |
| Comida rápida internacional (Big Mac, Cuarto de Libra, McNuggets, Whopper, KFC, Pizza Hut, Domino's, Subway, Starbucks) | `LABEL` | Información oficial publicada por cada cadena | Alta — pero bloqueada del plan IA por `ai_exclude_from_plan = true` |
| Suplementos (whey, barras Quest/BIO) | `LABEL` | Etiqueta oficial | Alta |

## Disclaimer mostrado al usuario

Texto en `lib/ui/main_screens/alimentacion_screen.dart` (constante `_disclaimerText`):

> "Estimación nutricional. No reemplaza la asesoría de un nutricionista o
> médico. Marcas comerciales: macros de etiqueta oficial. Platos caseros:
> aproximación basada en tablas INTA/LATINFOODS."

## Reglas de seguridad implementadas en el plan IA (`generate-nutrition-plan`)

Ver `supabase/functions/generate-nutrition-plan/index.ts`. Resumen:

- Pisos calóricos: 1300 (M) / 1500 (H) — validado con nutricionista 2026-06-08.
- Macros con pisos duros (carbs ≥ 40 % kcal, grasas ≥ 20 % kcal).
- Proteína 1.8 g/kg base, hasta 2.0 g/kg en pérdida/recomp/ganancia (ISSN 2017, Jäger et al.).
- Fibra ≥ 14 g por cada 1000 kcal (NIH DRI / IOM).
- Sodio ≤ 2300 mg/día base, ≤ 1500 mg si hipertensión declarada (NIH DRI / AHA).
- Timing pre/post entreno cuando aplica (ACSM Position Stand 2017, Thomas/Erdman/Burke):
  - pre_workout: ~1 g/kg CHO, P 10-20 g, grasa < 10 g.
  - post_workout: 1.0-1.2 g/kg CHO + ≥ 0.3 g/kg proteína.
- Hidratación: 35 ml/kg + 500 ml por sesión de entreno promediada en la semana (ACSM).
- Modo seguro TCA (SCOFF positivo / `eating_disorder_risk`): override silencioso a mantenimiento, sin lenguaje restrictivo.
- Bloqueo del plan IA: fast food internacional, bebidas alcohólicas (cervezas, vino, pisco). Siguen disponibles en el buscador para registro manual.
- Warning vegano B12 obligatorio cuando `food_preferences` incluye 'vegan' (DRI NIH + Academy of Nutrition and Dietetics 2016).

## Pendiente humano antes del piloto universitario (100-600 usuarios)

1. **Sign-off escrito** del nutricionista de la Universidad sobre los 80+ platos
   añadidos en la migración `20260612000002_food_catalog_expansion_v2.sql`
   y los 60+ campos sodio/azúcar/sat_fat rellenados.
2. Revisión y aprobación del texto del disclaimer y del warning B12 vegano.
3. Sign-off del kinesiólogo / profe de Ed. Física sobre las reglas timing pre/post entreno.
4. Acuerdo formal sobre cómo se cita "tablas INTA/LATINFOODS" en el copy público.

## Citas formales

- USDA FoodData Central. https://fdc.nal.usda.gov/
- INTA Universidad de Chile. Tabla de Composición de Alimentos, 3.ª ed., 2010.
- LATINFOODS (FAO). Red Latinoamericana de Composición de Alimentos.
- ACSM Position Stand: Nutrition and Athletic Performance. *Med Sci Sports Exerc*. 2016;48(3):543-568. Thomas DT, Erdman KA, Burke LM.
- ISSN Position Stand: Protein and exercise. *J Int Soc Sports Nutr*. 2017;14:20. Jäger R, et al.
- NIH Office of Dietary Supplements. Dietary Reference Intakes (DRI), tablas oficiales.
- American Heart Association. Sodium and salt — recomendación 1500 mg/día en hipertensión.
- Academy of Nutrition and Dietetics. Position: Vegetarian Diets. *J Acad Nutr Diet*. 2016;116(12):1970-1980.
