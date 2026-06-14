class FoodItem {
  final String name;
  final String? brand;
  final String? offProductId;
  final String? imageUrl;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? fiberPer100g;
  final bool isCustom;
  final List<String> countriesTags;
  final List<String> countryRelevance;
  // Porción de referencia (solo alimentos curados de custom_foods).
  final double? servingGrams;
  final String? servingDescription;
  // Si unitLabel != null y unitGrams > 0 el alimento se cuenta en unidades
  // (manzanas, huevos, piezas de sushi, latas, etc.) y unitGrams es el peso
  // de UNA unidad. Los macros siguen siendo per 100g.
  final String? unitLabel;
  final double? unitGrams;

  bool get hasCalories => kcalPer100g != null && kcalPer100g! > 0;
  bool get isUnitBased =>
      unitLabel != null && unitLabel!.isNotEmpty && (unitGrams ?? 0) > 0;

  const FoodItem({
    required this.name,
    this.brand,
    this.offProductId,
    this.imageUrl,
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.fiberPer100g,
    this.isCustom = false,
    this.countriesTags = const [],
    this.countryRelevance = const [],
    this.servingGrams,
    this.servingDescription,
    this.unitLabel,
    this.unitGrams,
  });

  double? kcalFor(double grams) => kcalPer100g != null ? _calc(kcalPer100g!, grams) : null;
  double? proteinFor(double grams) => proteinPer100g != null ? _calc(proteinPer100g!, grams) : null;
  double? carbsFor(double grams) => carbsPer100g != null ? _calc(carbsPer100g!, grams) : null;
  double? fatFor(double grams) => fatPer100g != null ? _calc(fatPer100g!, grams) : null;
  double? fiberFor(double grams) => fiberPer100g != null ? _calc(fiberPer100g!, grams) : null;

  static double _calc(double per100g, double grams) =>
      double.parse(((per100g * grams) / 100).toStringAsFixed(2));

  static FoodItem? fromOpenFoodFacts(Map<String, dynamic> json) {
    final name = (json['product_name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;
    final nutriments = json['nutriments'] as Map<String, dynamic>? ?? {};

    double? parseN(String key) {
      final v = nutriments[key];
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final kcal = parseN('energy-kcal_100g');
    if (kcal == null) return null;
    final countriesTags = (json['countries_tags'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const <String>[];

    return FoodItem(
      name: name,
      brand: (json['brands'] as String?)?.trim(),
      offProductId: json['id']?.toString() ?? json['code']?.toString(),
      imageUrl: json['image_small_url'] as String?,
      kcalPer100g: kcal,
      proteinPer100g: parseN('proteins_100g'),
      carbsPer100g: parseN('carbohydrates_100g'),
      fatPer100g: parseN('fat_100g'),
      fiberPer100g: parseN('fiber_100g'),
      countriesTags: countriesTags,
    );
  }

  static FoodItem fromCustomFood(Map<String, dynamic> row) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }
    final serving = d(row['serving_grams']);
    final unitGrams = d(row['unit_grams']);
    final unitLabelRaw = row['unit_label'] as String?;
    final countryRelevance = (row['country_relevance'] as List?)
            ?.map((e) => e.toString().toUpperCase())
            .toList() ??
        const <String>[];
    return FoodItem(
      name: row['name'] as String,
      brand: null,
      offProductId: null,
      imageUrl: null,
      kcalPer100g: d(row['kcal_per_100g']),
      proteinPer100g: d(row['protein_per_100g']),
      carbsPer100g: d(row['carbs_per_100g']),
      fatPer100g: d(row['fat_per_100g']),
      fiberPer100g: d(row['fiber_per_100g']),
      isCustom: true,
      countryRelevance: countryRelevance,
      servingGrams: (serving != null && serving > 0) ? serving : null,
      servingDescription: row['serving_description'] as String?,
      unitLabel: (unitLabelRaw != null && unitLabelRaw.trim().isNotEmpty)
          ? unitLabelRaw.trim()
          : null,
      unitGrams: (unitGrams != null && unitGrams > 0) ? unitGrams : null,
    );
  }
}
