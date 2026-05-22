import 'package:flutter/material.dart';
import '../../services/routine_service.dart';
import '../plans/plans_screen.dart';
import 'exercise_search_sheet.dart';

class CreateCommunityRoutineScreen extends StatefulWidget {
  const CreateCommunityRoutineScreen({super.key});

  @override
  State<CreateCommunityRoutineScreen> createState() =>
      _CreateCommunityRoutineScreenState();
}

class _CreateCommunityRoutineScreenState
    extends State<CreateCommunityRoutineScreen> {
  final _titleCtrl = TextEditingController();
  String _goal = 'GAIN_MUSCLE';
  final List<_ExerciseEntry> _exercises = [];
  bool _isSaving = false;

  static const _goals = [
    {'value': 'GAIN_MUSCLE', 'label': 'Ganar músculo'},
    {'value': 'LOSE_WEIGHT', 'label': 'Perder peso'},
    {'value': 'MAINTAIN', 'label': 'Mantener'},
    {'value': 'CUSTOM', 'label': 'Otro'},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseSearchSheet(
        userLocation: 'gym',
        onExerciseSelected: (exercise) {
          setState(() {
            _exercises.add(_ExerciseEntry(
              name: exercise['name_es'] as String,
              muscleGroup: exercise['muscle_group_primary'] as String,
              sets: (exercise['_sets'] as int?) ?? 3,
              reps: (exercise['_reps'] as String?) ?? '8-12',
              restSeconds: 60,
            ));
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pon un título a tu rutina'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ejercicio antes de guardar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final canPublish =
        await RoutineService.instance.canPublishCommunityRoutine();
    if (!canPublish) {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Limite Free alcanzado'),
          content: const Text(
            'Los planes Free pueden publicar hasta 5 rutinas para la comunidad. Hazte Plus o Premium para publicaciones ilimitadas.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ver planes'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await PlansScreen.open(context);
      }
      return;
    }
    setState(() => _isSaving = true);
    try {
      final exerciseMaps = _exercises
          .map((e) => {
                'name': e.name,
                'muscle_group': e.muscleGroup,
                'sets': e.sets,
                'reps': e.reps,
                'rest_seconds': e.restSeconds,
              })
          .toList();

      await RoutineService.instance.saveCommunityRoutine(
        title: title,
        goal: _goal,
        trainingLocation: 'GYM',
        exercises: exerciseMaps,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF00BFFF), size: 20),
              SizedBox(width: 10),
              Text('Rutina publicada para la comunidad'),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2500),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BFFF),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crear rutina',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Publicar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Título
          TextField(
            controller: _titleCtrl,
            maxLength: 60,
            decoration: InputDecoration(
              labelText: 'Título de la rutina',
              hintText: 'Ej: Push Pull Legs intenso',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF00BFFF), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Objetivo
          const Text(
            'Objetivo',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goals.map((g) {
              final selected = g['value'] == _goal;
              return GestureDetector(
                onTap: () => setState(() => _goal = g['value']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF00BFFF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF00BFFF)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    g['label']!,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Ejercicios
          const Text(
            'Ejercicios',
            style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (_exercises.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text(
                  'Aún no agregaste ejercicios',
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            )
          else
            ..._exercises.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFFF)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fitness_center,
                          color: Color(0xFF00BFFF), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e.muscleGroup} · ${e.sets}×${e.reps}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Color(0xFFEF5350), size: 20),
                      onPressed: () =>
                          setState(() => _exercises.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00BFFF), width: 1.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: Color(0xFF00BFFF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Agregar ejercicio',
                    style: TextStyle(
                      color: Color(0xFF00BFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ExerciseEntry {
  final String name;
  final String muscleGroup;
  final int sets;
  final String reps;
  final int restSeconds;

  const _ExerciseEntry({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });
}
