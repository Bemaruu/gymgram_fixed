import 'package:flutter/material.dart';
import '../../services/routine_service.dart';
import 'exercise_search_sheet.dart';

class CreateCustomRoutineScreen extends StatefulWidget {
  final int? initialDay;
  final List<bool>? availableDays;
  const CreateCustomRoutineScreen({super.key, this.initialDay, this.availableDays});

  @override
  State<CreateCustomRoutineScreen> createState() =>
      _CreateCustomRoutineScreenState();
}

class _CreateCustomRoutineScreenState
    extends State<CreateCustomRoutineScreen> {
  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  late int _selectedDay;
  late List<bool> _availableDays;
  final List<_ExerciseEntry> _exercises = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _availableDays = widget.availableDays ?? List.filled(7, true);
    final hasAny = _availableDays.any((d) => d);
    if (!hasAny) _availableDays = List.filled(7, true);

    final preferred = widget.initialDay;
    if (preferred != null && _availableDays[preferred]) {
      _selectedDay = preferred;
    } else {
      _selectedDay = _availableDays.indexWhere((d) => d);
      if (_selectedDay < 0) _selectedDay = DateTime.now().weekday - 1;
    }
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
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ejercicio antes de guardar.'),
          backgroundColor: Colors.orange,
        ),
      );
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

      await RoutineService.instance.saveRoutine(
        title: _dayNames[_selectedDay],
        goal: 'CUSTOM',
        trainingLocation: 'GYM',
        dayOfWeek: _selectedDay,
        exercises: exerciseMaps,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF00BFFF), size: 20),
              SizedBox(width: 10),
              Text('Rutina guardada exitosamente'),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2500),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
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
          'Mi rutina',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                )
              : TextButton(
                  onPressed: _exercises.isNotEmpty ? _save : null,
                  child: Text(
                    'Guardar',
                    style: TextStyle(
                      color: _exercises.isNotEmpty ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          // Header azul — selector de día
          Container(
            color: const Color(0xFF00BFFF),
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Text(
                    'Elige el día de entrenamiento',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 7,
                    itemBuilder: (_, i) {
                      final isSelected = i == _selectedDay;
                      final isTrainingDay = _availableDays[i];
                      return GestureDetector(
                        onTap: isTrainingDay
                            ? () => setState(() => _selectedDay = i)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : isTrainingDay
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: !isTrainingDay
                                ? Border.all(color: Colors.white.withValues(alpha: 0.20))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayLabels[i],
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF00BFFF)
                                      : isTrainingDay
                                          ? Colors.white
                                          : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  decoration: !isTrainingDay
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: Colors.white38,
                                ),
                              ),
                              if (!isTrainingDay) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.hotel_rounded, size: 11, color: Colors.white38),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _exercises.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _exercises.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _exercises.length) return _buildAddButton();
                      return _buildExerciseCard(_exercises[i], i);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFFF).withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_box_outlined, color: Color(0xFF00BFFF), size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Este día está vacío',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agrega los ejercicios de tu programa para este día',
              style: TextStyle(fontSize: 14, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openSearch,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Agregar ejercicio',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: GestureDetector(
        onTap: _openSearch,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00BFFF), width: 1.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: Color(0xFF00BFFF), size: 22),
              SizedBox(width: 10),
              Text(
                'Agregar ejercicio',
                style: TextStyle(color: Color(0xFF00BFFF), fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(_ExerciseEntry e, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00BFFF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fitness_center, color: Color(0xFF00BFFF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(e.muscleGroup, style: const TextStyle(color: Color(0xFF00BFFF), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${e.sets} series × ${e.reps}  •  Descanso ${e.restSeconds}s',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFFEF5350), size: 20),
            onPressed: () => setState(() => _exercises.removeAt(index)),
          ),
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
