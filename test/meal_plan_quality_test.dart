import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymgram_beta/models/ai_meal_template.dart';
import 'package:gymgram_beta/services/food_catalog_service.dart';
import 'package:gymgram_beta/services/meal_plan_generator.dart';
import 'package:gymgram_beta/services/simulated_ai_service.dart';

/// Banco de pruebas automatizado de CALIDAD de los planes de alimentación.
///
/// Genera usuarios sintéticos, arma el plan con el generador REAL
/// (`DbMealPlanGenerator.buildPlan`, sin red, sobre fixtures con la data real
/// de Supabase) y le pone NOTA 1–10 según qué tan bien cierra calorías y macros
/// y si respeta la dieta y las alergias.
void main() {
  late List<CatalogFood> catalog;
  late List<AiMealTemplate> templates;

  setUpAll(() {
    catalog = (jsonDecode(File('test/fixtures/custom_foods.json')
            .readAsStringSync()) as List)
        .map((e) => CatalogFood.fromMap(e as Map<String, dynamic>))
        .toList();
    templates = (jsonDecode(File('test/fixtures/ai_meal_templates.json')
            .readAsStringSync()) as List)
        .map((e) => AiMealTemplate.fromMap(e as Map<String, dynamic>))
        .toList();
  });

  // Palabras clave para verificar cumplimiento de dieta (mismas familias que
  // usa el generador internamente).
  const meatKw = [
    'pollo', 'pavo', 'vacuno', 'carne', 'cerdo', 'lomo', 'filete', 'tocino',
    'panceta', 'salchicha', 'longaniza', 'chorizo', 'cordero', 'higado',
    'jamon', 'albondiga', 'milanesa', 'prieta', 'morcilla', 'arrollado',
    'bistec', 'churrasco', 'pino', 'guatita', 'posta', 'jamonada'
  ];
  const fishKw = [
    'atun', 'salmon', 'merluza', 'reineta', 'congrio', 'camaron', 'sardina',
    'pescado', 'marisco', 'jurel', 'anchoa', 'pulpo'
  ];
  // OJO: 'mantequilla de maní' es vegana, así que NO se incluye 'mantequilla'
  // ni 'crema' (queda cubierto 'queso crema' por 'queso').
  const animalKw = [
    'yogur', 'queso', 'huevo', 'clara', 'yema', 'manjar', 'mayonesa'
  ];
  const highCarbKw = [
    'pasta', 'arroz', 'fideo', 'tallarin', 'pan ', 'papa', 'pure', 'noqui',
    'ñoqui', 'sopaipilla', 'empanada', 'choclo', 'quinoa', 'mote', 'humita',
    'tamal', 'risotto', 'pizza', 'completo'
  ];

  bool textHasAny(String t, List<String> kws) {
    final l = t.toLowerCase();
    return kws.any((k) => l.contains(k));
  }

  // Junta todo el texto de un plan (nombres + ingredientes + componentes).
  List<String> planTexts(List<Map<String, dynamic>> items) {
    final out = <String>[];
    for (final it in items) {
      out.add(it['name'] as String? ?? '');
      final ing = (it['ingredients'] as List?)?.cast<String>() ?? const [];
      out.addAll(ing);
      final comps =
          (it['components'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      for (final c in comps) {
        out.add(c['name'] as String? ?? '');
      }
    }
    return out.where((s) => s.isNotEmpty).toList();
  }

  double sumKey(List<Map<String, dynamic>> items, String k) =>
      items.fold(0.0, (s, it) => s + ((it[k] as num?)?.toDouble() ?? 0));

  /// Evalúa un plan y devuelve (nota, líneas de detalle).
  (double, List<String>) gradePlan(
    Map<String, dynamic> plan,
    _Profile p,
  ) {
    final items = (plan['items'] as List).cast<Map<String, dynamic>>();
    final tKcal = (plan['total_calories'] as num).toDouble();
    final tProt = (plan['protein_grams'] as num).toDouble();
    final tCarb = (plan['carbs_grams'] as num).toDouble();
    final tFat = (plan['fats_grams'] as num).toDouble();

    final aKcal = sumKey(items, 'calories');
    final aProt = sumKey(items, 'protein');
    final aCarb = sumKey(items, 'carbs');
    final aFat = sumKey(items, 'fats');

    final notes = <String>[];
    double score = 0;

    // ── Calorías (3 pts) ──
    final kErr = (aKcal - tKcal).abs() / tKcal;
    final double kPts = kErr <= 0.08
        ? 3
        : kErr <= 0.15
            ? 2
            : kErr <= 0.25
                ? 1
                : 0;
    score += kPts;

    // ── Proteína (3 pts) — la más importante ──
    final pRatio = tProt > 0 ? aProt / tProt : 1;
    final double pPts = (pRatio >= 0.92 && pRatio <= 1.30)
        ? 3
        : ((pRatio >= 0.80 && pRatio < 0.92) || (pRatio > 1.30 && pRatio <= 1.5))
            ? 2
            : (pRatio >= 0.70 && pRatio < 0.80)
                ? 1
                : 0;
    score += pPts;

    // ── Carbos (1.5 pts) ──
    final cErr = tCarb > 0 ? (aCarb - tCarb).abs() / tCarb : 0;
    score += cErr <= 0.20 ? 1.5 : (cErr <= 0.35 ? 0.75 : 0);

    // ── Grasas (1.5 pts) ──
    final fErr = tFat > 0 ? (aFat - tFat).abs() / tFat : 0;
    score += fErr <= 0.20 ? 1.5 : (fErr <= 0.35 ? 0.75 : 0);

    // ── Cumplimiento de dieta + alergias (1 pt, duro) ──
    final texts = planTexts(items);
    var compliant = true;
    if (p.dietPref == 'vegana') {
      for (final t in texts) {
        if (textHasAny(t, meatKw) ||
            textHasAny(t, fishKw) ||
            textHasAny(t, animalKw)) {
          compliant = false;
          notes.add('❌ vegano violado por: "$t"');
          break;
        }
      }
    } else if (p.dietPref == 'vegetariana') {
      for (final t in texts) {
        if (textHasAny(t, meatKw) || textHasAny(t, fishKw)) {
          compliant = false;
          notes.add('❌ vegetariano violado por: "$t"');
          break;
        }
      }
    }
    if (p.allergies.isNotEmpty) {
      for (final t in texts) {
        if (SimulatedAIService.textHasAllergen(t, p.allergies)) {
          compliant = false;
          notes.add('❌ alérgeno (${p.allergies.join(",")}) en: "$t"');
          break;
        }
      }
    }
    if (p.dietPref == 'lowcarb') {
      // Low-carb: penaliza recetas claramente altas en carbo.
      for (final it in items) {
        final name = (it['name'] as String? ?? '');
        final ing = ((it['ingredients'] as List?)?.cast<String>() ?? const [])
            .join(' ');
        if (textHasAny('$name $ing', highCarbKw)) {
          notes.add('⚠️ low-carb con item alto en carbo: "$name"');
          break;
        }
      }
    }
    score += compliant ? 1 : 0;

    // Penalización dura: comidas vacías.
    final emptyMeals = items.where((it) => (it['calories'] as int? ?? 0) <= 0);
    if (emptyMeals.isNotEmpty) {
      score -= 2;
      notes.add('❌ ${emptyMeals.length} comida(s) vacía(s)');
    }

    score = score.clamp(0, 10);

    notes.insert(0,
        'kcal ${aKcal.round()}/${tKcal.round()} (${(kErr * 100).toStringAsFixed(0)}%) · '
        'P ${aProt.round()}/${tProt.round()}g (${(pRatio * 100).toStringAsFixed(0)}%) · '
        'C ${aCarb.round()}/${tCarb.round()}g · '
        'G ${aFat.round()}/${tFat.round()}g · '
        'comidas ${items.length}');
    return (double.parse(score.toStringAsFixed(1)), notes);
  }

  // ── Usuarios sintéticos ──────────────────────────────────────────────────
  final profiles = <_Profile>[
    _Profile('U1 H mantener normal 3c', goal: 'MAINTAIN', gender: 'MALE',
        weight: 80, target: 80, meals: '3'),
    _Profile('U2 H ganar musculo 4c', goal: 'GAIN_MUSCLE', gender: 'MALE',
        weight: 75, target: 80, meals: '4', trainingDays: 5),
    _Profile('U3 M perder peso 3c', goal: 'LOSE_WEIGHT', gender: 'FEMALE',
        weight: 68, target: 60, meals: '3'),
    _Profile('U4 M perder vegetariana 3c', goal: 'LOSE_WEIGHT',
        gender: 'FEMALE', weight: 65, target: 58, meals: '3',
        prefs: ['vegetarian']),
    _Profile('U5 H ganar vegano 5c', goal: 'GAIN_MUSCLE', gender: 'MALE',
        weight: 78, target: 84, meals: '5', trainingDays: 5,
        prefs: ['vegan']),
    _Profile('U6 H mantener keto 3c', goal: 'MAINTAIN', gender: 'MALE',
        weight: 82, target: 82, meals: '3', prefs: ['keto']),
    _Profile('U7 M mantener alta-proteina 4c', goal: 'MAINTAIN',
        gender: 'FEMALE', weight: 62, target: 62, meals: '4',
        prefs: ['high_protein']),
    _Profile('U8 H perder alergia mani+mariscos gourmet', goal: 'LOSE_WEIGHT',
        gender: 'MALE', weight: 90, target: 82, meals: '3',
        allergies: ['nuts', 'seafood'], cooking: 'enjoy_cooking'),
    _Profile('U9 M mantener ayuno 2c', goal: 'MAINTAIN', gender: 'FEMALE',
        weight: 60, target: 60, meals: 'ayuno'),
    _Profile('U10 H ganar gourmet 5c', goal: 'GAIN_MUSCLE', gender: 'MALE',
        weight: 85, target: 90, meals: '5', trainingDays: 6,
        cooking: 'enjoy_cooking'),
  ];

  test('Calidad de planes de alimentación — nota 1 a 10 por usuario', () {
    const gen = DbMealPlanGenerator();
    final grades = <double>[];
    final buffer = StringBuffer();
    buffer.writeln('\n══════════ EVALUACIÓN DE PLANES DE ALIMENTACIÓN ══════════');

    for (var i = 0; i < profiles.length; i++) {
      final p = profiles[i];
      final input = MealPlanInput(
        goal: p.goal,
        gender: p.gender,
        weightKg: p.weight,
        targetWeightKg: p.target,
        age: 30,
        heightCm: p.gender == 'FEMALE' ? 165 : 178,
        trainingDaysPerWeek: p.trainingDays,
        mealsPerDay: p.meals,
        foodPreferences: p.prefs,
        allergies: p.allergies,
        cookingTime: p.cooking,
        userId: 'test-user-$i',
      );
      final plan = gen.buildPlan(
          input: input, templates: templates, catalog: catalog);
      final (grade, notes) = gradePlan(plan, p);
      grades.add(grade);

      buffer.writeln('\n${p.name}');
      buffer.writeln('  NOTA: $grade / 10');
      for (final n in notes) {
        buffer.writeln('  $n');
      }
      // Muestra las comidas del plan.
      for (final it in (plan['items'] as List).cast<Map<String, dynamic>>()) {
        final comps =
            (it['components'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final detalle = comps.isEmpty
            ? (it['ingredients'] as List?)?.join(', ') ?? ''
            : comps.map((c) => c['name']).join(' + ');
        buffer.writeln(
            '    • [${it['meal_type']}] ${it['name']} — ${it['calories']} kcal '
            '${detalle.isNotEmpty ? "($detalle)" : ""}');
      }
    }

    final avg = grades.reduce((a, b) => a + b) / grades.length;
    buffer.writeln('\n──────────────────────────────────────────────');
    buffer.writeln('PROMEDIO GENERAL: ${avg.toStringAsFixed(1)} / 10');
    buffer.writeln('Peor plan: ${grades.reduce((a, b) => a < b ? a : b)}');
    buffer.writeln('Mejor plan: ${grades.reduce((a, b) => a > b ? a : b)}');
    buffer.writeln('══════════════════════════════════════════════\n');
    // ignore: avoid_print
    print(buffer.toString());

    // Umbrales de aprobación (ajustables): el módulo no debería degradarse.
    expect(avg, greaterThanOrEqualTo(6.0),
        reason: 'El promedio de calidad de planes bajó de 6/10');
    expect(grades.every((g) => g >= 4.0), isTrue,
        reason: 'Hay al menos un plan con nota < 4/10');
  });
}

class _Profile {
  final String name;
  final String goal;
  final String gender;
  final double weight;
  final double target;
  final String meals;
  final int trainingDays;
  final List<String> prefs;
  final List<String> allergies;
  final String? cooking;

  _Profile(
    this.name, {
    required this.goal,
    required this.gender,
    required this.weight,
    required this.target,
    required this.meals,
    this.trainingDays = 3,
    this.prefs = const [],
    this.allergies = const [],
    this.cooking,
  });

  String get dietPref => SimulatedAIService.dominantDietPref(prefs);
}
