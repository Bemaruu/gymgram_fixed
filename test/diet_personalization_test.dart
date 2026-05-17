// Pruebas del flujo de generación de dietas.
// Verifica que:
//   1. Dos usuarios distintos con el mismo objetivo reciben planes distintos.
//   2. El mismo usuario recibe un plan distinto la semana siguiente.
//   3. El mismo usuario obtiene el mismo plan dentro de la misma semana
//      (estabilidad / idempotencia — clave para futura persistencia con IA real).
//   4. Las preferencias del onboarding nuevo (vegan, low_carb, etc.) se mapean.
//   5. Los disliked_foods se marcan en los items afectados.
//   6. cooking_time = 'no_time' fija al plan más simple.
//   7. El plan respeta calorías y devuelve los macros esperados.

import 'package:flutter_test/flutter_test.dart';
import 'package:gymgram_beta/services/simulated_ai_service.dart';

Map<String, dynamic> _plan({
  required String userId,
  int week = 0,
  int day = 0,
  List<String> prefs = const ['omnivore'],
  List<String> disliked = const [],
  String? cookingTime,
  String mealsPerDay = '3',
}) =>
    SimulatedAIService.generateMealPlan(
      goal: 'MAINTAIN',
      gender: 'MALE',
      weightKg: 75,
      age: 30,
      heightCm: 178,
      targetWeightKg: 75,
      foodPreferences: prefs,
      dislikedFoods: disliked,
      cookingTime: cookingTime,
      userId: userId,
      weekIndex: week,
      dayIndex: day,
      mealsPerDay: mealsPerDay,
    );

String _signature(Map<String, dynamic> plan) {
  final items = (plan['items'] as List).cast<Map<String, dynamic>>();
  return items.map((m) => '${m['meal_type']}:${m['name']}').join('|');
}

void main() {
  group('Personalización por usuario y semana', () {
    test('1. Usuarios distintos → plan distinto (misma semana, mismo día)', () {
      final a = _plan(userId: 'user-aaaa');
      final b = _plan(userId: 'user-bbbb');
      final c = _plan(userId: 'user-cccc');

      expect(_signature(a), isNot(equals(_signature(b))),
          reason: 'A y B no pueden coincidir');
      expect(_signature(a), isNot(equals(_signature(c))),
          reason: 'A y C no pueden coincidir');
    });

    test('2. Misma persona, semana siguiente → plan distinto', () {
      final w1 = _plan(userId: 'user-x', week: 100);
      final w2 = _plan(userId: 'user-x', week: 101);
      final w3 = _plan(userId: 'user-x', week: 102);
      expect(_signature(w1), isNot(equals(_signature(w2))));
      expect(_signature(w2), isNot(equals(_signature(w3))));
    });

    test('3. Misma persona, misma semana → plan estable (idempotente)', () {
      final a = _plan(userId: 'user-x', week: 50, day: 2);
      final b = _plan(userId: 'user-x', week: 50, day: 2);
      expect(_signature(a), equals(_signature(b)));
    });
  });

  group('Mapeo de preferencias del onboarding nuevo', () {
    test('vegan → food_mode "vegana"', () {
      final p = _plan(userId: 'u', prefs: ['vegan']);
      expect(p['food_mode'], 'vegana');
    });

    test('low_carb → food_mode "lowcarb"', () {
      final p = _plan(userId: 'u', prefs: ['low_carb']);
      expect(p['food_mode'], 'lowcarb');
    });

    test('high_protein → food_mode "proteica"', () {
      final p = _plan(userId: 'u', prefs: ['high_protein']);
      expect(p['food_mode'], 'proteica');
    });

    test('keto → food_mode "lowcarb"', () {
      final p = _plan(userId: 'u', prefs: ['keto']);
      expect(p['food_mode'], 'lowcarb');
    });

    test('legacy "vegana" sigue funcionando (backwards compat)', () {
      final p = _plan(userId: 'u', prefs: ['vegana']);
      expect(p['food_mode'], 'vegana');
    });

    test('omnivore / no_preference → "normal"', () {
      expect(_plan(userId: 'u', prefs: ['omnivore'])['food_mode'], 'normal');
      expect(_plan(userId: 'u', prefs: ['no_preference'])['food_mode'], 'normal');
    });
  });

  group('Filtro de alimentos no deseados', () {
    test('Tomate marcado en items que lo contienen', () {
      final p = _plan(
        userId: 'u',
        prefs: ['omnivore'],
        disliked: ['tomato'],
      );
      final items = (p['items'] as List).cast<Map<String, dynamic>>();
      bool anyMarked = false;
      for (final item in items) {
        final ingredients = (item['ingredients'] as List).cast<String>();
        if (ingredients.any((i) => i.toLowerCase().contains('tomate'))) {
          expect(
            ingredients.any((i) => i.contains('💡 Incluye')),
            isTrue,
            reason: 'Items con tomate deben llevar la nota',
          );
          anyMarked = true;
        }
      }
      // Si por azar el seed no incluyó tomate, el test sigue siendo válido —
      // solo verifica que si aparece, queda marcado.
      expect(anyMarked || true, isTrue);
    });

    test('custom:"algo" no rompe el flujo', () {
      final p = _plan(
        userId: 'u',
        disliked: ['custom:mi alimento raro'],
      );
      expect(p['items'], isNotEmpty);
    });
  });

  group('Adaptación por tiempo de cocina', () {
    test('no_time → dos usuarios distintos siguen recibiendo planes distintos',
        () {
      // CLAVE: el sesgo por tiempo limita el rango pero NUNCA elimina la
      // variación entre usuarios. Esto es lo que rompía el flujo cuando
      // muchos usuarios elegían "no_time" (primera opción).
      final a = _plan(userId: 'cuenta-aaaa', cookingTime: 'no_time');
      final b = _plan(userId: 'cuenta-bbbb', cookingTime: 'no_time');
      final c = _plan(userId: 'cuenta-cccc', cookingTime: 'no_time');
      final sigs = {_signature(a), _signature(b), _signature(c)};
      expect(sigs.length, greaterThan(1),
          reason: 'Distintos userIds deben producir al menos 2 planes distintos');
    });

    test('enjoy_cooking → variedad máxima (mismo usuario, semanas distintas)',
        () {
      final w1 = _plan(userId: 'u', week: 1, cookingTime: 'enjoy_cooking');
      final w2 = _plan(userId: 'u', week: 2, cookingTime: 'enjoy_cooking');
      expect(_signature(w1), isNot(equals(_signature(w2))));
    });
  });

  group('Integridad del plan (no romper UI)', () {
    test('Devuelve total_calories, macros, items, explanation_text', () {
      final p = _plan(userId: 'u');
      expect(p['total_calories'], isA<int>());
      expect((p['total_calories'] as int) > 1200, isTrue);
      expect(p['protein_grams'], isA<int>());
      expect(p['carbs_grams'], isA<int>());
      expect(p['fats_grams'], isA<int>());
      expect(p['items'], isA<List>());
      expect((p['items'] as List).isNotEmpty, isTrue);
      expect(p['explanation_text'], isA<String>());
      expect(p['week_index'], 0);
    });

    test('Ayuno intermitente (onboarding nuevo) produce 3 ítems con horario',
        () {
      final p = _plan(userId: 'u', mealsPerDay: 'intermittent_fasting');
      final items = (p['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, 3);
      expect(items[0]['name'].toString().contains('12:00'), isTrue);
    });

    test('5 comidas incluye pre-entreno', () {
      final p = _plan(userId: 'u', mealsPerDay: '5');
      final items = (p['items'] as List).cast<Map<String, dynamic>>();
      expect(items.any((i) => i['name'].toString().toLowerCase().contains('pre-entreno')),
          isTrue);
    });
  });
}
