import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food_item.dart';
import '../models/food_log.dart';
import 'badge_service.dart';

class FoodService {
  static final FoodService instance = FoodService._();
  FoodService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  static const _offSearchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';

  Future<List<FoodItem>> searchFoods(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];

    final results = await Future.wait([
      _searchCustomFoods(q),
      _searchOpenFoodFacts(q),
    ]);

    final custom = results[0];
    final off = results[1];

    final customNames = custom.map((f) => f.name.toLowerCase()).toSet();
    final uniqueOff = off.where((f) => !customNames.contains(f.name.toLowerCase())).toList();

    return [...custom, ...uniqueOff];
  }

  Future<List<FoodItem>> _searchCustomFoods(String query) async {
    final q = query.toLowerCase().trim();
    try {
      final rows = await _client
          .from('custom_foods')
          .select('name, kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, fiber_per_100g, serving_grams, serving_description')
          .or('name_normalized.ilike.%$q%,name.ilike.%$q%')
          .order('name')
          .limit(20);
      return rows.map((r) => FoodItem.fromCustomFood(r)).toList();
    } catch (e) {
      debugPrint('FoodService._searchCustomFoods error: $e');
      return [];
    }
  }

  Future<List<FoodItem>> _searchOpenFoodFacts(String query) async {
    final uri = Uri.parse(_offSearchUrl).replace(queryParameters: {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '25',
      'lc': 'es',
      'fields': 'id,code,product_name,brands,nutriments,image_small_url',
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body) as Map<String, dynamic>;
      final products = (body['products'] as List?) ?? [];
      final results = <FoodItem>[];
      for (final raw in products) {
        if (raw is! Map<String, dynamic>) continue;
        final item = FoodItem.fromOpenFoodFacts(raw);
        if (item != null) results.add(item);
      }
      return results;
    } catch (e) {
      debugPrint('FoodService._searchOpenFoodFacts error: $e');
      return [];
    }
  }

  Future<FoodItem?> lookupBarcode(String barcode) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name,brands,nutriments,image_small_url',
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null;
      final product = body['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      return FoodItem.fromOpenFoodFacts(product);
    } catch (e) {
      debugPrint('FoodService.lookupBarcode error: $e');
      rethrow;
    }
  }

  Future<FoodLog> logFood(
    FoodItem food,
    double grams,
    String mealType, {
    DateTime? date,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    if (grams <= 0) throw ArgumentError('grams debe ser mayor a 0');
    final logDate = date ?? DateTime.now();
    final log = FoodLog(
      id: '',
      userId: uid,
      logDate: logDate,
      mealType: mealType,
      foodName: food.name,
      brand: food.brand,
      offProductId: food.offProductId,
      imageUrl: food.imageUrl,
      grams: grams,
      kcalPer100g: food.kcalPer100g,
      proteinPer100g: food.proteinPer100g,
      carbsPer100g: food.carbsPer100g,
      fatPer100g: food.fatPer100g,
      kcalTotal: food.kcalFor(grams),
      proteinTotal: food.proteinFor(grams),
      carbsTotal: food.carbsFor(grams),
      fatTotal: food.fatFor(grams),
      fiberPer100g: food.fiberPer100g,
      fiberTotal: food.fiberFor(grams),
      createdAt: DateTime.now(),
    );
    final inserted =
        await _client.from('food_logs').insert(log.toInsertMap()).select().single();
    await BadgeService.instance.checkAndAwardBadges(uid, 'meal_plan_completed');
    return FoodLog.fromMap(inserted);
  }

  /// Registra una comida del plan sugerido como una entrada en food_logs,
  /// usando los totales ya calculados del item (suma de sus componentes).
  Future<FoodLog> logPlanMeal(
    Map<String, dynamic> meal, {
    DateTime? date,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    final logDate = date ?? DateTime.now();
    final mealType = (meal['meal_type'] as String?) ?? 'snack';

    final components =
        (meal['components'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    double grams = 0;
    for (final c in components) {
      grams += (c['grams'] as num?)?.toDouble() ?? 0;
    }
    if (grams <= 0) grams = (meal['porcion_g'] as num?)?.toDouble() ?? 0;
    if (grams <= 0) grams = 1; // food_logs exige grams > 0

    double? d(dynamic v) => v == null ? null : (v as num).toDouble();

    final log = FoodLog(
      id: '',
      userId: uid,
      logDate: logDate,
      mealType: mealType,
      foodName: (meal['name'] as String?)?.trim().isNotEmpty == true
          ? meal['name'] as String
          : 'Comida del plan',
      grams: grams,
      kcalTotal: d(meal['calories']),
      proteinTotal: d(meal['protein']),
      carbsTotal: d(meal['carbs']),
      fatTotal: d(meal['fats']),
      createdAt: DateTime.now(),
    );

    final inserted = await _client
        .from('food_logs')
        .insert(log.toInsertMap())
        .select()
        .single();
    await BadgeService.instance.checkAndAwardBadges(uid, 'meal_plan_completed');
    return FoodLog.fromMap(inserted);
  }

  /// Registra un componente suelto (alimento simple) de una comida del plan,
  /// para poder checkear alimento por alimento estilo Fitia.
  Future<FoodLog> logPlanComponent(
    Map<String, dynamic> component,
    String mealType, {
    DateTime? date,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    final logDate = date ?? DateTime.now();
    double? d(dynamic v) => v == null ? null : (v as num).toDouble();

    double grams = (component['grams'] as num?)?.toDouble() ?? 0;
    if (grams <= 0) grams = 1; // food_logs exige grams > 0

    final log = FoodLog(
      id: '',
      userId: uid,
      logDate: logDate,
      mealType: mealType,
      foodName: (component['name'] as String?)?.trim().isNotEmpty == true
          ? component['name'] as String
          : 'Alimento del plan',
      grams: grams,
      kcalTotal: d(component['calories']),
      proteinTotal: d(component['protein']),
      carbsTotal: d(component['carbs']),
      fatTotal: d(component['fats']),
      createdAt: DateTime.now(),
    );

    final inserted = await _client
        .from('food_logs')
        .insert(log.toInsertMap())
        .select()
        .single();
    await BadgeService.instance.checkAndAwardBadges(uid, 'meal_plan_completed');
    return FoodLog.fromMap(inserted);
  }

  Future<List<FoodLog>> getDailyLog(DateTime date) async {
    final uid = _uid;
    if (uid == null) return [];
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('food_logs')
        .select()
        .eq('user_id', uid)
        .eq('log_date', dateStr)
        .order('created_at', ascending: true);
    return rows.map((r) => FoodLog.fromMap(r)).toList();
  }

  Future<void> deleteFoodLog(String logId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    await _client.from('food_logs').delete().eq('id', logId).eq('user_id', uid);
  }

  Future<Map<String, double>> getDailyTotals(DateTime date) async {
    final logs = await getDailyLog(date);
    double kcal = 0, protein = 0, carbs = 0, fat = 0;
    for (final log in logs) {
      kcal += log.kcalTotal ?? 0;
      protein += log.proteinTotal ?? 0;
      carbs += log.carbsTotal ?? 0;
      fat += log.fatTotal ?? 0;
    }
    return {
      'kcal': double.parse(kcal.toStringAsFixed(1)),
      'protein': double.parse(protein.toStringAsFixed(1)),
      'carbs': double.parse(carbs.toStringAsFixed(1)),
      'fat': double.parse(fat.toStringAsFixed(1)),
    };
  }
}
