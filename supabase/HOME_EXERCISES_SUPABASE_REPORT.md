# Reporte para implementar en Supabase: ejercicios de casa, cardio y deportes

## Archivos tocados

- `supabase/migrations/20260524000001_home_exercises_and_sports_catalog.sql`
- `lib/services/exercise_service.dart`

## Objetivo

Enriquecer `public.exercise_catalog` con una cantidad importante de ejercicios para casa y actividades fisicas/deportivas, para que la IA pueda recomendar rutinas considerando:

- lugar de entrenamiento: `home` / `both`
- grupo muscular principal
- grupos secundarios
- implementos necesarios
- tipo de ejercicio
- nivel requerido
- descripcion operativa en `tips`

## Migracion agregada

Archivo:

`supabase/migrations/20260524000001_home_exercises_and_sports_catalog.sql`

La migracion hace `insert into public.exercise_catalog (...) values (...) on conflict (slug) do update`, por lo que es idempotente.

Columnas usadas:

- `name_es`
- `slug`
- `muscle_group_primary`
- `muscle_group_secondary`
- `location`
- `equipment`
- `exercise_type`
- `difficulty`
- `tips`

No modifica schema ni RLS.

## Contenido agregado

Total nuevo en la migracion: 87 entradas.

Por ubicacion:

- `home`: 68
- `both`: 19

Por categoria principal:

- Pecho: 6
- Espalda: 8
- Hombros: 5
- Bíceps: 4
- Tríceps: 4
- Cuádriceps: 8
- Femoral: 6
- Glúteos: 5
- Pantorrillas: 3
- Lumbar: 3
- Core: 7
- Cardio: 16
- Deportes: 12

## Actividades y deportes incluidos

Cardio / actividad fisica:

- Caminar
- Caminata rapida
- Trotar
- Correr
- Sprints
- Bicicleta
- Bicicleta estatica
- Saltar la cuerda
- Jumping jacks
- High knees
- Burpees
- Shadow boxing
- Baile cardio
- Subir escaleras
- Senderismo
- Remo indoor

Deportes:

- Futbol
- Basquetbol
- Tenis
- Padel
- Voleibol
- Natacion
- Boxeo recreativo
- Artes marciales
- Yoga
- Pilates
- Escalada indoor
- Patinaje

## Cambio en Flutter

Archivo:

`lib/services/exercise_service.dart`

Se agregaron dos filtros al arreglo `muscleGroups`:

- `Cardio`
- `Deportes`

Esto permite que el catalogo pueda filtrar las nuevas actividades desde la UI que usa `ExerciseService.getExercises`.

## Validaciones hechas localmente

Sobre la migracion nueva:

- slugs duplicados: 0
- `exercise_type` invalidos: 0
- `difficulty` invalidos: 0
- `location` invalidos: 0

`flutter analyze` y `dart analyze lib/services/exercise_service.dart` fueron intentados, pero quedaron colgados por timeout. No devolvieron error util.

## Revision de Claude (encoding y consistencia) — RESUELTO

El "mojibake" reportado era solo visual de la consola PowerShell. Ambos archivos
(`...home_exercises_and_sports_catalog.sql` y `exercise_service.dart`) estan en
UTF-8 limpio.

Verificado:

1. `muscle_group_primary` de la migracion nueva coincide EXACTO con el catalogo
   original y con los labels de Flutter:
   - `Bíceps`, `Tríceps`, `Cuádriceps`, `Glúteos` (todos con tilde, identicos).
   - `Cardio` y `Deportes` agregados correctamente al filtro Flutter.

2. Bug encontrado y arreglado: los grupos **secundarios** de la migracion nueva
   estaban SIN tilde (`"Triceps"`, `"Biceps"`, `"Gluteos"`, `"Cuadriceps"`),
   mientras el catalogo original los usa CON tilde. Esto habria generado chips
   duplicados en cualquier UI que muestre grupos secundarios. Normalizados a:
   `"Tríceps"`, `"Bíceps"`, `"Glúteos"`, `"Cuádriceps"`.
   No afecta `generate-routine` (solo usa `muscle_group_primary` en el prompt),
   pero se corrige por consistencia de datos.

Checklist de verificacion (opcional, post-aplicacion):

```sql
select distinct muscle_group_primary
from public.exercise_catalog
order by muscle_group_primary;
```

Confirmar que no aparezcan valores duplicados por encoding y que `Cardio` /
`Deportes` devuelvan resultados desde la app.

## SQL de verificacion post-migracion

```sql
select location, count(*)
from public.exercise_catalog
where slug in (
  select slug
  from public.exercise_catalog
  where slug in (
    'flexiones-inclinadas',
    'remo-con-mochila',
    'sentadilla-a-silla',
    'caminar',
    'futbol'
  )
)
group by location
order by location;
```

```sql
select muscle_group_primary, count(*)
from public.exercise_catalog
where location in ('home', 'both')
group by muscle_group_primary
order by muscle_group_primary;
```

```sql
select slug, name_es, location, muscle_group_primary, equipment, exercise_type, difficulty, tips
from public.exercise_catalog
where slug in (
  'remo-con-mochila',
  'curl-femoral-toalla',
  'caminar',
  'correr',
  'futbol',
  'basquetbol'
)
order by slug;
```

## Recomendacion para aplicar

Aplicar la migracion nueva en Supabase con el flujo normal del proyecto.

Despues de aplicar:

- revisar que no haya categorias duplicadas por tilde/codificacion
- revisar que `home` muestre muchos mas ejercicios
- revisar que `Cardio` y `Deportes` sean filtrables desde la app
- si hay errores de encoding, corregir los labels en la migracion o en el servicio Flutter para que ambos lados coincidan
