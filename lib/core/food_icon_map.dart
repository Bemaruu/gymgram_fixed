enum FoodCategory {
  meat,
  chicken,
  fish,
  egg,
  dairy,
  grain,
  bread,
  rice,
  pasta,
  fruit,
  veggie,
  legume,
  nuts,
  avocado,
  sweet,
  drink,
  water,
  coffee,
  supplement,
  snack,
  fastfood,
  other,
}

class FoodIconMap {
  static const Map<FoodCategory, String> assetByCategory = {
    FoodCategory.meat: 'assets/icons/food/food_meat.svg',
    FoodCategory.chicken: 'assets/icons/food/food_chicken.svg',
    FoodCategory.fish: 'assets/icons/food/food_fish.svg',
    FoodCategory.egg: 'assets/icons/food/food_egg.svg',
    FoodCategory.dairy: 'assets/icons/food/food_dairy.svg',
    FoodCategory.grain: 'assets/icons/food/food_grain.svg',
    FoodCategory.bread: 'assets/icons/food/food_bread.svg',
    FoodCategory.rice: 'assets/icons/food/food_rice.svg',
    FoodCategory.pasta: 'assets/icons/food/food_pasta.svg',
    FoodCategory.fruit: 'assets/icons/food/food_fruit.svg',
    FoodCategory.veggie: 'assets/icons/food/food_veggie.svg',
    FoodCategory.legume: 'assets/icons/food/food_legume.svg',
    FoodCategory.nuts: 'assets/icons/food/food_nuts.svg',
    FoodCategory.avocado: 'assets/icons/food/food_avocado.svg',
    FoodCategory.sweet: 'assets/icons/food/food_sweet.svg',
    FoodCategory.drink: 'assets/icons/food/food_drink.svg',
    FoodCategory.water: 'assets/icons/food/food_water.svg',
    FoodCategory.coffee: 'assets/icons/food/food_coffee.svg',
    FoodCategory.supplement: 'assets/icons/food/food_supplement.svg',
    FoodCategory.snack: 'assets/icons/food/food_snack.svg',
    FoodCategory.fastfood: 'assets/icons/food/food_fastfood.svg',
  };

  /// Heurística: detecta la categoría por nombre del alimento (español).
  /// Si no hay match, devuelve FoodCategory.other.
  static FoodCategory categorize(String foodName) {
    final n = foodName.toLowerCase().trim();
    bool any(List<String> kws) => kws.any((k) => n.contains(k));

    if (any(['agua'])) return FoodCategory.water;
    if (any(['café', 'cafe', 'expreso', 'capuchino', 'latte'])) {
      return FoodCategory.coffee;
    }
    if (any(['leche', 'yogur', 'yogurt', 'queso', 'cuajada', 'kefir'])) {
      return FoodCategory.dairy;
    }
    if (any(['huevo', 'clara'])) return FoodCategory.egg;
    if (any(['pollo', 'pavo', 'pechuga'])) return FoodCategory.chicken;
    if (any([
      'atún',
      'atun',
      'salmón',
      'salmon',
      'pescado',
      'merluza',
      'tilapia',
      'sardina'
    ])) {
      return FoodCategory.fish;
    }
    if (any([
      'carne',
      'res',
      'ternera',
      'cerdo',
      'jamón',
      'jamon',
      'tocino',
      'chorizo',
      'bistec'
    ])) {
      return FoodCategory.meat;
    }
    if (any(['arroz'])) return FoodCategory.rice;
    if (any([
      'pasta',
      'fideo',
      'macarron',
      'espagueti',
      'spaghetti',
      'tallarín',
      'tallarin'
    ])) {
      return FoodCategory.pasta;
    }
    if (any(['pan', 'tostada', 'baguette'])) return FoodCategory.bread;
    if (any(['avena', 'cereal', 'quinoa', 'granola', 'trigo'])) {
      return FoodCategory.grain;
    }
    if (any([
      'frijol',
      'lenteja',
      'garbanzo',
      'haba',
      'porotos',
      'judías',
      'judias'
    ])) {
      return FoodCategory.legume;
    }
    if (any(['palta', 'aguacate'])) return FoodCategory.avocado;
    if (any([
      'nuez',
      'almendra',
      'maní',
      'mani',
      'cacahuete',
      'pistacho',
      'castaña',
      'castana',
      'avellana'
    ])) {
      return FoodCategory.nuts;
    }
    if (any([
      'manzana',
      'plátano',
      'platano',
      'banana',
      'fresa',
      'piña',
      'pina',
      'mango',
      'naranja',
      'uva',
      'sandía',
      'sandia',
      'pera',
      'kiwi',
      'fruta'
    ])) {
      return FoodCategory.fruit;
    }
    if (any([
      'brócoli',
      'brocoli',
      'espinaca',
      'lechuga',
      'tomate',
      'zanahoria',
      'pepino',
      'verdura',
      'vegetal',
      'ensalada'
    ])) {
      return FoodCategory.veggie;
    }
    if (any([
      'chocolate',
      'pastel',
      'torta',
      'helado',
      'galleta dulce',
      'postre',
      'dulce',
      'caramelo',
      'donut',
      'rosquilla'
    ])) {
      return FoodCategory.sweet;
    }
    if (any(['galleta', 'snack', 'papas', 'chips'])) {
      return FoodCategory.snack;
    }
    if (any(['hamburguesa', 'pizza', 'hot dog', 'taco'])) {
      return FoodCategory.fastfood;
    }
    if (any([
      'proteína',
      'proteina',
      'creatina',
      'bcaa',
      'multivitamínico',
      'multivitaminico',
      'suplemento',
      'pre-entreno',
      'preworkout'
    ])) {
      return FoodCategory.supplement;
    }
    if (any([
      'jugo',
      'zumo',
      'batido',
      'shake',
      'smoothie',
      'refresco',
      'soda',
      'bebida'
    ])) {
      return FoodCategory.drink;
    }

    return FoodCategory.other;
  }

  static String? assetFor(String foodName) {
    final cat = categorize(foodName);
    return assetByCategory[cat];
  }
}
