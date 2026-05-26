import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/country_utils.dart';

/// Alimento suelto curado del catálogo (tabla custom_foods).
/// Macros expresados POR 100g. `servingGrams` es una porción típica de
/// referencia (ej: 1 huevo = 50g) usada para componer comidas estilo Fitia.
class CatalogFood {
  final String name;
  final String nameNormalized;
  final String category;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double servingGrams;
  final String? servingDescription;
  final List<String> countryRelevance;

  const CatalogFood({
    required this.name,
    this.nameNormalized = '',
    required this.category,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.servingGrams,
    this.servingDescription,
    this.countryRelevance = const [],
  });

  double kcalFor(double g) => kcalPer100g * g / 100;
  double proteinFor(double g) => proteinPer100g * g / 100;
  double carbsFor(double g) => carbsPer100g * g / 100;
  double fatFor(double g) => fatPer100g * g / 100;

  factory CatalogFood.fromMap(Map<String, dynamic> m) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final serving = d(m['serving_grams']);
    final countries = (m['country_relevance'] as List?)
            ?.map((e) => e.toString().toUpperCase())
            .toList() ??
        const <String>[];
    return CatalogFood(
      name: m['name'] as String,
      nameNormalized: (m['name_normalized'] as String? ?? m['name'] as String)
          .toLowerCase()
          .trim(),
      category: (m['category'] as String?) ?? '',
      kcalPer100g: d(m['kcal_per_100g']),
      proteinPer100g: d(m['protein_per_100g']),
      carbsPer100g: d(m['carbs_per_100g']),
      fatPer100g: d(m['fat_per_100g']),
      fiberPer100g: d(m['fiber_per_100g']),
      servingGrams: serving > 0 ? serving : 100,
      servingDescription: m['serving_description'] as String?,
      countryRelevance: countries,
    );
  }
}

/// Lee el catálogo de alimentos sueltos (custom_foods) para componer comidas
/// mixtas en el generador de planes. Cachea en memoria para no refetch en cada
/// cambio de día.
class FoodCatalogService {
  static final FoodCatalogService instance = FoodCatalogService._();
  FoodCatalogService._();

  static const _columns = 'name, name_normalized, category, '
      'serving_description, serving_grams, kcal_per_100g, protein_per_100g, '
      'carbs_per_100g, fat_per_100g, fiber_per_100g, country_relevance';

  final _client = Supabase.instance.client;
  final Map<String, List<CatalogFood>> _cacheByCountry = {};
  List<CatalogFood>? _allFoods;
  Map<String, CatalogFood>? _ingredientIndex;

  Future<List<CatalogFood>> getCatalog([String? countryCode]) async {
    final country = CountryUtils.normalize(countryCode);
    if (_cacheByCountry.containsKey(country)) return _cacheByCountry[country]!;
    final foods = await _getAllFoods();
    if (foods.isEmpty) return [];
    final local = foods
        .where((f) =>
            f.countryRelevance.isEmpty ||
            f.countryRelevance.contains(country))
        .toList();
    _cacheByCountry[country] =
        local.isNotEmpty || country != CountryUtils.defaultCountry
            ? local
            : foods;
    return _cacheByCountry[country]!;
  }

  /// Índice de TODOS los alimentos por name_normalized, sin filtro de país.
  /// Usado para resolver ingredientes de recetas: una receta ya viene filtrada
  /// por país, sus ingredientes (arroz, pollo, etc.) deben resolverse siempre.
  Future<Map<String, CatalogFood>> getIngredientIndex() async {
    if (_ingredientIndex != null) return _ingredientIndex!;
    final foods = await _getAllFoods();
    _ingredientIndex = {for (final f in foods) f.nameNormalized: f};
    return _ingredientIndex!;
  }

  Future<List<CatalogFood>> _getAllFoods() async {
    if (_allFoods != null) return _allFoods!;
    try {
      final rows = await _client.from('custom_foods').select(_columns);
      _allFoods = (rows as List)
          .map((r) => CatalogFood.fromMap(r as Map<String, dynamic>))
          .where((f) => f.kcalPer100g > 0)
          .toList();
      return _allFoods!;
    } catch (e) {
      debugPrint('FoodCatalogService._getAllFoods error: $e');
      return [];
    }
  }
}
