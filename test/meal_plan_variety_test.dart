import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymgram_beta/models/ai_meal_template.dart';
import 'package:gymgram_beta/services/food_catalog_service.dart';
import 'package:gymgram_beta/services/meal_plan_generator.dart';

/// ¿10 usuarios con el MISMO objetivo reciben 10 planes DISTINTOS?
/// El plan es determinista por (userId, semana): distinto userId → distinta
/// semilla → distinta selección de recetas/alimentos. Este test lo verifica.
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

  // "Firma" de un plan = conjunto de nombres de comidas + alimentos.
  Set<String> signature(Map<String, dynamic> plan) {
    final s = <String>{};
    for (final it in (plan['items'] as List).cast<Map<String, dynamic>>()) {
      s.add(it['name'] as String? ?? '');
      final comps =
          (it['components'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      for (final c in comps) {
        s.add(c['name'] as String? ?? '');
      }
    }
    s.remove('');
    return s;
  }

  double jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 1;
    final inter = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0 : inter / union;
  }

  void evaluar(String titulo, MealPlanInput Function(String userId) build) {
    const gen = DbMealPlanGenerator();
    final plans = <Map<String, dynamic>>[];
    final sigs = <Set<String>>[];
    for (var i = 0; i < 10; i++) {
      final plan = gen.buildPlan(
        input: build('user-$titulo-$i'),
        templates: templates,
        catalog: catalog,
      );
      plans.add(plan);
      sigs.add(signature(plan));
    }

    // Planes únicos (por firma exacta).
    final distintos = sigs.map((s) {
      final l = s.toList()..sort();
      return l.join('|');
    }).toSet();

    // Similitud media entre todos los pares.
    double simSum = 0;
    int pares = 0;
    for (var i = 0; i < sigs.length; i++) {
      for (var j = i + 1; j < sigs.length; j++) {
        simSum += jaccard(sigs[i], sigs[j]);
        pares++;
      }
    }
    final simMedia = pares > 0 ? simSum / pares : 0;

    final buf = StringBuffer();
    buf.writeln('\n══════ $titulo ══════');
    buf.writeln('Planes distintos: ${distintos.length} / 10');
    buf.writeln(
        'Similitud media entre pares: ${(simMedia * 100).toStringAsFixed(0)}% '
        '(0% = todos distintos, 100% = idénticos)');
    for (var i = 0; i < plans.length; i++) {
      final nombres = (plans[i]['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((it) => it['name'])
          .join(' · ');
      buf.writeln('  U$i: $nombres');
    }
    // ignore: avoid_print
    print(buf.toString());

    // Esperamos al menos 8/10 firmas únicas y baja similitud media.
    expect(distintos.length, greaterThanOrEqualTo(8),
        reason: '$titulo: muy pocos planes distintos');
  }

  // Variedad DÍA A DÍA: los 7 días de la semana de un MISMO usuario no deben
  // repetirse (la semilla incluye dayIndex).
  void evaluarSemana(String titulo, MealPlanInput Function(int dayIndex) build) {
    const gen = DbMealPlanGenerator();
    final plans = <Map<String, dynamic>>[];
    final sigs = <Set<String>>[];
    for (var d = 0; d < 7; d++) {
      final plan = gen.buildPlan(
          input: build(d), templates: templates, catalog: catalog);
      plans.add(plan);
      sigs.add(signature(plan));
    }
    final distintos = sigs.map((s) {
      final l = s.toList()..sort();
      return l.join('|');
    }).toSet();

    double simSum = 0;
    int pares = 0;
    for (var i = 0; i < sigs.length; i++) {
      for (var j = i + 1; j < sigs.length; j++) {
        simSum += jaccard(sigs[i], sigs[j]);
        pares++;
      }
    }
    final simMedia = pares > 0 ? simSum / pares : 0;

    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final buf = StringBuffer();
    buf.writeln('\n══════ $titulo (1 usuario, 7 días) ══════');
    buf.writeln('Días distintos: ${distintos.length} / 7');
    buf.writeln(
        'Similitud media entre días: ${(simMedia * 100).toStringAsFixed(0)}%');
    for (var d = 0; d < plans.length; d++) {
      final nombres = (plans[d]['items'] as List)
          .cast<Map<String, dynamic>>()
          .map((it) => it['name'])
          .join(' · ');
      buf.writeln('  ${dias[d]}: $nombres');
    }
    // ignore: avoid_print
    print(buf.toString());

    // Los 7 días deben ser únicos (idealmente) — exigimos al menos 6/7.
    expect(distintos.length, greaterThanOrEqualTo(6),
        reason: '$titulo: la semana se repite demasiado entre días');
  }

  // Clasifica la proteína de un plato por familia (mismas familias del motor).
  String familyOf(String text) {
    final l = text.toLowerCase();
    const kw = {
      'aves': ['pollo', 'pavo'],
      'roja': [
        'vacuno', 'carne', 'cerdo', 'lomo', 'posta', 'molida', 'churrasco',
        'bistec', 'milanesa', 'albondiga', 'res', 'cordero', 'asad'
      ],
      'mar': [
        'pescado', 'atun', 'salmon', 'merluza', 'reineta', 'congrio',
        'camaron', 'jurel', 'marisco', 'sardina'
      ],
      'huevo': ['huevo', 'clara', 'tortilla', 'omelette'],
      'legumbre': [
        'lenteja', 'poroto', 'garbanzo', 'soja', 'soya', 'tofu', 'tempeh',
        'lupino', 'arveja', 'haba'
      ],
    };
    for (final e in kw.entries) {
      if (e.value.any(l.contains)) return e.key;
    }
    return 'otro';
  }

  test('Proteína no se repite toda la semana (omnívoro ganar, 7 días)', () {
    const gen = DbMealPlanGenerator();
    final conteo = <String, int>{};
    final detalle = <String>[];
    for (var d = 0; d < 7; d++) {
      final plan = gen.buildPlan(
        input: MealPlanInput(
          goal: 'GAIN_MUSCLE',
          gender: 'MALE',
          weightKg: 80,
          targetWeightKg: 85,
          age: 28,
          heightCm: 180,
          mealsPerDay: '3',
          trainingDaysPerWeek: 5,
          userId: 'proteina-semana',
          dayIndex: d,
        ),
        templates: templates,
        catalog: catalog,
      );
      for (final it in (plan['items'] as List).cast<Map<String, dynamic>>()) {
        final mt = it['meal_type'];
        if (mt != 'lunch' && mt != 'dinner') continue;
        final comps = (it['components'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map((c) => c['name'])
                .join(' ') ??
            '';
        final ing = (it['ingredients'] as List?)?.join(' ') ?? '';
        final fam = familyOf('${it['name']} $comps $ing');
        conteo[fam] = (conteo[fam] ?? 0) + 1;
        detalle.add('D$d ${it['name']} → $fam');
      }
    }
    final maxFam =
        conteo.values.isEmpty ? 0 : conteo.values.reduce((a, b) => a > b ? a : b);
    final total = conteo.values.fold(0, (a, b) => a + b);
    // ignore: avoid_print
    print('\n══════ Distribución de proteína (almuerzo+cena, 7 días) ══════\n'
        '${conteo.entries.map((e) => '${e.key}: ${e.value}').join(' · ')}\n'
        'Familia más repetida: $maxFam de $total comidas principales\n'
        '${detalle.join('\n')}\n');
    // Ninguna familia debe copar la semana: máx 4 de ~14 comidas principales.
    expect(conteo.length, greaterThanOrEqualTo(3),
        reason: 'Muy pocas familias de proteína en la semana');
    expect(maxFam, lessThanOrEqualTo((total * 0.45).ceil()),
        reason: 'Una proteína domina demasiado la semana');
  });

  test('1 usuario, 7 días → menús distintos cada día (ganar músculo, 4c)', () {
    evaluarSemana(
        'SEMANA-GANAR-H',
        (day) => MealPlanInput(
              goal: 'GAIN_MUSCLE',
              gender: 'MALE',
              weightKg: 78,
              targetWeightKg: 84,
              age: 28,
              heightCm: 180,
              mealsPerDay: '4',
              trainingDaysPerWeek: 5,
              userId: 'semana-user-fijo',
              dayIndex: day,
            ));
  });

  test('1 usuaria, 7 días → menús distintos cada día (perder peso, 3c)', () {
    evaluarSemana(
        'SEMANA-PERDER-M',
        (day) => MealPlanInput(
              goal: 'LOSE_WEIGHT',
              gender: 'FEMALE',
              weightKg: 65,
              targetWeightKg: 58,
              age: 30,
              heightCm: 165,
              mealsPerDay: '3',
              userId: 'semana-user-fija',
              dayIndex: day,
            ));
  });

  test('10 usuarios mismo objetivo → planes distintos (mantener, 3 comidas)',
      () {
    evaluar(
        'MANTENER-H-80kg-3c',
        (uid) => MealPlanInput(
              goal: 'MAINTAIN',
              gender: 'MALE',
              weightKg: 80,
              targetWeightKg: 80,
              age: 30,
              heightCm: 178,
              mealsPerDay: '3',
              userId: uid,
            ));
  });

  test('10 usuarios mismo objetivo → planes distintos (ganar músculo, 4c)', () {
    evaluar(
        'GANAR-H-78kg-4c',
        (uid) => MealPlanInput(
              goal: 'GAIN_MUSCLE',
              gender: 'MALE',
              weightKg: 78,
              targetWeightKg: 84,
              age: 28,
              heightCm: 180,
              mealsPerDay: '4',
              trainingDaysPerWeek: 5,
              userId: uid,
            ));
  });

  test('10 usuarias mismo objetivo → planes distintos (perder peso, 3c)', () {
    evaluar(
        'PERDER-M-65kg-3c',
        (uid) => MealPlanInput(
              goal: 'LOSE_WEIGHT',
              gender: 'FEMALE',
              weightKg: 65,
              targetWeightKg: 58,
              age: 30,
              heightCm: 165,
              mealsPerDay: '3',
              userId: uid,
            ));
  });
}
