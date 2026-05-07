class FoodLog {
  final String id;
  final String userId;
  final DateTime logDate;
  final String mealType;
  final String foodName;
  final String? brand;
  final String? offProductId;
  final String? imageUrl;
  final double grams;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double? kcalTotal;
  final double? proteinTotal;
  final double? carbsTotal;
  final double? fatTotal;
  final double? fiberPer100g;
  final double? fiberTotal;
  final DateTime createdAt;

  const FoodLog({
    required this.id,
    required this.userId,
    required this.logDate,
    required this.mealType,
    required this.foodName,
    this.brand,
    this.offProductId,
    this.imageUrl,
    required this.grams,
    this.kcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.kcalTotal,
    this.proteinTotal,
    this.carbsTotal,
    this.fatTotal,
    this.fiberPer100g,
    this.fiberTotal,
    required this.createdAt,
  });

  static FoodLog fromMap(Map<String, dynamic> m) {
    double? d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return FoodLog(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      logDate: DateTime.parse(m['log_date'] as String),
      mealType: m['meal_type'] as String,
      foodName: m['food_name'] as String,
      brand: m['brand'] as String?,
      offProductId: m['off_product_id'] as String?,
      imageUrl: m['image_url'] as String?,
      grams: d(m['grams']) ?? 0,
      kcalPer100g: d(m['kcal_per_100g']),
      proteinPer100g: d(m['protein_per_100g']),
      carbsPer100g: d(m['carbs_per_100g']),
      fatPer100g: d(m['fat_per_100g']),
      kcalTotal: d(m['kcal_total']),
      proteinTotal: d(m['protein_total']),
      carbsTotal: d(m['carbs_total']),
      fatTotal: d(m['fat_total']),
      fiberPer100g: d(m['fiber_per_100g']),
      fiberTotal: d(m['fiber_total']),
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'user_id': userId,
        'log_date':
            '${logDate.year}-${logDate.month.toString().padLeft(2, '0')}-${logDate.day.toString().padLeft(2, '0')}',
        'meal_type': mealType,
        'food_name': foodName,
        if (brand != null) 'brand': brand,
        if (offProductId != null) 'off_product_id': offProductId,
        if (imageUrl != null) 'image_url': imageUrl,
        'grams': grams,
        if (kcalPer100g != null) 'kcal_per_100g': kcalPer100g,
        if (proteinPer100g != null) 'protein_per_100g': proteinPer100g,
        if (carbsPer100g != null) 'carbs_per_100g': carbsPer100g,
        if (fatPer100g != null) 'fat_per_100g': fatPer100g,
        if (kcalTotal != null) 'kcal_total': kcalTotal,
        if (proteinTotal != null) 'protein_total': proteinTotal,
        if (carbsTotal != null) 'carbs_total': carbsTotal,
        if (fatTotal != null) 'fat_total': fatTotal,
        if (fiberPer100g != null) 'fiber_per_100g': fiberPer100g,
        if (fiberTotal != null) 'fiber_total': fiberTotal,
      };
}
