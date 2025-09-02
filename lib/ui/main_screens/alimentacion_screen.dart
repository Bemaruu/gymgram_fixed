import 'package:flutter/material.dart';
import '/widgets/meal_card.dart';
import '/core/app_colors.dart';

class AlimentacionScreen extends StatefulWidget {
  const AlimentacionScreen({super.key});

  @override
  State<AlimentacionScreen> createState() => _AlimentacionScreenState();
}

class _AlimentacionScreenState extends State<AlimentacionScreen> {
  int selectedDayIndex = DateTime.now().weekday - 1;
  int totalCalories = 0;
  int waterCount = 0;
  final int calorieGoal = 2000;

  // Mock data para comidas
  final List<Map<String, dynamic>> meals = [
    {
      'title': 'Desayuno',
      'foods': [
        FoodItem(name: 'Avena', kcal: 150),
        FoodItem(name: 'Plátano', kcal: 90),
        FoodItem(name: 'Huevo', kcal: 80),
      ]
    },
    {
      'title': 'Almuerzo',
      'foods': [
        FoodItem(name: 'Pollo', kcal: 200),
        FoodItem(name: 'Arroz', kcal: 150),
        FoodItem(name: 'Ensalada', kcal: 50),
      ]
    },
    {
      'title': 'Cena',
      'foods': [
        FoodItem(name: 'Pescado', kcal: 180),
        FoodItem(name: 'Verduras', kcal: 100),
      ]
    },
  ];

  void toggleFoodChecked(MealCard mealCard, int foodIndex) {
    setState(() {
      final food = mealCard.foods[foodIndex];
      final updatedFood = food.copyWith(isChecked: !food.isChecked);
      mealCard.foods[foodIndex] = updatedFood;

      // Recalcular calorías
      totalCalories = meals.expand((meal) => meal['foods'] as List<FoodItem>).fold(
        0,
        (sum, food) => food.isChecked ? sum + food.kcal : sum,
      );
    });
  }

  void toggleWater() {
    if (waterCount < 8) {
      setState(() {
        waterCount++;
      });
    }
  }

  void resetWater() {
    setState(() {
      waterCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de Alimentación'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),

          // Calendario circular
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isSelected = index == selectedDayIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDayIndex = index;
                  });
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade200,
                  child: Text(
                    days[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Calorías consumidas con barra
          const Text('Calorías consumidas:', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (totalCalories / calorieGoal).clamp(0.0, 1.0),
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: totalCalories < calorieGoal
                        ? Colors.green
                        : (totalCalories <= calorieGoal + 100 ? Colors.orange : Colors.red),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text('$totalCalories / $calorieGoal kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // MealCards dinámicos
          ...meals.map((meal) {
  final foodList = meal['foods'] as List<FoodItem>;

  return MealCard(
    title: meal['title'],
    foods: foodList,
    onToggle: (index) {
      setState(() {
        // reemplazamos el item seleccionado
        foodList[index] = foodList[index].copyWith(
          isChecked: !foodList[index].isChecked,
        );

        // recalculamos calorías
        totalCalories = meals
            .expand((meal) => meal['foods'] as List<FoodItem>)
            .fold<int>(
              0,
              (sum, food) => food.isChecked ? sum + food.kcal : sum,
            );
      });
    },
  );
}),


          const SizedBox(height: 32),

          // Contador de agua
          const Text('Agua consumida (vasos):', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(8, (index) {
              final filled = index < waterCount;
              return GestureDetector(
                onTap: toggleWater,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: filled ? AppColors.primary : Colors.grey.shade300,
                  child: const Icon(Icons.water_drop, size: 16, color: Colors.white),
                ),
              );
            }),
          ),
          TextButton(
            onPressed: resetWater,
            child: const Text('Reiniciar contador'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
