import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/country_utils.dart';
import '../core/input_sanitizers.dart';
import '../models/food_item.dart';
import '../models/food_log.dart';
import 'badge_service.dart';

class FoodService {
  static final FoodService instance = FoodService._();
  FoodService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  static const _offSearchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';
  static const _offUserAgent = 'GymGramBeta/1.0 (support@gymgram.app)';
  final Map<String, List<FoodItem>> _offSearchCache = {};
  String? _countryCodeCache;

  Future<List<FoodItem>> searchFoods(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final countryCode = await _userCountryCode();

    final results = await Future.wait([
      _searchCustomFoods(q, countryCode),
      q.length >= 3
          ? _searchOpenFoodFacts(q, countryCode)
          : Future.value(<FoodItem>[]),
    ]);

    final custom = results[0];
    final off = results[1];

    final customNames = custom.map((f) => f.name.toLowerCase()).toSet();
    final uniqueOff =
        off.where((f) => !customNames.contains(f.name.toLowerCase())).toList();

    return [...custom, ...uniqueOff];
  }

  Future<String> _userCountryCode() async {
    if (_countryCodeCache != null) return _countryCodeCache!;
    final uid = _uid;
    if (uid == null) {
      _countryCodeCache = CountryUtils.detectDeviceCountry();
      return _countryCodeCache!;
    }
    try {
      final row = await _client
          .from('profiles')
          .select('country_code')
          .eq('id', uid)
          .maybeSingle();
      _countryCodeCache = CountryUtils.normalize(
        row?['country_code'] as String?,
        fallback: CountryUtils.detectDeviceCountry(),
      );
    } catch (_) {
      _countryCodeCache = CountryUtils.detectDeviceCountry();
    }
    return _countryCodeCache!;
  }

  Future<List<FoodItem>> _searchCustomFoods(
    String query,
    String countryCode,
  ) async {
    final q = InputSanitizers.safePostgrestLike(query.toLowerCase());
    if (q.isEmpty) return [];
    final country = CountryUtils.normalize(countryCode);
    try {
      final rows = await _client
          .from('custom_foods')
          .select(
            'name, kcal_per_100g, protein_per_100g, carbs_per_100g, '
            'fat_per_100g, fiber_per_100g, serving_grams, '
            'serving_description, country_relevance',
          )
          .or('name_normalized.ilike.%$q%,name.ilike.%$q%')
          .order('name')
          .limit(50);
      final foods = rows.map((r) => FoodItem.fromCustomFood(r)).toList();
      final local = foods.where((f) {
        if (f.countryRelevance.isEmpty) return true;
        return f.countryRelevance.contains(country);
      }).toList();
      if (local.isNotEmpty || country != CountryUtils.defaultCountry) {
        return local.take(20).toList();
      }
      return foods.take(20).toList();
    } catch (e) {
      debugPrint('FoodService._searchCustomFoods error: $e');
      return [];
    }
  }

  Future<List<FoodItem>> _searchOpenFoodFacts(
    String query,
    String countryCode,
  ) async {
    final country = CountryUtils.normalize(countryCode);
    final cacheKey = '${country.toLowerCase()}:${query.toLowerCase()}';
    if (_offSearchCache.containsKey(cacheKey)) return _offSearchCache[cacheKey]!;
    final uri = Uri.parse(_offSearchUrl).replace(queryParameters: {
      'search_terms': query,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '25',
      'lc': CountryUtils.languageFor(country),
      'cc': country.toLowerCase(),
      'fields':
          'id,code,product_name,brands,nutriments,image_small_url,countries_tags',
    });
    try {
      final res = await http
          .get(uri, headers: {'User-Agent': _offUserAgent})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final body = json.decode(res.body) as Map<String, dynamic>;
      final products = (body['products'] as List?) ?? [];
      final results = <FoodItem>[];
      for (final raw in products) {
        if (raw is! Map<String, dynamic>) continue;
        final item = FoodItem.fromOpenFoodFacts(raw);
        if (item != null) results.add(item);
      }
      final local = results.where((f) => _matchesCountry(f, country)).toList();
      final sorted = local.isEmpty
          ? results
          : [...local, ...results.where((f) => !_matchesCountry(f, country))];
      _offSearchCache[cacheKey] = sorted;
      return sorted;
    } catch (e) {
      debugPrint('FoodService._searchOpenFoodFacts error: $e');
      return [];
    }
  }

  Future<FoodItem?> lookupBarcode(String barcode) async {
    final country = await _userCountryCode();
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json?cc=${country.toLowerCase()}&lc=${CountryUtils.languageFor(country)}&fields=id,code,product_name,brands,nutriments,image_small_url,countries_tags',
    );
    try {
      final res = await http
          .get(uri, headers: {'User-Agent': _offUserAgent})
          .timeout(const Duration(seconds: 10));
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

  bool _matchesCountry(FoodItem food, String countryCode) {
    if (food.countriesTags.isEmpty) return false;
    final countryName = CountryUtils.openFoodFactsCountryTag(countryCode);
    if (countryName.isEmpty) return false;
    return food.countriesTags.any(
      (tag) => tag.endsWith(':$countryName'),
    );
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
