import 'dart:async';
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
    final q = query.trim();
    if (q.length < 2) return [];
    final country = CountryUtils.normalize(countryCode);
    try {
      // RPC search_foods usa tsvector (GIN) con ranking + similitud trigrama
      // + bonus por country_relevance/popular_in. Escala a 50k+ filas.
      final rows = await _client.rpc(
        'search_foods',
        params: <String, dynamic>{
          'q': q,
          'country_code': country,
          'exclude_ai_blocked': false,
          'max_results': 30,
        },
      ) as List<dynamic>;
      return rows
          .whereType<Map<String, dynamic>>()
          .map((r) => FoodItem.fromCustomFood(r))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FoodService._searchCustomFoods RPC error, fallback: $e');
      }
      // Fallback: ilike (compatibilidad si la RPC no existe en algún env).
      final q2 = InputSanitizers.safePostgrestLike(q.toLowerCase());
      if (q2.isEmpty) return [];
      try {
        final rows = await _client
            .from('custom_foods')
            .select(
              'name, kcal_per_100g, protein_per_100g, carbs_per_100g, '
              'fat_per_100g, fiber_per_100g, serving_grams, '
              'serving_description, country_relevance',
            )
            .or('name_normalized.ilike.%$q2%,name.ilike.%$q2%')
            .order('name')
            .limit(20);
        return rows
            .map((r) => FoodItem.fromCustomFood(r))
            .toList();
      } catch (e2) {
        debugPrint('FoodService._searchCustomFoods fallback error: $e2');
        return [];
      }
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

  /// Mapea `countries_tags` de OFF a códigos ISO de país, con cap a una
  /// lista corta para no romper el .overlaps() de generate-nutrition-plan.
  /// Si no hay tags, marca GLOBAL.
  List<String> _countryRelevanceFromTags(List<String> tags) {
    if (tags.isEmpty) return const ['GLOBAL'];
    const map = {
      'chile': 'CL',
      'argentina': 'AR',
      'mexico': 'MX',
      'colombia': 'CO',
      'peru': 'PE',
      'spain': 'ES',
      'united-states': 'US',
      'brasil': 'BR',
      'brazil': 'BR',
      'uruguay': 'UY',
      'ecuador': 'EC',
      'venezuela': 'VE',
    };
    final out = <String>{};
    for (final tag in tags) {
      // tag formato "en:chile"
      final i = tag.indexOf(':');
      final key = i >= 0 ? tag.substring(i + 1) : tag;
      final iso = map[key];
      if (iso != null) out.add(iso);
      if (out.length >= 6) break;
    }
    if (out.isEmpty) return const ['GLOBAL'];
    return out.toList(growable: false);
  }

  String _normalize(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Categoría heurística por nombre/marca, para que el alimento OFF
  /// caiga en el grupo correcto del buscador y prompt IA (en caso de
  /// admitirse en futuro).
  String _guessCategoryFromName(String name, String? brand) {
    final s = '${name.toLowerCase()} ${(brand ?? '').toLowerCase()}';
    if (RegExp(r'\b(monster|red bull|powerade|gatorade|coca|sprite|fanta|pepsi|agua|cerveza|vino|jugo|leche|cafe|te|nescafe|smoothie)\b').hasMatch(s)) {
      return 'Bebidas';
    }
    if (RegExp(r'\b(yogur|yogurt|queso|crema|mantequilla|manjar|leche condensada)\b').hasMatch(s)) {
      return 'Lacteos';
    }
    if (RegExp(r'\b(snickers|kitkat|twix|chocolate|chocman|sublime|chips|papas fritas|galleta|barra|cereal|nesquik|milo|chocapic|frosted|corn flakes|quaker)\b').hasMatch(s)) {
      // cereales secos van a Cereales, snacks a Snacks. Heurística simple:
      if (RegExp(r'\b(cereal|corn flakes|chocapic|nesquik cereal|quaker|frosted)\b').hasMatch(s)) {
        return 'Cereales';
      }
      return 'Snacks';
    }
    if (RegExp(r'\b(pan|baguette|hallulla|marraqueta|tortilla|fideos|arroz|avena|quinoa|harina)\b').hasMatch(s)) {
      return 'Cereales';
    }
    if (RegExp(r'\b(pollo|carne|cerdo|atun|salmon|huevo|jamon|pavo|chorizo|tocino|sardinas|whey|proteina)\b').hasMatch(s)) {
      return 'Proteinas';
    }
    if (RegExp(r'\b(lentejas|garbanzos|porotos|frijoles|arvejas|habas|soja|edamame|legumbre)\b').hasMatch(s)) {
      return 'Legumbres';
    }
    if (RegExp(r'\b(tomate|lechuga|cebolla|zanahoria|brocoli|coliflor|espinaca|papa|camote|zapallo|pimenton)\b').hasMatch(s)) {
      return 'Verduras';
    }
    if (RegExp(r'\b(platano|manzana|naranja|pera|uva|sandia|melon|frutilla|kiwi|durazno|pina|palta|aguacate|frambuesa|arandano)\b').hasMatch(s)) {
      return 'Frutas';
    }
    if (RegExp(r'\b(aceite|mantequilla mani|nueces|almendras|chia|linaza|mani)\b').hasMatch(s)) {
      return 'Grasas';
    }
    return 'Snacks'; // default seguro para productos de marca no clasificados
  }

  /// Upsert idempotente del producto OFF en custom_foods. No bloquea el log.
  /// Si el alimento ya existe (off_product_id duplicado) Postgres ignora el
  /// insert por la unique index parcial → no rompe nada.
  Future<void> _cacheOffProductToCustomFoods(FoodItem food) async {
    try {
      if (food.kcalPer100g == null) return;
      final brand = (food.brand ?? '').trim();
      final displayName = brand.isEmpty
          ? food.name.trim()
          : '${food.name.trim()} (${brand.split(',').first.trim()})';
      final row = <String, dynamic>{
        'name': displayName,
        'name_normalized': _normalize(displayName),
        'category': _guessCategoryFromName(food.name, food.brand),
        'kcal_per_100g': food.kcalPer100g,
        'protein_per_100g': food.proteinPer100g ?? 0,
        'carbs_per_100g': food.carbsPer100g ?? 0,
        'fat_per_100g': food.fatPer100g ?? 0,
        'fiber_per_100g': food.fiberPer100g ?? 0,
        'serving_grams': 100,
        'serving_description': '100 g',
        'source': 'OFF',
        'off_product_id': food.offProductId,
        'image_url': food.imageUrl,
        'brand': brand.isEmpty ? null : brand,
        'country_relevance': _countryRelevanceFromTags(food.countriesTags),
        // OFF no entra al plan IA por defecto (calidad variable). Sigue
        // disponible para registro manual y búsqueda.
        'ai_exclude_from_plan': true,
      };
      await _client.from('custom_foods').insert(row);
    } catch (e) {
      // duplicate key / RLS → silenciamos, no es un error de usuario.
      if (kDebugMode) {
        debugPrint('FoodService._cacheOffProductToCustomFoods skip: $e');
      }
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

    // Auto-cache: si el producto vino de Open Food Facts (no era ya curado),
    // lo persistimos en custom_foods para que crezca con el uso real. Fire and
    // forget: si falla por unique constraint o RLS, no rompemos el log.
    if (!food.isCustom && food.offProductId != null) {
      unawaited(_cacheOffProductToCustomFoods(food));
    }
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
