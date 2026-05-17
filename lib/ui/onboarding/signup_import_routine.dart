import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/input_sanitizers.dart';
import '../shared/custom_button.dart';

/// Captura de la rutina semanal del usuario para importarla a su perfil
/// y dejarla lista para un análisis futuro de IA.
///
/// Diseño: usa la misma paleta y patrón visual que CreateCustomRoutineScreen
/// (header azul + cards blancos), pero adaptado a recolección, no a guardado
/// directo. El guardado ocurre al final (signup_step_13) con source='user_imported'.
class SignupImportRoutine extends StatefulWidget {
  const SignupImportRoutine({super.key});

  @override
  State<SignupImportRoutine> createState() => _SignupImportRoutineState();
}

class _SignupImportRoutineState extends State<SignupImportRoutine> {
  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _dayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  late Map<String, dynamic> userData;
  int _selectedDay = 0;

  /// Por día (0..6) → lista de ejercicios. Día sin entrada = descanso.
  final Map<int, List<Map<String, dynamic>>> _routine = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    // Pre-rellena los días con la selección hecha en signup_step_7 si existe.
    final availableDays = userData['availableDays'];
    if (availableDays is List && availableDays.isNotEmpty) {
      for (final d in availableDays) {
        final idx = int.tryParse(d.toString());
        if (idx != null) _routine.putIfAbsent(idx, () => []);
      }
      _selectedDay = _routine.keys.first;
    }
  }

  bool _isTrainingDay(int day) => _routine.containsKey(day);

  void _toggleTrainingDay(int day) {
    setState(() {
      if (_routine.containsKey(day)) {
        _routine.remove(day);
        if (_selectedDay == day && _routine.isNotEmpty) {
          _selectedDay = _routine.keys.first;
        }
      } else {
        _routine[day] = [];
        _selectedDay = day;
      }
    });
  }

  Future<void> _openAddExercise() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddExerciseSheet(),
    );
    if (result != null) {
      setState(() {
        _routine.putIfAbsent(_selectedDay, () => []);
        _routine[_selectedDay]!.add(result);
      });
    }
  }

  void _removeExercise(int idx) {
    setState(() => _routine[_selectedDay]!.removeAt(idx));
  }

  bool get _hasAtLeastOneExercise =>
      _routine.values.any((exs) => exs.isNotEmpty);

  void _onContinue() {
    if (!_hasAtLeastOneExercise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un ejercicio en algún día.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Serializa los días con entrenamiento al formato que signup_step_13 usará
    // para crear las rutinas en bulk con source='user_imported'.
    final importedRoutine = <Map<String, dynamic>>[];
    _routine.forEach((day, exercises) {
      if (exercises.isEmpty) return;
      importedRoutine.add({
        'day_of_week': day,
        'title': _dayNames[day],
        'exercises': exercises,
      });
    });
    userData['importedRoutine'] = importedRoutine;

    // Sincroniza availableDays con los días marcados aquí, para que sea
    // coherente al guardar.
    userData['availableDays'] =
        _routine.keys.map((d) => d.toString()).toList();

    Navigator.pushNamed(context, '/signup_step_5', arguments: userData);
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _routine[_selectedDay] ?? const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tu rutina actual',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _hasAtLeastOneExercise ? _onContinue : null,
            child: Text(
              'Siguiente',
              style: TextStyle(
                color: _hasAtLeastOneExercise ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Text(
                    'Marca tus días de entrenamiento y agrega los ejercicios',
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
                      final isTrainingDay = _isTrainingDay(i);
                      return GestureDetector(
                        onTap: () {
                          if (isTrainingDay) {
                            setState(() => _selectedDay = i);
                          } else {
                            _toggleTrainingDay(i);
                          }
                        },
                        onLongPress: () => _toggleTrainingDay(i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : isTrainingDay
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: !isTrainingDay
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.20))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayLabels[i],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
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
                                const Icon(Icons.hotel_rounded,
                                    size: 11, color: Colors.white38),
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
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Toca un día para entrenar; mantén presionado para quitarlo.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: !_isTrainingDay(_selectedDay)
                ? _buildEmptyState(rest: true)
                : exercises.isEmpty
                    ? _buildEmptyState(rest: false)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: exercises.length + 1,
                        itemBuilder: (_, i) {
                          if (i == exercises.length) return _buildAddButton();
                          return _buildExerciseCard(exercises[i], i);
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: CustomButton(
                text: 'Siguiente',
                onPressed: _hasAtLeastOneExercise ? _onContinue : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool rest}) {
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
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                rest ? Icons.hotel_rounded : Icons.add_box_outlined,
                color: AppColors.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              rest ? 'Día de descanso' : 'Día sin ejercicios',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              rest
                  ? 'Toca el día arriba para marcarlo como día de entrenamiento.'
                  : 'Agrega los ejercicios que haces este día.',
              style: const TextStyle(fontSize: 13, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
            if (!rest) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openAddExercise,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Agregar ejercicio',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: GestureDetector(
        onTap: _openAddExercise,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text('Agregar ejercicio',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> e, int idx) {
    final name = e['name']?.toString() ?? '';
    final mg = e['muscle_group']?.toString() ?? '';
    final sets = e['sets']?.toString() ?? '';
    final reps = e['reps']?.toString() ?? '';
    final rest = e['rest_seconds']?.toString() ?? '';
    final notes = e['optional_notes']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.fitness_center, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(mg,
                    style:
                        TextStyle(color: AppColors.primary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '$sets series × $reps  •  Descanso ${rest}s',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(notes,
                      style: const TextStyle(color: Colors.black45, fontSize: 11)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFFEF5350), size: 20),
            onPressed: () => _removeExercise(idx),
          ),
        ],
      ),
    );
  }
}

class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet();

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _reps = TextEditingController(text: '8-12');
  final _notes = TextEditingController();

  String _muscleGroup = 'chest';
  int _sets = 3;
  int _restSeconds = 60;

  static const _muscles = <Map<String, String>>[
    {'v': 'chest', 'l': 'Pecho'},
    {'v': 'back', 'l': 'Espalda'},
    {'v': 'legs', 'l': 'Piernas'},
    {'v': 'glutes', 'l': 'Glúteos'},
    {'v': 'shoulders', 'l': 'Hombros'},
    {'v': 'biceps', 'l': 'Bíceps'},
    {'v': 'triceps', 'l': 'Tríceps'},
    {'v': 'core', 'l': 'Core'},
    {'v': 'cardio', 'l': 'Cardio'},
    {'v': 'full_body', 'l': 'Cuerpo completo'},
  ];

  @override
  void dispose() {
    _name.dispose();
    _reps.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop<Map<String, dynamic>>(context, {
      'name': InputSanitizers.cleanText(_name.text, maxLen: 60),
      'muscle_group': _muscleGroup,
      'sets': _sets,
      'reps': InputSanitizers.cleanText(_reps.text, maxLen: 30),
      'rest_seconds': _restSeconds,
      'optional_notes': InputSanitizers.cleanOptional(_notes.text, maxLen: 160),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('Nuevo ejercicio',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del ejercicio',
                    hintText: 'Ej. Press banca',
                  ),
                  validator: InputSanitizers.validateExerciseName,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _muscleGroup,
                  decoration: const InputDecoration(labelText: 'Grupo muscular'),
                  items: _muscles
                      .map((m) => DropdownMenuItem(
                            value: m['v'],
                            child: Text(m['l']!),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _muscleGroup = v ?? 'chest'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _numberStepper(
                        label: 'Series',
                        value: _sets,
                        min: 1,
                        max: 10,
                        step: 1,
                        onChanged: (v) => setState(() => _sets = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reps,
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Reps',
                          hintText: '8-12',
                        ),
                        validator: InputSanitizers.validateReps,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _numberStepper(
                  label: 'Descanso (segundos)',
                  value: _restSeconds,
                  min: 15,
                  max: 300,
                  step: 15,
                  onChanged: (v) => setState(() => _restSeconds = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    hintText: 'Ej. Bajar 4s, subir 1s',
                  ),
                  validator: InputSanitizers.validateExerciseNotes,
                ),
                const SizedBox(height: 16),
                CustomButton(text: 'Agregar', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value - step >= min ? () => onChanged(value - step) : null,
            ),
            Expanded(
              child: Center(
                child: Text('$value',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: value + step <= max ? () => onChanged(value + step) : null,
            ),
          ],
        ),
      ],
    );
  }
}
