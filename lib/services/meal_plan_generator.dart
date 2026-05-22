import 'package:flutter/foundation.dart';
import 'ai_meal_template_service.dart';
import 'food_catalog_service.dart';
import 'nutrition_calculator.dart';
import 'simulated_ai_service.dart';
import '../models/ai_meal_template.dart';

/// Datos consumidos por cualquier generador de planes (simulado o IA real).
class MealPlanInput {
  final String goal;
  final String gender;
  final double weightKg;
  final int age;
  final double heightCm;
  final double targetWeightKg;
  final int trainingDaysPerWeek;
  final String dailyActivityLevel;
  final String mealsPerDay;
  final List<String> foodPreferences;
  final List<String> allergies;
  final List<String> dislikedFoods;
  final String? cookingTime;
  final String? userId;
  final int weekIndex;
  final int dayIndex;
  // Variación por comida (slotIndex → nº de "cambios" pedidos por el usuario).
  // Permite intercambiar una comida por otra alternativa de forma estable.
  final Map<int, int> slotVariations;

  const MealPlanInput({
    required this.goal,
    required this.gender,
    required this.weightKg,
    this.age = 30,
    this.heightCm = 170.0,
    this.targetWeightKg = 0,
    this.trainingDaysPerWeek = 3,
    this.dailyActivityLevel = 'moderate',
    this.mealsPerDay = '3',
    this.foodPreferences = const [],
    this.allergies = const [],
    this.dislikedFoods = const [],
    this.cookingTime,
    this.userId,
    this.weekIndex = 0,
    this.dayIndex = 0,
    this.slotVariations = const {},
  });
}

abstract class MealPlanGenerator {
  Future<Map<String, dynamic>> generate(MealPlanInput input);
}

/// Generador basado en la DB de recetas chilenas (ai_meal_templates).
/// Selecciona recetas reales según objetivo, momento del día y preferencias.
/// Si Supabase falla o no hay suficientes templates, cae al generador simulado.
class DbMealPlanGenerator implements MealPlanGenerator {
  const DbMealPlanGenerator();

  @override
  Future<Map<String, dynamic>> generate(MealPlanInput input) async {
    try {
      return await _generateFromDb(input);
    } catch (e) {
      debugPrint('DbMealPlanGenerator fallback to simulated: $e');
      return const SimulatedMealPlanGenerator().generate(input);
    }
  }

  Future<Map<String, dynamic>> _generateFromDb(MealPlanInput input) async {
    final slots = _slotsFor(input.mealsPerDay);
    final allowGourmet = input.cookingTime == 'enjoy_cooking';
    final dificultades = _difficultiesFor(input.cookingTime);

    // Trae recetas con filtro de objetivo+dificultad server-side; si faltan,
    // amplía SIN introducir Gourmet (salvo que el usuario lo haya pedido).
    var templates = await AiMealTemplateService.instance.getTemplatesForGoal(
      input.goal,
      dificultades: dificultades,
      limit: 45,
    );
    if (templates.length < slots.length) {
      final broad = allowGourmet
          ? const ['Muy fácil', 'Normal', 'Gourmet']
          : const ['Muy fácil', 'Normal'];
      templates = await AiMealTemplateService.instance
          .getTemplatesForGoal(input.goal, dificultades: broad, limit: 45);
    }

    final catalog = await FoodCatalogService.instance.getCatalog();
    // Solo cae al simulado si NO hay datos (Supabase caído). Con catálogo,
    // aunque no haya recetas (ej. vegano/keto), se arma con alimentos sueltos.
    if (catalog.isEmpty && templates.isEmpty) {
      return const SimulatedMealPlanGenerator().generate(input);
    }

    return buildPlan(input: input, templates: templates, catalog: catalog);
  }

  /// Arma el plan a partir de datos ya cargados (recetas + catálogo). Es PURO
  /// (sin red), así que se puede testear con fixtures. Los filtros por objetivo,
  /// dificultad, gourmet, alergias y dieta son idempotentes: si las recetas ya
  /// vienen filtradas (producción) no cambian; si vienen crudas (tests) filtran.
  Map<String, dynamic> buildPlan({
    required MealPlanInput input,
    required List<AiMealTemplate> templates,
    required List<CatalogFood> catalog,
  }) {
    final effectiveTarget =
        input.targetWeightKg > 0 ? input.targetWeightKg : input.weightKg;

    // Preferencia de dieta: vegana / vegetariana / lowcarb / proteica / normal.
    final dietPref = SimulatedAIService.dominantDietPref(input.foodPreferences);

    final nutrition = NutritionCalculator.calculate(
      gender: input.gender,
      age: input.age,
      weightKg: input.weightKg,
      heightCm: input.heightCm,
      targetWeightKg: effectiveTarget,
      fitnessGoal: input.goal,
      trainingDaysPerWeek: input.trainingDaysPerWeek,
      dailyActivityLevel: input.dailyActivityLevel,
      dietPref: dietPref,
    );

    final slots = _slotsFor(input.mealsPerDay);
    final allowGourmet = input.cookingTime == 'enjoy_cooking';
    final dificultades = _difficultiesFor(input.cookingTime);

    var t = templates
        .where((x) => _matchesGoal(x, input.goal))
        .where((x) => dificultades.contains(x.categoriaDificultad))
        .toList();
    if (!allowGourmet) {
      t = t
          .where((x) => !x.modoDieta.toLowerCase().contains('gourmet'))
          .toList();
    }
    if (input.allergies.isNotEmpty) {
      t = t
          .where((x) => !SimulatedAIService.textHasAllergen(
                '${x.nombre} ${x.ingredientesBase ?? ''}',
                input.allergies,
              ))
          .toList();
    }
    final dietExclusions = _dietExclusions(dietPref);
    if (dietExclusions.isNotEmpty) {
      t = t
          .where((x) => !_containsAny(
                '${x.nombre} ${x.ingredientesBase ?? ''}',
                dietExclusions,
              ))
          .toList();
    }
    if (dietPref == 'lowcarb') {
      t = t
          .where((x) => !_containsAny(
                '${x.nombre} ${x.ingredientesBase ?? ''}',
                _highCarbKw,
              ))
          .toList();
    }

    final pools = _FoodPools.build(catalog, input.allergies);
    final seed = _seed(input.userId, input.weekIndex);
    final items = <Map<String, dynamic>>[];

    final totalWeight =
        slots.fold<double>(0, (sum, s) => sum + _slotWeight(s));
    final targetCalories = nutrition.recommendedCalories.toDouble();
    // % de calorías que el usuario debe obtener de proteína (de SUS macros).
    // Dimensiona dinámicamente cuán proteicos son los platos.
    final proteinCalFrac = targetCalories > 0
        ? (nutrition.proteinGrams * 4) / targetCalories
        : 0.30;
    final usedRecipes = <String>{};

    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final slotTarget = targetCalories * (_slotWeight(slot) / totalWeight);
      final variation = input.slotVariations[i] ?? 0;
      final slotSeed = seed + variation * 7919;
      items.add(_assembleMeal(
        slot: slot,
        target: slotTarget,
        templates: t,
        pools: pools,
        dietPref: dietPref,
        proteinCalFrac: proteinCalFrac,
        seed: slotSeed,
        dayIndex: input.dayIndex,
        slotIndex: i,
        usedRecipes: usedRecipes,
      ));
    }

    _closeMacros(
      items: items,
      pools: pools,
      dietPref: dietPref,
      nutrition: nutrition,
      seed: seed + input.dayIndex,
    );

    return {
      'title': 'Plan ${_goalLabel(input.goal)} — Chile',
      'food_mode': 'chile',
      'total_calories': nutrition.recommendedCalories,
      'maintenance_calories': nutrition.maintenanceCalories,
      'bmr': nutrition.bmr,
      'calorie_adjustment': nutrition.calorieAdjustment,
      'goal_interpretation': nutrition.goalInterpretation,
      'strategy': nutrition.strategy,
      'explanation_text': nutrition.explanationText,
      'protein_grams': nutrition.proteinGrams,
      'carbs_grams': nutrition.carbsGrams,
      'fats_grams': nutrition.fatsGrams,
      'disclaimer': SimulatedAIService.disclaimer,
      'week_index': input.weekIndex,
      'cooking_time': input.cookingTime,
      'items': SimulatedAIService.annotateDislikes(items, input.dislikedFoods),
    };
  }

  // Replica el filtro de objetivo server-side (idempotente en producción).
  bool _matchesGoal(AiMealTemplate t, String goal) {
    final objetivo = switch (goal.toUpperCase()) {
      'LOSE_WEIGHT' => 'perder_grasa',
      'GAIN_MUSCLE' => 'ganar_musculo',
      _ => 'mantener',
    };
    final wanted = objetivo == 'mantener'
        ? const ['mantener', 'mantenimiento']
        : [objetivo];
    if (t.objetivoRecomendado.isEmpty) return true; // sin tag → no excluir
    return t.objetivoRecomendado.any(wanted.contains);
  }

  Map<String, dynamic> _toItem(AiMealTemplate t, String slot, double mult) {
    double round1(double v) => double.parse((v * mult).toStringAsFixed(1));
    return {
      'meal_type': _mealType(slot),
      'name': t.nombre,
      'ingredients': t.ingredientesBase
              ?.split(', ')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[],
      'calories': (t.kcal * mult).round(),
      'protein': round1(t.proteinaG),
      'carbs': round1(t.carbohidratosG),
      'fats': round1(t.grasasG),
      // Campos extra para uso futuro (IA real, detalle de receta).
      'external_id': t.externalId,
      'porcion_g': t.porcionG == null ? null : (t.porcionG! * mult).round(),
      'portion_multiplier': mult,
    };
  }

  // Peso relativo de calorías por comida; se normaliza sobre los slots usados.
  static double _slotWeight(String slot) {
    switch (slot) {
      case 'desayuno':
        return 0.25;
      case 'almuerzo':
        return 0.35;
      case 'cena':
        return 0.30;
      case 'once':
        return 0.15;
      case 'post_entreno':
        return 0.12;
      case 'colacion':
        return 0.10;
      default:
        return 0.15;
    }
  }

  // ── Ensamblado de comidas estilo Fitia ──────────────────────────────────
  // TODAS las comidas (incluido desayuno/colación) alternan entre receta sola
  // de la DB (avena con leche, yogur con fruta, pan con queso, batido, arroz
  // con pollo, etc.) y una combinación de alimentos sueltos. Así se aprovecha
  // todo el catálogo de recetas y se evita la monotonía (no siempre huevo).

  Map<String, dynamic> _assembleMeal({
    required String slot,
    required double target,
    required List<AiMealTemplate> templates,
    required _FoodPools pools,
    required String dietPref,
    required double proteinCalFrac,
    required int seed,
    required int dayIndex,
    required int slotIndex,
    required Set<String> usedRecipes,
  }) {
    // Alterna determinísticamente: ~mitad recetas, ~mitad alimentos sueltos.
    final asRecipe = ((seed ~/ 13 + dayIndex + slotIndex) % 2 == 0);

    // Rotación de familia de proteína en almuerzo/cena (omnívoro): cada día y
    // comida apunta a una familia distinta para que la semana no sea todo
    // pollo. Veg/vegano no rotan (ya varían por sus alimentos).
    String? family;
    if ((slot == 'almuerzo' || slot == 'cena') &&
        dietPref != 'vegana' &&
        dietPref != 'vegetariana') {
      // Índice global de comida principal en la semana (2 por día: almuerzo y
      // cena). Recorrer las familias por este índice reparte uniforme → ninguna
      // familia supera ~3 veces en 7 días (14 comidas principales).
      // Keto/low-carb no rota a legumbres (son altas en carbohidratos).
      final fams =
          dietPref == 'lowcarb' ? _ketoProteinFamilies : _proteinFamilies;
      final mainOrdinal = dayIndex * 2 + (slot == 'cena' ? 1 : 0);
      family = fams[(seed + mainOrdinal).abs() % fams.length];
    }

    Map<String, dynamic>? tryRecipe() => _recipeAlone(templates, slot, target,
        seed, dayIndex, slotIndex, usedRecipes, family);
    Map<String, dynamic>? tryFoods() => _buildFromFoods(slot, target, pools,
        dietPref, proteinCalFrac, seed, dayIndex, slotIndex, family);

    if (asRecipe) {
      return tryRecipe() ?? tryFoods() ?? _emptyMeal(slot);
    }
    return tryFoods() ?? tryRecipe() ?? _emptyMeal(slot);
  }

  // Familias de proteína para rotar a lo largo de la semana.
  static const _proteinFamilies = ['aves', 'roja', 'mar', 'huevo', 'legumbre'];
  // Keto/low-carb: sin legumbres (altas en carbohidratos).
  static const _ketoProteinFamilies = ['aves', 'roja', 'mar', 'huevo'];
  static const _familyKw = {
    'aves': ['pollo', 'pavo', 'gallina'],
    'roja': [
      'vacuno', 'carne', 'cerdo', 'lomo', 'posta', 'molida', 'churrasco',
      'bistec', 'asad', 'milanesa', 'albondiga', 'chuleta', 'res', 'cordero'
    ],
    'mar': [
      'pescado', 'atun', 'salmon', 'merluza', 'reineta', 'congrio', 'camaron',
      'jurel', 'marisco', 'sardina', 'pulpo', 'mariscos'
    ],
    'huevo': ['huevo', 'clara', 'tortilla', 'omelette', 'revuelt'],
    'legumbre': [
      'lenteja', 'poroto', 'garbanzo', 'soja', 'soya', 'tofu', 'tempeh',
      'lupino', 'arveja', 'haba', 'frijol'
    ],
  };

  bool _textInFamily(String text, String family) {
    final l = text.toLowerCase();
    return (_familyKw[family] ?? const []).any(l.contains);
  }

  /// Receta sin acompañamientos añadidos: muestra sus ingredientes reales.
  Map<String, dynamic>? _recipeAlone(
    List<AiMealTemplate> templates,
    String slot,
    double target,
    int seed,
    int dayIndex,
    int slotIndex,
    Set<String> usedRecipes, [
    String? proteinFamily,
  ]) {
    final t = _pickRecipe(
        templates, slot, seed, dayIndex, slotIndex, usedRecipes, proteinFamily);
    if (t == null) return null;
    return _toItem(t, slot, _recipeMult(target, t.kcal, 2.5));
  }

  AiMealTemplate? _pickRecipe(
    List<AiMealTemplate> templates,
    String slot,
    int seed,
    int dayIndex,
    int slotIndex,
    Set<String> usedRecipes, [
    String? proteinFamily,
  ]) {
    var pool = templates.where((t) => t.momentoDia.contains(slot)).toList();
    // Limita a la familia de proteína del día (si quedan recetas de esa
    // familia); si no hay, no fuerza y usa todas las del momento.
    if (proteinFamily != null) {
      final fam = pool
          .where((t) => _textInFamily(
              '${t.nombre} ${t.ingredientesBase ?? ''}', proteinFamily))
          .toList();
      if (fam.isNotEmpty) pool = fam;
    }
    final source = pool.isNotEmpty ? pool : templates;
    if (source.isEmpty) return null;
    // Anti-repetición: prioriza recetas no usadas aún esta semana.
    final fresh =
        source.where((t) => !usedRecipes.contains(t.externalId)).toList();
    final pickFrom = fresh.isNotEmpty ? fresh : source;
    final idx = (seed + dayIndex * 31 + slotIndex * 7).abs() % pickFrom.length;
    final chosen = pickFrom[idx];
    usedRecipes.add(chosen.externalId);
    return chosen;
  }

  double _recipeMult(double target, int kcal, double maxMult) {
    final raw = kcal > 0 ? target / kcal : 1.0;
    return double.parse(raw.clamp(0.4, maxMult).toStringAsFixed(2));
  }

  Map<String, dynamic>? _buildFromFoods(
    String slot,
    double target,
    _FoodPools pools,
    String dietPref,
    double proteinCalFrac,
    int seed,
    int dayIndex,
    int slotIndex, [
    String? proteinFamily,
  ]) {
    final plan = _foodSlotPlan(slot, dietPref, proteinCalFrac);
    final components = <Map<String, dynamic>>[];
    for (var r = 0; r < plan.length; r++) {
      final (role, frac) = plan[r];
      var pool = _rolePool(pools, role, dietPref);
      // En la proteína principal, respeta la familia del día (si hay stock).
      if (role == 'mprotein' && proteinFamily != null) {
        if (proteinFamily == 'legumbre') {
          // El omnívoro también tiene día de legumbres (no está en mainProteins).
          if (pools.legumes.isNotEmpty) pool = pools.legumes;
        } else {
          final fam =
              pool.where((f) => _textInFamily(f.name, proteinFamily)).toList();
          if (fam.isNotEmpty) pool = fam;
        }
      }
      if (pool.isEmpty) continue;
      final food = _pickFood(pool, seed, dayIndex, slotIndex, r + 1);
      if (food == null) continue;
      // La verdura es muy baja en calorías: escalarla por kcal da porciones
      // absurdas (500g de brócoli). Va como 1 porción fija de referencia.
      final double grams;
      if (role == 'veg') {
        grams = food.servingGrams;
      } else {
        final sub = target * frac;
        grams = food.kcalPer100g > 0
            ? (sub / food.kcalPer100g) * 100
            : food.servingGrams;
      }
      components.add(_foodComponent(food, grams));
    }
    if (components.isEmpty) return null;
    final title =
        components.take(3).map((c) => c['name'] as String).join(' + ');
    return _composeItem(slot, title, components);
  }

  /// Fracción de calorías de la comida que va al alimento proteico, derivada
  /// del % de proteína OBJETIVO del usuario (sus datos), no de un valor fijo.
  /// Se divide por la "eficiencia proteica" del pool (cuánta de su energía es
  /// proteína): carnes magras/huevo ~0.68, mezcla veg+huevo ~0.55, legumbres
  /// ~0.42. Así un usuario alto en proteína recibe platos más proteicos y uno
  /// en mantención no se pasa.
  double _mainProteinFrac(String dietPref, double proteinCalFrac) {
    final efficiency = dietPref == 'vegana'
        ? 0.42
        : dietPref == 'vegetariana'
            ? 0.55
            : 0.68;
    return (proteinCalFrac / efficiency).clamp(0.32, 0.62);
  }

  // Ordena un pool por densidad proteica (g proteína por kcal), de mayor a
  // menor. Devuelve una copia (no muta el pool original).
  List<CatalogFood> _byProteinDensity(List<CatalogFood> pool) {
    final copy = [...pool];
    copy.sort((a, b) {
      final da = a.kcalPer100g > 0 ? a.proteinPer100g / a.kcalPer100g : 0;
      final db = b.kcalPer100g > 0 ? b.proteinPer100g / b.kcalPer100g : 0;
      return db.compareTo(da);
    });
    return copy;
  }

  List<(String, double)> _foodSlotPlan(
      String slot, String dietPref, double proteinCalFrac) {
    // Low-carb / keto: reemplaza carbos por proteína + grasa (frutos secos) y
    // evita pan/avena/fruta azucarada.
    if (dietPref == 'lowcarb') {
      switch (slot) {
        case 'desayuno':
          return [('egg', 0.60), ('nuts', 0.40)];
        case 'colacion':
          return [('dairy', 0.50), ('nuts', 0.50)];
        case 'post_entreno':
          return [('mprotein', 0.60), ('nuts', 0.40)];
        case 'almuerzo':
        case 'cena':
          return [('mprotein', 0.65), ('nuts', 0.25), ('veg', 0.10)];
        default:
          return [('dairy', 0.5), ('nuts', 0.5)];
      }
    }
    switch (slot) {
      case 'desayuno':
        // El huevo escala con la necesidad de proteína; el resto se reparte
        // entre carbo y fruta manteniendo la suma ≈ 1.
        final ep = (proteinCalFrac * 1.2).clamp(0.28, 0.45);
        final rest = 1 - ep;
        return [('egg', ep), ('bcarb', rest * 0.57), ('fruit', rest * 0.43)];
      case 'colacion':
        return [('dairy', 0.55), ('fruit', 0.45)];
      case 'post_entreno':
        return [('dairy', 0.50), ('fruit', 0.50)];
      case 'almuerzo':
      case 'cena':
        // Plato proteína-forward dinámico: la proteína se dimensiona al objetivo
        // del usuario; el carbo toma el resto; la verdura va como porción fija.
        final mp = _mainProteinFrac(dietPref, proteinCalFrac);
        final mc = (0.92 - mp).clamp(0.22, 0.58);
        return [('mprotein', mp), ('mcarb', mc), ('veg', 0.10)];
      default:
        return [('dairy', 0.5), ('fruit', 0.5)];
    }
  }

  List<CatalogFood> _rolePool(_FoodPools p, String role, String dietPref) {
    final vegan = dietPref == 'vegana';
    final vegetarian = dietPref == 'vegetariana';
    switch (role) {
      case 'egg': // proteína de desayuno — variada, no solo huevo
        if (vegan) {
          // Mantequilla de maní/frutos secos + tofu/soya/lupino para variar.
          return [...p.nuts, ..._byProteinDensity(p.legumes).take(3)];
        }
        // Yogures proteicos del pool lácteo (yogur/leche), no quesos grasos.
        final dairyProt =
            p.dairy.where((f) => _containsAny(f.name, ['yogur'])).toList();
        if (vegetarian) return [...p.eggs, ...dairyProt];
        // Omnívoro: huevos + yogur + fiambre magro (pavo / jamón de pavo).
        final leanCold = p.mainProteins
            .where((f) => _containsAny(f.name, ['pavo', 'jamon']))
            .toList();
        return [...p.eggs, ...dairyProt, ...leanCold];
      case 'mprotein': // proteína de almuerzo/cena
        // Para dietas vegetales la densidad proteica importa mucho: ordena por
        // g proteína/kcal (soja, edamame, claras primero) para acercarse al
        // objetivo de proteína sin disparar las calorías.
        if (vegan) return _byProteinDensity(p.legumes).take(5).toList();
        if (vegetarian) {
          return _byProteinDensity([...p.eggs, ...p.legumes]).take(6).toList();
        }
        return p.mainProteins;
      case 'dairy':
        if (vegan) return p.nuts.isNotEmpty ? p.nuts : p.fruits;
        return p.dairy;
      case 'bcarb':
        return p.breakfastCarbs;
      case 'mcarb':
        return p.mainCarbs;
      case 'fruit':
        return p.fruits;
      case 'veg':
        return p.veggies;
      case 'nuts':
        return p.nuts;
      default:
        return const [];
    }
  }

  CatalogFood? _pickFood(
    List<CatalogFood> pool,
    int seed,
    int dayIndex,
    int slotIndex,
    int roleSalt,
  ) {
    if (pool.isEmpty) return null;
    final idx =
        (seed + dayIndex * 17 + slotIndex * 5 + roleSalt * 101).abs() %
            pool.length;
    return pool[idx];
  }

  Map<String, dynamic> _foodComponent(CatalogFood f, double grams) {
    final serving = f.servingGrams;
    var units = serving > 0 ? (grams / serving).round() : 1;
    units = units.clamp(1, 6);
    final g = serving > 0 ? units * serving : grams;
    return {
      'kind': 'food',
      'name': f.name,
      'grams': double.parse(g.toStringAsFixed(0)),
      'units': units,
      'serving_g': serving,
      'calories': double.parse(f.kcalFor(g).toStringAsFixed(1)),
      'protein': double.parse(f.proteinFor(g).toStringAsFixed(1)),
      'carbs': double.parse(f.carbsFor(g).toStringAsFixed(1)),
      'fats': double.parse(f.fatFor(g).toStringAsFixed(1)),
    };
  }

  Map<String, dynamic> _composeItem(
    String slot,
    String title,
    List<Map<String, dynamic>> components, {
    String? recipeBaseId,
    double? mult,
  }) {
    double kcal = 0, p = 0, c = 0, f = 0;
    for (final comp in components) {
      kcal += comp['calories'] as double;
      p += comp['protein'] as double;
      c += comp['carbs'] as double;
      f += comp['fats'] as double;
    }
    final ingredients = components.map((comp) {
      final units = comp['units'] as int? ?? 1;
      final g = comp['grams'];
      final qty = units > 1 ? ' ×$units' : '';
      final gramsTxt = g != null ? ' (${(g as num).toStringAsFixed(0)}g)' : '';
      return '${comp['name']}$qty$gramsTxt';
    }).toList();

    return {
      'meal_type': _mealType(slot),
      'name': title,
      'ingredients': ingredients,
      'components': components,
      'calories': kcal.round(),
      'protein': double.parse(p.toStringAsFixed(1)),
      'carbs': double.parse(c.toStringAsFixed(1)),
      'fats': double.parse(f.toStringAsFixed(1)),
      if (recipeBaseId != null) 'external_id': recipeBaseId,
      if (mult != null) 'portion_multiplier': mult,
    };
  }

  Map<String, dynamic> _emptyMeal(String slot) => {
        'meal_type': _mealType(slot),
        'name': 'Comida',
        'ingredients': <String>[],
        'components': <Map<String, dynamic>>[],
        'calories': 0,
        'protein': 0.0,
        'carbs': 0.0,
        'fats': 0.0,
      };

  // ── Cierre de macros con alimentos simples ───────────────────────────────
  // Tras armar las comidas base, agrega complementos (huevo, yogur, atún,
  // fruta, frutos secos…) hasta acercar PROTEÍNA y CALORÍAS al objetivo del
  // día. La proteína tiene piso (puede empujar un poco las kcal); el relleno
  // calórico nunca se pasa más del margen.
  static const double _kcalTol = 0.08; // ±8% de calorías
  static const double _proteinFloorRatio = 0.92; // alcanzar ≥92% de proteína
  static const int _maxCloseItems = 5; // tope de complementos

  void _closeMacros({
    required List<Map<String, dynamic>> items,
    required _FoodPools pools,
    required String dietPref,
    required NutritionResult nutrition,
    required int seed,
  }) {
    double sumKey(String k) =>
        items.fold(0.0, (s, it) => s + ((it[k] as num?)?.toDouble() ?? 0));

    final pTarget = nutrition.proteinGrams.toDouble();
    final cTarget = nutrition.carbsGrams.toDouble();
    final fTarget = nutrition.fatsGrams.toDouble();
    final kTarget = nutrition.recommendedCalories.toDouble();
    if (kTarget <= 0) return;

    // Proteína de relleno ordenada por densidad (g proteína / kcal) de mayor a
    // menor: así cerramos proteína gastando el mínimo de calorías (clave para
    // déficit). Evita que el complemento dispare las calorías del día.
    final proteinPool = _closureProteinPool(pools, dietPref)
      ..sort((a, b) {
        final da = a.kcalPer100g > 0 ? a.proteinPer100g / a.kcalPer100g : 0;
        final db = b.kcalPer100g > 0 ? b.proteinPer100g / b.kcalPer100g : 0;
        return db.compareTo(da);
      });
    final carbPool = [...pools.fruits, ...pools.breakfastCarbs];
    final fatPool = pools.nuts;

    double curP = sumKey('protein');
    double curC = sumKey('carbs');
    double curF = sumKey('fats');
    double curK = sumKey('calories');

    // Techo absoluto de calorías: el complemento NUNCA debe pasar de aquí, ni
    // siquiera para cerrar proteína. Mejor quedar algo corto de proteína que
    // arruinar el déficit/objetivo calórico del usuario.
    final ceiling = kTarget * (1 + _kcalTol);

    final added = <Map<String, dynamic>>[];

    CatalogFood? pick(List<CatalogFood> pool, int salt) {
      if (pool.isEmpty) return null;
      return pool[(seed + salt * 101 + added.length * 7).abs() % pool.length];
    }

    for (int iter = 0; iter < 8 && added.length < _maxCloseItems; iter++) {
      final needProtein = curP < pTarget * _proteinFloorRatio;
      final needKcal = curK < kTarget * (1 - _kcalTol);
      if (!needProtein && !needKcal) break;

      CatalogFood? food;
      if (needProtein) {
        food = pick(proteinPool, 1);
        // Si la opción rotada se pasa del techo, usa la MÁS magra disponible.
        if (food != null &&
            curK + food.kcalFor(food.servingGrams) > ceiling &&
            proteinPool.isNotEmpty) {
          food = proteinPool.first;
        }
      } else {
        // Faltan calorías: prioriza el macro más deficitario (carbo vs grasa).
        final cDef = cTarget > 0 ? (cTarget - curC) / cTarget : 0;
        final fDef = fTarget > 0 ? (fTarget - curF) / fTarget : 0;
        food = (fDef > cDef) ? pick(fatPool, 2) : pick(carbPool, 3);
        food ??= pick(carbPool, 3) ?? pick(fatPool, 2);
      }
      if (food == null) break;

      final grams = food.servingGrams;
      final kcal = food.kcalFor(grams);
      // Regla dura: ningún complemento puede pasar el techo de calorías.
      if (curK + kcal > ceiling) break;

      final comp = _foodComponent(food, grams);
      added.add(comp);
      curP += comp['protein'] as double;
      curC += comp['carbs'] as double;
      curF += comp['fats'] as double;
      curK += comp['calories'] as double;
    }

    if (added.isEmpty) return;
    final title = added.take(3).map((c) => c['name'] as String).join(' + ');
    final supplement = _composeItem('colacion', title, added);
    supplement['is_supplement'] = true; // no es swappable; relleno de macros
    items.add(supplement);
  }

  /// Alimentos simples densos en proteína para cerrar el déficit, por dieta.
  List<CatalogFood> _closureProteinPool(_FoodPools p, String dietPref) {
    if (dietPref == 'vegana') return [...p.legumes, ...p.nuts];
    if (dietPref == 'vegetariana') return [...p.eggs, ...p.dairy, ...p.legumes];
    // Omnívoro: complementos magros y "snackeables" (atún, pavo, jamón de pavo)
    // + huevo + lácteos + legumbres. Evita meter carnes grasas como snack.
    final lean = p.mainProteins
        .where((f) => _containsAny(f.name, ['atun', 'pavo', 'jamon']))
        .toList();
    return [...p.eggs, ...p.dairy, ...lean, ...p.legumes];
  }

  List<String> _slotsFor(String mealsPerDay) {
    switch (mealsPerDay) {
      case '2':
        return ['almuerzo', 'cena'];
      case 'ayuno':
      case 'intermittent_fasting':
        return ['almuerzo', 'cena'];
      case '4':
        return ['desayuno', 'almuerzo', 'cena', 'colacion'];
      case '5':
        return ['desayuno', 'almuerzo', 'cena', 'colacion', 'post_entreno'];
      default: // '3', 'flexible'
        return ['desayuno', 'almuerzo', 'cena'];
    }
  }

  // Palabras clave de ingredientes incompatibles con la dieta elegida.
  // vegetariana = sin carne ni pescado/mariscos.
  // vegana = además sin lácteos, huevo ni miel.
  static const _meatKw = [
    'pollo', 'pavo', 'vacuno', 'carne', 'cerdo', 'lomo', 'filete', 'tocino',
    'panceta', 'salchicha', 'longaniza', 'chorizo', 'cordero', 'higado',
    'jamon', 'albondiga', 'milanesa', 'prieta', 'morcilla', 'arrollado',
    'bistec', 'churrasco', 'pino', 'guatita'
  ];
  static const _fishKw = [
    'atun', 'salmon', 'merluza', 'reineta', 'congrio', 'camaron', 'sardina',
    'pescado', 'marisco', 'jurel', 'anchoa', 'pulpo'
  ];
  static const _animalKw = [
    'leche', 'yogur', 'queso', 'huevo', 'clara', 'yema', 'mantequilla',
    'crema', 'manjar', 'miel', 'mayonesa'
  ];
  // Recetas cargadas de carbohidratos, no aptas para low-carb / keto.
  static const _highCarbKw = [
    'pasta', 'arroz', 'fideo', 'tallarin', 'tallarín', 'pan', 'papa', 'papas',
    'pure', 'puré', 'noqui', 'ñoqui', 'sopaipilla', 'empanada', 'choclo',
    'quinoa', 'cous', 'mote', 'humita', 'tamal', 'lasaña', 'lasagna',
    'risotto', 'pizza', 'completo', 'hotdog', 'sandwich', 'sándwich'
  ];

  List<String> _dietExclusions(String dietPref) {
    switch (dietPref) {
      case 'vegana':
        return const [..._meatKw, ..._fishKw, ..._animalKw];
      case 'vegetariana':
        return const [..._meatKw, ..._fishKw];
      default:
        return const [];
    }
  }

  bool _containsAny(String text, List<String> keywords) {
    final t = text.toLowerCase();
    return keywords.any((k) => t.contains(k));
  }

  // Mapea el tiempo de cocina a los niveles de dificultad permitidos.
  // Gourmet SOLO para quien eligió "Disfruto cocinar".
  List<String> _difficultiesFor(String? cookingTime) {
    switch (cookingTime) {
      case 'no_time':
        return const ['Muy fácil'];
      case 'quick_lt_15m':
        return const ['Muy fácil', 'Normal'];
      case 'enjoy_cooking':
        return const ['Muy fácil', 'Normal', 'Gourmet'];
      case 'medium_15_30m':
      default:
        return const ['Muy fácil', 'Normal'];
    }
  }

  String _mealType(String momento) {
    switch (momento) {
      case 'desayuno':
        return 'breakfast';
      case 'almuerzo':
        return 'lunch';
      case 'cena':
        return 'dinner';
      case 'post_entreno':
        return 'post_workout';
      default:
        return 'snack';
    }
  }

  String _goalLabel(String g) {
    switch (g.toUpperCase()) {
      case 'LOSE_WEIGHT':
        return 'Pérdida de grasa';
      case 'GAIN_MUSCLE':
        return 'Ganancia muscular';
      default:
        return 'Mantenimiento';
    }
  }

  // Mismo hash determinista que SimulatedAIService para coherencia.
  static int _seed(String? userId, int weekIndex) {
    final base =
        (userId == null || userId.isEmpty) ? 'anon'.hashCode : userId.hashCode;
    return ((base.abs() * 1315423911) ^ (weekIndex * 2654435761)) & 0x7fffffff;
  }
}

/// Generador simulado (heurístico local, sin red). Usado como fallback.
class SimulatedMealPlanGenerator implements MealPlanGenerator {
  const SimulatedMealPlanGenerator();

  @override
  Future<Map<String, dynamic>> generate(MealPlanInput input) async {
    return SimulatedAIService.generateMealPlan(
      goal: input.goal,
      gender: input.gender,
      weightKg: input.weightKg,
      age: input.age,
      heightCm: input.heightCm,
      targetWeightKg: input.targetWeightKg,
      trainingDaysPerWeek: input.trainingDaysPerWeek,
      dailyActivityLevel: input.dailyActivityLevel,
      mealsPerDay: input.mealsPerDay,
      foodPreferences: input.foodPreferences,
      allergies: input.allergies,
      dislikedFoods: input.dislikedFoods,
      cookingTime: input.cookingTime,
      userId: input.userId,
      weekIndex: input.weekIndex,
      dayIndex: input.dayIndex,
    );
  }
}

/// Clasifica el catálogo de alimentos sueltos por rol nutricional para que el
/// ensamblador pueda componer comidas coherentes. Excluye alérgenos del usuario.
class _FoodPools {
  final List<CatalogFood> eggs; // proteína de desayuno
  final List<CatalogFood> mainProteins; // proteína de almuerzo/cena
  final List<CatalogFood> legumes; // proteína vegetal (lentejas, porotos...)
  final List<CatalogFood> dairy;
  final List<CatalogFood> breakfastCarbs; // avena, pan, tostadas...
  final List<CatalogFood> mainCarbs; // arroz, pasta, quinoa...
  final List<CatalogFood> veggies;
  final List<CatalogFood> fruits;
  final List<CatalogFood> nuts;

  const _FoodPools({
    required this.eggs,
    required this.mainProteins,
    required this.legumes,
    required this.dairy,
    required this.breakfastCarbs,
    required this.mainCarbs,
    required this.veggies,
    required this.fruits,
    required this.nuts,
  });

  static _FoodPools build(List<CatalogFood> all, List<String> allergies) {
    bool nameHas(CatalogFood f, List<String> kws) {
      final n = f.name.toLowerCase();
      return kws.any((k) => n.contains(k));
    }

    // Seguridad: descarta alimentos con un alérgeno del usuario.
    final foods = all
        .where((f) => !SimulatedAIService.textHasAllergen(f.name, allergies))
        .toList();

    List<CatalogFood> cat(String c) =>
        foods.where((f) => f.category == c).toList();

    // Embutidos/procesados que no queremos en combos automáticos saludables.
    const processedMeat = [
      'tocino', 'panceta', 'salchicha', 'longaniza', 'chorizo',
      'prieta', 'morcilla', 'arrollado'
    ];
    const starchyVeg = [
      'papa', 'patata', 'camote', 'batata', 'choclo', 'maiz',
      'zapallo', 'calabaza', 'betarraga', 'remolacha'
    ];

    return _FoodPools(
      eggs: cat('Proteinas').where((f) => nameHas(f, ['huevo', 'clara'])).toList(),
      mainProteins: cat('Proteinas')
          .where((f) => !nameHas(f, [...processedMeat, 'yema']))
          .toList(),
      legumes: cat('Legumbres'),
      dairy: cat('Lacteos')
          .where((f) =>
              nameHas(f, ['yogur', 'leche']) &&
              !nameHas(f, ['condensada', 'crema', 'helado']))
          .toList(),
      breakfastCarbs: cat('Cereales')
          .where((f) =>
              nameHas(f, ['avena', 'pan', 'tostada', 'quinoa', 'tortilla', 'galleta']) &&
              !nameHas(f, ['harina']))
          .toList(),
      mainCarbs: cat('Cereales')
          .where((f) => nameHas(f, ['arroz', 'pasta', 'fideo', 'quinoa', 'mote', 'cous']))
          .toList(),
      veggies: cat('Verduras').where((f) => !nameHas(f, starchyVeg)).toList(),
      fruits: cat('Frutas')
          .where((f) => !nameHas(f, ['palta', 'aguacate', 'limon']))
          .toList(),
      nuts: cat('Grasas')
          .where((f) => nameHas(f, ['nuece', 'almendra', 'mani', 'semilla']))
          .toList(),
    );
  }
}

/// Punto único de inyección. Cambiar `current` aquí afecta toda la app.
class MealPlanGeneratorProvider {
  MealPlanGeneratorProvider._();

  // DbMealPlanGenerator usa la DB de recetas chilenas con fallback al simulado.
  static MealPlanGenerator current = const DbMealPlanGenerator();
}
