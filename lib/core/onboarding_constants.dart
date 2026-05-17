// Catálogos cerrados del onboarding. Cada opción tiene valor interno estable
// (snake_case en inglés o UPPERCASE para los legacy) y un label visible en español.
//
// Importante: los valores legacy (gender, fitness_goal, training_location)
// se mantienen en UPPERCASE para no romper a los consumidores actuales
// (nutrition_calculator, perfil_screen, alimentacion_screen).
// Los campos nuevos usan lowercase_snake_case.

class ChipOption {
  final String value;
  final String label;
  const ChipOption(this.value, this.label);
}

class OnboardingCatalogs {
  OnboardingCatalogs._();

  // ── Legacy (UPPERCASE para compatibilidad downstream) ───────────────────
  static const gender = <ChipOption>[
    ChipOption('MALE', 'Hombre'),
    ChipOption('FEMALE', 'Mujer'),
    ChipOption('OTHER', 'Otro'),
    ChipOption('PREFER_NOT_TO_SAY', 'Prefiero no decir'),
  ];

  static const fitnessGoal = <ChipOption>[
    ChipOption('LOSE_WEIGHT', 'Perder grasa'),
    ChipOption('GAIN_MUSCLE', 'Ganar masa muscular'),
    ChipOption('RECOMPOSITION', 'Recomposición corporal'),
    ChipOption('MAINTAIN', 'Mantenerme sano'),
    ChipOption('IMPROVE_ENDURANCE', 'Mejorar resistencia'),
    ChipOption('TONE_BODY', 'Tonificar'),
  ];

  static const trainingLocation = <ChipOption>[
    ChipOption('HOME', 'En casa'),
    ChipOption('GYM', 'Gimnasio'),
    ChipOption('OUTDOOR', 'Aire libre'),
    ChipOption('HYBRID', 'Mixto'),
  ];

  // ── Nuevos (lowercase_snake_case) ───────────────────────────────────────
  static const trainingLevel = <ChipOption>[
    ChipOption('beginner', 'Nuevo / Principiante'),
    ChipOption('intermediate_lt_1y', 'Menos de 1 año entrenando'),
    ChipOption('intermediate_1y_3y', 'Entre 1 y 3 años'),
    ChipOption('advanced_gt_3y', 'Más de 3 años'),
  ];

  static const experiencePath = <ChipOption>[
    ChipOption('analyze_existing_routine', 'Quiero analizar mi rutina actual'),
    ChipOption('create_ai_routine', 'Quiero que GymGram cree una rutina para mí'),
  ];

  static const equipment = <ChipOption>[
    ChipOption('bodyweight', 'Peso corporal'),
    ChipOption('dumbbells', 'Mancuernas'),
    ChipOption('barbell', 'Barra'),
    ChipOption('machines', 'Máquinas'),
    ChipOption('bands', 'Bandas elásticas'),
    ChipOption('kettlebell', 'Kettlebells'),
    ChipOption('cardio_machines', 'Máquinas de cardio'),
    ChipOption('pullup_bar', 'Barra de dominadas'),
    ChipOption('full_gym', 'Gimnasio completo'),
  ];

  static const sessionDuration = <ChipOption>[
    ChipOption('20', '20 minutos'),
    ChipOption('30', '30 minutos'),
    ChipOption('45', '45 minutos'),
    ChipOption('60', '1 hora'),
    ChipOption('90', '1 hora y media'),
  ];

  static const routineSplit = <ChipOption>[
    ChipOption('full_body', 'Cuerpo completo'),
    ChipOption('upper_lower', 'Tren superior / inferior'),
    ChipOption('push_pull_legs', 'Push - Pull - Legs'),
    ChipOption('bro_split', 'Una zona por día'),
    ChipOption('no_preference', 'Sin preferencia'),
  ];

  static const injuries = <ChipOption>[
    ChipOption('none', 'Ninguna'),
    ChipOption('knee', 'Rodilla'),
    ChipOption('lower_back', 'Espalda baja'),
    ChipOption('shoulder', 'Hombro'),
    ChipOption('wrist', 'Muñeca'),
    ChipOption('ankle', 'Tobillo'),
    ChipOption('hip', 'Cadera'),
    ChipOption('neck', 'Cuello'),
    ChipOption('elbow', 'Codo'),
  ];

  static const diet = <ChipOption>[
    ChipOption('omnivore', 'Normal'),
    ChipOption('vegetarian', 'Vegetariana'),
    ChipOption('vegan', 'Vegana'),
    ChipOption('high_protein', 'Alta en proteínas'),
    ChipOption('low_carb', 'Baja en carbohidratos'),
    ChipOption('keto', 'Keto'),
    ChipOption('no_preference', 'Sin preferencia'),
  ];

  static const dietaryRestrictions = <ChipOption>[
    ChipOption('lactose', 'Lactosa'),
    ChipOption('gluten', 'Gluten'),
    ChipOption('nuts', 'Frutos secos'),
    ChipOption('seafood', 'Mariscos / Pescado'),
    ChipOption('egg', 'Huevo'),
    ChipOption('soy', 'Soja'),
    ChipOption('none', 'No tengo'),
  ];

  static const cookingTime = <ChipOption>[
    ChipOption('no_time', 'No tengo tiempo'),
    ChipOption('quick_lt_15m', 'Rápido (menos de 15 min)'),
    ChipOption('medium_15_30m', 'Moderado (15-30 min)'),
    ChipOption('enjoy_cooking', 'Disfruto cocinar'),
  ];

  // Catálogo amplio. Se muestra con buscador en la UI.
  // Agrupado mentalmente por categoría para que se entienda mejor el dataset.
  static const dislikedFoodsCommon = <ChipOption>[
    // Proteínas animales
    ChipOption('beef', 'Carne de vacuno'),
    ChipOption('pork', 'Cerdo'),
    ChipOption('chicken', 'Pollo'),
    ChipOption('turkey', 'Pavo'),
    ChipOption('lamb', 'Cordero'),
    ChipOption('fish', 'Pescado'),
    ChipOption('salmon', 'Salmón'),
    ChipOption('tuna', 'Atún'),
    ChipOption('seafood', 'Mariscos'),
    ChipOption('shrimp', 'Camarones'),
    ChipOption('eggs', 'Huevos'),
    // Lácteos
    ChipOption('milk', 'Leche'),
    ChipOption('cheese', 'Queso'),
    ChipOption('yogurt', 'Yogur'),
    ChipOption('butter', 'Mantequilla'),
    // Carbohidratos y granos
    ChipOption('bread', 'Pan'),
    ChipOption('rice', 'Arroz'),
    ChipOption('pasta', 'Pasta'),
    ChipOption('potato', 'Papa / Patata'),
    ChipOption('sweet_potato', 'Camote / Batata'),
    ChipOption('oats', 'Avena'),
    ChipOption('quinoa', 'Quinoa'),
    ChipOption('corn', 'Maíz / Choclo'),
    // Legumbres y semillas
    ChipOption('beans', 'Frijoles / Porotos'),
    ChipOption('lentils', 'Lentejas'),
    ChipOption('chickpeas', 'Garbanzos'),
    ChipOption('peas', 'Arvejas / Guisantes'),
    ChipOption('tofu', 'Tofu'),
    ChipOption('nuts', 'Frutos secos'),
    ChipOption('peanuts', 'Maní / Cacahuetes'),
    // Vegetales
    ChipOption('tomato', 'Tomate'),
    ChipOption('onion', 'Cebolla'),
    ChipOption('garlic', 'Ajo'),
    ChipOption('lettuce', 'Lechuga'),
    ChipOption('spinach', 'Espinaca'),
    ChipOption('broccoli', 'Brócoli'),
    ChipOption('cauliflower', 'Coliflor'),
    ChipOption('carrot', 'Zanahoria'),
    ChipOption('pepper', 'Pimiento / Morrón'),
    ChipOption('cucumber', 'Pepino'),
    ChipOption('mushrooms', 'Hongos / Champiñones'),
    ChipOption('eggplant', 'Berenjena'),
    ChipOption('zucchini', 'Zapallito / Calabacín'),
    ChipOption('olives', 'Aceitunas'),
    ChipOption('avocado', 'Palta / Aguacate'),
    // Frutas
    ChipOption('apple', 'Manzana'),
    ChipOption('banana', 'Plátano / Banana'),
    ChipOption('orange', 'Naranja'),
    ChipOption('strawberry', 'Frutilla / Fresa'),
    ChipOption('grapes', 'Uvas'),
    ChipOption('pineapple', 'Piña / Ananá'),
    ChipOption('mango', 'Mango'),
    ChipOption('papaya', 'Papaya'),
    ChipOption('coconut', 'Coco'),
    // Otros
    ChipOption('spicy', 'Picante'),
    ChipOption('sugar', 'Azúcar'),
    ChipOption('soda', 'Bebidas azucaradas'),
    ChipOption('coffee', 'Café'),
    ChipOption('alcohol', 'Alcohol'),
    ChipOption('processed_meat', 'Embutidos / Cecinas'),
    ChipOption('fast_food', 'Comida rápida'),
    ChipOption('fried_food', 'Fritos'),
  ];

  static const coachingStyle = <ChipOption>[
    ChipOption('gentle', 'Suave y motivador'),
    ChipOption('balanced', 'Equilibrado'),
    ChipOption('strict', 'Exigente y directo'),
    ChipOption('no_notifications', 'Prefiero no recibir mensajes'),
  ];

  static const trainingTime = <ChipOption>[
    ChipOption('morning_early', 'Mañana (antes de las 9:00)'),
    ChipOption('morning_late', 'Media mañana (9:00 - 12:00)'),
    ChipOption('afternoon', 'Tarde (12:00 - 17:00)'),
    ChipOption('evening', 'Noche (después de las 17:00)'),
    ChipOption('variable', 'Varía según el día'),
  ];

  static const mealsPerDay = <ChipOption>[
    ChipOption('2', '2 comidas'),
    ChipOption('3', '3 comidas'),
    ChipOption('4', '4 comidas'),
    ChipOption('5', '5 o más'),
    ChipOption('intermittent_fasting', 'Ayuno intermitente'),
    ChipOption('flexible', 'Depende del día'),
  ];

  // Días: 0 = lunes ... 6 = domingo (alineado con day_of_week de routines)
  static const weekDays = <ChipOption>[
    ChipOption('0', 'Lunes'),
    ChipOption('1', 'Martes'),
    ChipOption('2', 'Miércoles'),
    ChipOption('3', 'Jueves'),
    ChipOption('4', 'Viernes'),
    ChipOption('5', 'Sábado'),
    ChipOption('6', 'Domingo'),
  ];
}
