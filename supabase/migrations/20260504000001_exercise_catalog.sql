-- exercise_catalog: catálogo maestro de ejercicios pre-cargados en español
create table public.exercise_catalog (
  id                     uuid primary key default gen_random_uuid(),
  name_es                text not null,
  slug                   text unique not null,
  muscle_group_primary   text not null,
  muscle_group_secondary text[] default '{}',
  location               text not null check (location in ('gym', 'home', 'both')),
  equipment              text[] default '{}',
  exercise_type          text not null check (exercise_type in ('compuesto', 'aislamiento', 'estabilizacion', 'explosivo', 'cardio')),
  difficulty             text not null check (difficulty in ('principiante', 'intermedio', 'avanzado')),
  tips                   text,
  is_active              boolean default true,
  created_at             timestamptz default now()
);

create index idx_exercise_catalog_muscle   on public.exercise_catalog (muscle_group_primary);
create index idx_exercise_catalog_location on public.exercise_catalog (location);
create index idx_exercise_catalog_filter   on public.exercise_catalog (muscle_group_primary, location, difficulty) where is_active = true;

-- Full-text search en español
create index idx_exercise_catalog_fts on public.exercise_catalog
  using gin (to_tsvector('spanish', name_es));

-- RLS
alter table public.exercise_catalog enable row level security;

create policy "exercise_catalog_read" on public.exercise_catalog
  for select to authenticated using (is_active = true);

-- SEED: ~80 ejercicios curados
insert into public.exercise_catalog
  (name_es, slug, muscle_group_primary, muscle_group_secondary, location, equipment, exercise_type, difficulty)
values
-- PECHO
('Press de banca con barra',          'press-banca-barra',              'Pecho',       '{"Tríceps","Hombros"}',            'gym',  '{"barra","banco"}',                     'compuesto',    'intermedio'),
('Press inclinado con mancuernas',    'press-inclinado-mancuernas',     'Pecho',       '{"Tríceps","Hombros"}',            'gym',  '{"mancuernas","banco inclinado"}',       'compuesto',    'principiante'),
('Press declinado con barra',         'press-declinado-barra',          'Pecho',       '{"Tríceps"}',                      'gym',  '{"barra","banco declinado"}',            'compuesto',    'intermedio'),
('Aperturas en máquina (pec deck)',   'aperturas-pec-deck',             'Pecho',       '{}',                               'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Crossover en polea alta',           'crossover-polea-alta',           'Pecho',       '{}',                               'gym',  '{"cables"}',                            'aislamiento',  'principiante'),
('Aperturas en polea baja',           'aperturas-polea-baja',           'Pecho',       '{}',                               'gym',  '{"cables"}',                            'aislamiento',  'principiante'),
('Press de pecho en máquina',         'press-pecho-maquina',            'Pecho',       '{"Tríceps"}',                      'gym',  '{"máquina"}',                           'compuesto',    'principiante'),
('Flexiones',                         'flexiones',                      'Pecho',       '{"Tríceps","Hombros"}',            'both', '{"cuerpo"}',                            'compuesto',    'principiante'),
('Flexiones con pies elevados',       'flexiones-pies-elevados',        'Pecho',       '{"Tríceps"}',                      'home', '{"cuerpo"}',                            'compuesto',    'intermedio'),
('Flexiones diamante',                'flexiones-diamante',             'Tríceps',     '{"Pecho"}',                        'home', '{"cuerpo"}',                            'compuesto',    'intermedio'),
-- ESPALDA
('Dominadas agarre ancho',            'dominadas-agarre-ancho',         'Espalda',     '{"Bíceps"}',                       'both', '{"barra fija"}',                        'compuesto',    'intermedio'),
('Jalón al pecho agarre ancho',       'jalon-pecho-agarre-ancho',       'Espalda',     '{"Bíceps"}',                       'gym',  '{"polea alta"}',                        'compuesto',    'principiante'),
('Jalón agarre neutro',               'jalon-agarre-neutro',            'Espalda',     '{"Bíceps"}',                       'gym',  '{"polea alta"}',                        'compuesto',    'principiante'),
('Remo con barra',                    'remo-barra',                     'Espalda',     '{"Bíceps"}',                       'gym',  '{"barra"}',                             'compuesto',    'intermedio'),
('Remo con mancuerna unilateral',     'remo-mancuerna-unilateral',      'Espalda',     '{"Bíceps"}',                       'gym',  '{"mancuerna","banco"}',                 'compuesto',    'principiante'),
('Remo en máquina Hammer',            'remo-maquina-hammer',            'Espalda',     '{"Bíceps"}',                       'gym',  '{"máquina"}',                           'compuesto',    'principiante'),
('Remo en T-bar',                     'remo-t-bar',                     'Espalda',     '{"Bíceps"}',                       'gym',  '{"t-bar"}',                             'compuesto',    'intermedio'),
('Remo Pendlay',                      'remo-pendlay',                   'Espalda',     '{"Bíceps"}',                       'gym',  '{"barra"}',                             'compuesto',    'avanzado'),
('Australian pull-ups',               'australian-pull-ups',            'Espalda',     '{"Bíceps"}',                       'home', '{"mesa o barra baja"}',                 'compuesto',    'principiante'),
('Superman con brazos extendidos',    'superman-brazos-extendidos',     'Lumbar',      '{"Glúteos"}',                      'home', '{"cuerpo"}',                            'aislamiento',  'principiante'),
-- HOMBROS
('Press militar con barra',           'press-militar-barra',            'Hombros',     '{"Tríceps"}',                      'gym',  '{"barra"}',                             'compuesto',    'intermedio'),
('Press Arnold con mancuernas',       'press-arnold-mancuernas',        'Hombros',     '{"Tríceps"}',                      'gym',  '{"mancuernas"}',                        'compuesto',    'principiante'),
('Press de hombros en máquina',       'press-hombros-maquina',          'Hombros',     '{"Tríceps"}',                      'gym',  '{"máquina"}',                           'compuesto',    'principiante'),
('Elevaciones laterales con mancuernas', 'elevaciones-laterales-mancuernas', 'Hombros','{}',                              'gym',  '{"mancuernas"}',                        'aislamiento',  'principiante'),
('Elevaciones frontales con mancuernas', 'elevaciones-frontales-mancuernas', 'Hombros','{}',                              'gym',  '{"mancuernas"}',                        'aislamiento',  'principiante'),
('Face pulls en polea',               'face-pulls-polea',               'Hombros',     '{"Hombros post."}',                'gym',  '{"cables","cuerda"}',                   'aislamiento',  'principiante'),
('Pájaros con mancuernas',            'pajaros-mancuernas',             'Hombros',     '{}',                               'gym',  '{"mancuernas"}',                        'aislamiento',  'principiante'),
('Flexiones pike',                    'flexiones-pike',                 'Hombros',     '{"Tríceps"}',                      'home', '{"cuerpo"}',                            'compuesto',    'principiante'),
('Elevaciones laterales con botellas','elevaciones-laterales-botellas', 'Hombros',     '{}',                               'home', '{"botellas"}',                          'aislamiento',  'principiante'),
('Press overhead con botellas',       'press-overhead-botellas',        'Hombros',     '{"Tríceps"}',                      'home', '{"botellas"}',                          'compuesto',    'principiante'),
-- BÍCEPS
('Curl con barra recta',              'curl-barra-recta',               'Bíceps',      '{}',                               'gym',  '{"barra"}',                             'aislamiento',  'principiante'),
('Curl con barra EZ',                 'curl-barra-ez',                  'Bíceps',      '{}',                               'gym',  '{"barra EZ"}',                          'aislamiento',  'principiante'),
('Curl con mancuernas alternado',     'curl-mancuernas-alternado',      'Bíceps',      '{}',                               'gym',  '{"mancuernas"}',                        'aislamiento',  'principiante'),
('Curl martillo con mancuernas',      'curl-martillo-mancuernas',       'Bíceps',      '{}',                               'gym',  '{"mancuernas"}',                        'aislamiento',  'principiante'),
('Curl concentrado',                  'curl-concentrado',               'Bíceps',      '{}',                               'gym',  '{"mancuerna"}',                         'aislamiento',  'principiante'),
('Curl en polea baja',                'curl-polea-baja',                'Bíceps',      '{}',                               'gym',  '{"cable"}',                             'aislamiento',  'principiante'),
('Curl Zottman',                      'curl-zottman',                   'Bíceps',      '{}',                               'gym',  '{"mancuernas"}',                        'aislamiento',  'intermedio'),
('Chin-ups',                          'chin-ups',                       'Bíceps',      '{"Espalda"}',                      'both', '{"barra fija"}',                        'compuesto',    'intermedio'),
('Curl de bíceps con mochila',        'curl-biceps-mochila',            'Bíceps',      '{}',                               'home', '{"mochila"}',                           'aislamiento',  'principiante'),
('Curl concentrado con botella',      'curl-concentrado-botella',       'Bíceps',      '{}',                               'home', '{"botella"}',                           'aislamiento',  'principiante'),
-- TRÍCEPS
('Press francés con EZ',              'press-frances-ez',               'Tríceps',     '{}',                               'gym',  '{"barra EZ","banco"}',                  'aislamiento',  'intermedio'),
('Extensión tríceps en polea alta (cuerda)', 'extension-triceps-polea-cuerda', 'Tríceps','{}',                            'gym',  '{"cable"}',                             'aislamiento',  'principiante'),
('Extensión tríceps sobre cabeza en polea',  'extension-triceps-sobre-cabeza-polea', 'Tríceps','{}',                      'gym',  '{"cable"}',                             'aislamiento',  'principiante'),
('Fondos en paralelas',               'fondos-paralelas',               'Tríceps',     '{"Pecho"}',                        'gym',  '{"paralelas"}',                         'compuesto',    'intermedio'),
('Kickbacks de tríceps con mancuerna','kickbacks-triceps-mancuerna',    'Tríceps',     '{}',                               'gym',  '{"mancuerna"}',                         'aislamiento',  'principiante'),
('Fondos asistidos en máquina',       'fondos-asistidos-maquina',       'Tríceps',     '{}',                               'gym',  '{"máquina"}',                           'compuesto',    'principiante'),
('Dips entre sillas',                 'dips-entre-sillas',              'Tríceps',     '{"Pecho"}',                        'home', '{"2 sillas"}',                          'compuesto',    'principiante'),
('Extensión tríceps con botella',     'extension-triceps-botella',      'Tríceps',     '{}',                               'home', '{"botella"}',                           'aislamiento',  'principiante'),
-- CUÁDRICEPS
('Sentadilla libre con barra',        'sentadilla-libre-barra',         'Cuádriceps',  '{"Glúteos","Femoral"}',            'gym',  '{"barra"}',                             'compuesto',    'intermedio'),
('Sentadilla en Smith',               'sentadilla-smith',               'Cuádriceps',  '{"Glúteos"}',                      'gym',  '{"smith machine"}',                     'compuesto',    'principiante'),
('Prensa de piernas 45°',             'prensa-piernas-45',              'Cuádriceps',  '{"Glúteos"}',                      'gym',  '{"máquina"}',                           'compuesto',    'principiante'),
('Hack squat',                        'hack-squat',                     'Cuádriceps',  '{}',                               'gym',  '{"máquina"}',                           'compuesto',    'intermedio'),
('Extensión de cuádriceps',           'extension-cuadriceps',           'Cuádriceps',  '{}',                               'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Sentadilla búlgara',                'sentadilla-bulgara',             'Cuádriceps',  '{"Glúteos"}',                      'both', '{"banco o silla"}',                     'compuesto',    'intermedio'),
('Zancadas caminando',                'zancadas-caminando',             'Cuádriceps',  '{"Glúteos","Femoral"}',            'both', '{"cuerpo o mancuernas"}',               'compuesto',    'principiante'),
('Goblet squat',                      'goblet-squat',                   'Cuádriceps',  '{"Glúteos"}',                      'both', '{"mancuerna o kettlebell"}',            'compuesto',    'principiante'),
('Sentadilla con salto',              'sentadilla-salto',               'Cuádriceps',  '{"Glúteos"}',                      'home', '{"cuerpo"}',                            'explosivo',    'intermedio'),
('Step-ups en banco',                 'step-ups-banco',                 'Cuádriceps',  '{"Glúteos"}',                      'both', '{"banco o silla"}',                     'compuesto',    'principiante'),
-- FEMORAL
('Peso muerto rumano con barra',      'peso-muerto-rumano-barra',       'Femoral',     '{"Glúteos","Lumbar"}',             'gym',  '{"barra"}',                             'compuesto',    'intermedio'),
('Peso muerto rumano con mancuernas', 'peso-muerto-rumano-mancuernas',  'Femoral',     '{"Glúteos"}',                      'gym',  '{"mancuernas"}',                        'compuesto',    'principiante'),
('Curl femoral acostado',             'curl-femoral-acostado',          'Femoral',     '{}',                               'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Curl femoral sentado',              'curl-femoral-sentado',           'Femoral',     '{}',                               'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Good mornings con barra',           'good-mornings-barra',            'Lumbar',      '{"Femoral"}',                      'gym',  '{"barra"}',                             'compuesto',    'avanzado'),
('Peso muerto convencional',          'peso-muerto-convencional',       'Cadena posterior','{"Femoral","Glúteos","Lumbar","Espalda"}','gym','{"barra"}',                    'compuesto',    'avanzado'),
('Nordic curl modificado',            'nordic-curl-modificado',         'Femoral',     '{}',                               'home', '{"cuerpo"}',                            'compuesto',    'avanzado'),
('Peso muerto unipodal',              'peso-muerto-unipodal',           'Femoral',     '{"Glúteos"}',                      'both', '{"cuerpo o mancuerna"}',               'compuesto',    'intermedio'),
-- GLÚTEOS
('Hip thrust con barra',              'hip-thrust-barra',               'Glúteos',     '{"Femoral"}',                      'gym',  '{"barra","banco"}',                     'compuesto',    'intermedio'),
('Puente de glúteos con barra',       'puente-gluteos-barra',           'Glúteos',     '{}',                               'gym',  '{"barra"}',                             'compuesto',    'principiante'),
('Kickback en polea baja',            'kickback-polea-baja',            'Glúteos',     '{}',                               'gym',  '{"cable"}',                             'aislamiento',  'principiante'),
('Abductor en máquina',               'abductor-maquina',               'Glúteos',     '{}',                               'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Sentadilla sumo con mancuerna',     'sentadilla-sumo-mancuerna',      'Glúteos',     '{"Cuádriceps","Femoral"}',         'gym',  '{"mancuerna"}',                         'compuesto',    'principiante'),
('Hip thrust con peso corporal',      'hip-thrust-peso-corporal',       'Glúteos',     '{}',                               'home', '{"cuerpo"}',                            'compuesto',    'principiante'),
('Kickback en cuadrupedia',           'kickback-cuadrupedia',           'Glúteos',     '{}',                               'home', '{"cuerpo"}',                            'aislamiento',  'principiante'),
('Fire hydrant',                      'fire-hydrant',                   'Glúteos',     '{}',                               'home', '{"cuerpo"}',                            'aislamiento',  'principiante'),
('Clamshell',                         'clamshell',                      'Glúteos',     '{}',                               'home', '{"cuerpo o banda"}',                    'aislamiento',  'principiante'),
('Frog pumps',                        'frog-pumps',                     'Glúteos',     '{}',                               'home', '{"cuerpo"}',                            'aislamiento',  'principiante'),
-- PANTORRILLAS
('Elevación de pantorrillas de pie en máquina', 'elevacion-pantorrillas-maquina','Pantorrillas','{}',                     'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Elevación de pantorrillas sentado', 'elevacion-pantorrillas-sentado', 'Pantorrillas', '{}',                              'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Pantorrillas en prensa',            'pantorrillas-prensa',            'Pantorrillas', '{}',                              'gym',  '{"máquina"}',                           'aislamiento',  'principiante'),
('Pantorrillas de pie (unipodal)',     'pantorrillas-pie-unipodal',      'Pantorrillas', '{}',                              'home', '{"escalón"}',                           'aislamiento',  'principiante'),
-- CORE
('Plancha frontal',                   'plancha-frontal',                'Core',         '{}',                              'both', '{"cuerpo"}',                            'estabilizacion','principiante'),
('Plancha lateral',                   'plancha-lateral',                'Core',         '{}',                              'both', '{"cuerpo"}',                            'estabilizacion','principiante'),
('Crunch en polea',                   'crunch-polea',                   'Core',         '{}',                              'gym',  '{"cable"}',                             'aislamiento',  'principiante'),
('Elevación de piernas colgado',      'elevacion-piernas-colgado',      'Core',         '{}',                              'gym',  '{"barra fija"}',                        'compuesto',    'intermedio'),
('Crunch bicicleta',                  'crunch-bicicleta',               'Core',         '{}',                              'home', '{"cuerpo"}',                            'aislamiento',  'principiante'),
('Mountain climbers',                 'mountain-climbers',              'Core',         '{}',                              'home', '{"cuerpo"}',                            'cardio',       'principiante'),
('Dead bug',                          'dead-bug',                       'Core',         '{}',                              'home', '{"cuerpo"}',                            'estabilizacion','principiante'),
('Russian twist',                     'russian-twist',                  'Core',         '{}',                              'home', '{"cuerpo o botella"}',                  'aislamiento',  'principiante');
