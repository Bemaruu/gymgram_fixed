import 'package:flutter/material.dart';

class Exercise {
  final String name;
  final int sets;
  final int reps;
  final int restSeconds;
  final String imageUrl;
  bool isChecked;

  Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.imageUrl,
    this.isChecked = false,
  });
}

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  int selectedDayIndex = DateTime.now().weekday - 1;
  final List<String> weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  final List<bool> userSelectedDays = [true, true, true, true, true, false, false];

  final List<Exercise> exercises = [
    Exercise(
      name: 'Pull-Ups',
      sets: 4,
      reps: 8,
      restSeconds: 90,
      imageUrl: 'assets/images/pullup.png',
    ),
    Exercise(
      name: 'Dumbbell Row',
      sets: 4,
      reps: 10,
      restSeconds: 60,
      imageUrl: 'assets/images/dumbbell_row.png',
    ),
    Exercise(
      name: 'Face Pull',
      sets: 3,
      reps: 12,
      restSeconds: 60,
      imageUrl: 'assets/images/face_pull.png',
    ),
  ];

  int get completedExercises => exercises.where((e) => e.isChecked).length;

  void toggleExercise(int index) {
    setState(() {
      exercises[index].isChecked = !exercises[index].isChecked;
    });
  }

  void showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Image.asset(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Rutina del Día', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // CALENDARIO
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final isSelected = index == selectedDayIndex;
                final isAvailable = userSelectedDays[index];
                return GestureDetector(
                  onTap: isAvailable
                      ? () {
                          setState(() {
                            selectedDayIndex = index;
                          });
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00BFFF)
                          : isAvailable
                              ? Colors.grey[200]
                              : Colors.orange[200],
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      weekDays[index],
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected || !isAvailable ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // CONTADOR DE EJERCICIOS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$completedExercises/${exercises.length} Ejercicios',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completedExercises / exercises.length,
                    backgroundColor: Colors.grey[300],
                    color: const Color(0xFF00BFFF),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // LISTA DE EJERCICIOS
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isShortList = exercises.length <= 3;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final e = exercises[index];
                    return GestureDetector(
                      onTap: () => toggleExercise(index),
                      child: Container(
                        height: isShortList ? (constraints.maxHeight / exercises.length) - 20 : null,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => showFullImage(e.imageUrl),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white,
                                  image: DecorationImage(
                                    image: AssetImage(e.imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.name,
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${e.sets} sets • ${e.reps} reps • Rest ${e.restSeconds}s',
                                      style: const TextStyle(color: Colors.black54)),
                                ],
                              ),
                            ),
                            Icon(
                              e.isChecked
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: e.isChecked ? Colors.green : Colors.grey,
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
