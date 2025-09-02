import 'package:flutter/material.dart';

class FoodItem {
  final String name;
  final int kcal;
  bool isChecked;
  
  FoodItem({
    required this.name,
    required this.kcal,
    this.isChecked = false,
  });

      FoodItem copyWith({
    String? name,
    int? kcal,
    bool? isChecked,
  }) {
    return FoodItem(
      name: name ?? this.name,
      kcal: kcal ?? this.kcal,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class MealCard extends StatelessWidget {
  final String title;
  final List<FoodItem> foods;
  final Function(int index)? onToggle; // AÑADIR ESTO

  const MealCard({
    Key? key,
    required this.title,
    required this.foods,
    this.onToggle, // Y esto
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalKcal = foods.fold<int>(0, (sum, item) => sum + (item.isChecked ? item.kcal : 0));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y calorías
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '$totalKcal kcal',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Lista de alimentos
          ...foods.asMap().entries.map((entry) {
            final index = entry.key;
            final food = entry.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        food.isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: food.isChecked ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      onPressed: () {
                        if (onToggle != null) {
                          onToggle!(index); // AQUÍ se llama al toggle con el índice correcto
                        }
                      },
                    ),
                    Text(food.name),
                  ],
                ),
                Text('${food.kcal} kcal'),
              ],
            );
          }),
        ],
      ),
    );
  }
}

