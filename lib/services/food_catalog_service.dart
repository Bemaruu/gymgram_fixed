import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Alimento suelto curado del catálogo (tabla custom_foods).
/// Macros expresados POR 100g. `servingGrams` es una porción típica de
/// referencia (ej: 1 huevo = 50g) usada para componer comidas estilo Fitia.
class CatalogFood {
  final String name;
  final String category;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double servingGrams;
  final String? servingDescription;

  const CatalogFood({
    required this.name,
    required this.category,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.servingGrams,
    this.servingDescription,
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
    return CatalogFood(
      name: m['name'] as String,
      category: (m['category'] as String?) ?? '',
      kcalPer100g: d(m['kcal_per_100g']),
      proteinPer100g: d(m['protein_per_100g']),
      carbsPer100g: d(m['carbs_per_100g']),
      fatPer100g: d(m['fat_per_100g']),
      fiberPer100g: d(m['fiber_per_100g']),
      servingGrams: serving > 0 ? serving : 100,
      servingDescription: m['serving_description'] as String?,
    );
  }
}

/// Lee el catálogo de alimentos sueltos (custom_foods) para componer comidas
/// mixtas en el generador de planes. Cachea en memoria para no refetch en cada
/// cambio de día.
class FoodCatalogService {
  static final FoodCatalogService instance = FoodCatalogService._();
  FoodCatalogService._();

  final _client = Supabase.instance.client;
  List<CatalogFood>? _cache;

  Future<List<CatalogFood>> getCatalog() async {
    if (_cache != null) return _cache!;
    try {
      final rows = await _client.from('custom_foods').select(
            'name, category, serving_description, serving_grams, '
            'kcal_per_100g, protein_per_100g, carbs_per_100g, '
            'fat_per_100g, fiber_per_100g',
          );
      _cache = (rows as List)
          .map((r) => CatalogFood.fromMap(r as Map<String, dynamic>))
          .where((f) => f.kcalPer100g > 0)
          .toList();
      return _cache!;
    } catch (e) {
      debugPrint('FoodCatalogService.getCatalog error: $e');
      return [];
    }
  }
}
