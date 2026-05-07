import 'package:supabase_flutter/supabase_flutter.dart';

class MealService {
  static final MealService instance = MealService._();
  MealService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // Devuelve el plan de alimentación de una fecha concreta
  Future<Map<String, dynamic>?> getMealPlanForDate(DateTime date) async {
    final uid = _uid;
    if (uid == null) return null;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final plan = await _client
        .from('meal_plans')
        .select('*, meal_items(*)')
        .eq('user_id', uid)
        .eq('target_date', dateStr)
        .maybeSingle();

    return plan;
  }

  // Crea un plan de comidas con sus items
  Future<String> saveMealPlan({
    required String title,
    required String foodMode,
    required DateTime targetDate,
    required int totalCalories,
    required List<Map<String, dynamic>> items,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('No hay usuario autenticado');

    final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    // Upsert del plan (uno por día)
    final plan = await _client.from('meal_plans').upsert({
      'user_id': uid,
      'title': title,
      'food_mode': foodMode,
      'target_date': dateStr,
      'total_calories': totalCalories,
    }, onConflict: 'user_id, target_date').select().single();

    final planId = plan['id'] as String;

    // Reemplaza los items
    await _client.from('meal_items').delete().eq('meal_plan_id', planId);
    if (items.isNotEmpty) {
      final rows = items.asMap().entries.map((e) => {
        'meal_plan_id': planId,
        'meal_type': e.value['meal_type'],
        'name': e.value['name'],
        'ingredients': e.value['ingredients'] ?? [],
        'calories': e.value['calories'] ?? 0,
        'protein': e.value['protein'],
        'carbs': e.value['carbs'],
        'fats': e.value['fats'],
        'order_index': e.key,
      }).toList();
      await _client.from('meal_items').insert(rows);
    }

    return planId;
  }

  // Marca o desmarca un item como completado
  Future<void> toggleMealItem(String itemId, {required bool completed}) async {
    await _client.from('meal_items').update({'completed': completed}).eq('id', itemId);
  }
}
