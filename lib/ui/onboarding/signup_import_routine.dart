import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/input_sanitizers.dart';
import '../../core/onboarding_flow.dart';
import '../../services/exercise_service.dart';
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
  bool _didInit = false;

  /// Por día (0..6) → lista de ejercicios. Día sin entrada = descanso.
  final Map<int, List<Map<String, dynamic>>> _routine = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IMPORTANTE: inicializar UNA sola vez. ModalRoute.of(context) crea una
    // dependencia del route; al abrir/cerrar el bottom sheet para agregar un
    // ejercicio, didChangeDependencies se vuelve a disparar. Sin este guard,
    // se reseteaba _selectedDay al primer día → "te devuelve a otro día"
    // cada vez que agregabas un ejercicio.
    if (_didInit) return;
    _didInit = true;

    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    // Pre-rellena los días con la selección hecha en signup_step_7 si existe.
    final availableDays = userData['availableDays'];
    if (availableDays is List && availableDays.isNotEmpty) {
      for (final d in availableDays) {
        final idx = int.tryParse(d.toString());
        if (idx != null) _routine.putIfAbsent(idx, () => []);
      }
      if (_routine.isNotEmpty) _selectedDay = _routine.keys.first;
    }
  }

  // Un día es "de entrenamiento" si tiene al menos un ejercicio. No hay que
  // marcarlo aparte: agregar un ejercicio lo activa, y un día sin ejercicios
  // queda como descanso automáticamente.
  bool _isTrainingDay(int day) => _routine[day]?.isNotEmpty ?? false;

  void _selectDay(int day) {
    setState(() {
      _selectedDay = day;
      _routine.putIfAbsent(day, () => []);
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

  Future<void> _openCopyDay() async {
    final source = _selectedDay;
    final sourceExercises = _routine[source];
    if (sourceExercises == null || sourceExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este día no tiene ejercicios para copiar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final targets = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CopyDaySheet(
        sourceDay: source,
        sourceDayName: _dayNames[source],
        dayNames: _dayNames,
        dayLabels: _dayLabels,
      ),
    );
    if (targets == null || targets.isEmpty) return;
    setState(() {
      for (final t in targets) {
        _routine[t] = sourceExercises
            .map((ex) => Map<String, dynamic>.from(ex))
            .toList();
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Rutina de ${_dayNames[source]} copiada a ${targets.length} día(s).',
        ),
        backgroundColor: AppColors.primary,
      ),
    );
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
    // Solo cuentan los días con al menos un ejercicio: un día tocado pero
    // vacío no es día de entrenamiento.
    final trainingDays = (_routine.entries
            .where((e) => e.value.isNotEmpty)
            .map((e) => e.key)
            .toList())
        ..sort();

    final importedRoutine = <Map<String, dynamic>>[
      for (final day in trainingDays)
        {
          'day_of_week': day,
          'title': _dayNames[day],
          'exercises': _routine[day],
        },
    ];
    userData['importedRoutine'] = importedRoutine;

    // Sincroniza availableDays con los días que realmente tienen ejercicios,
    // para que sea coherente con la rutina guardada.
    userData['availableDays'] =
        trainingDays.map((d) => d.toString()).toList();
    userData['trainingDays'] =
        trainingDays.map((d) => _dayNames[d]).join(', ');

    // Defaults derivados: como el usuario importa rutina, se omiten
    // signup_split y signup_days_duration. El split queda sin preferencia
    // (NULL en BD, el CHECK constraint no acepta 'custom') y el tiempo
    // por sesión cae al default estándar.
    userData['sessionDurationMinutes'] ??= 60;

    final next = OnboardingFlow.nextRoute('/signup_import_routine', userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
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
          if ((_routine[_selectedDay]?.isNotEmpty ?? false))
            IconButton(
              tooltip: 'Copiar este día a otro',
              icon: const Icon(Icons.copy_all_rounded, size: 22),
              onPressed: _openCopyDay,
            ),
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
                    'Elige un día y agrega tus ejercicios',
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
                      // Punto blanco = el día ya tiene ejercicios. Todos los
                      // días son seleccionables libremente.
                      final hasExercises = _isTrainingDay(i);
                      return GestureDetector(
                        onTap: () => _selectDay(i),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayLabels[i],
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (!isSelected && hasExercises) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
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
                'Agrega los ejercicios que quieras en cada día. Un día sin ejercicios queda como descanso.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: exercises.isEmpty
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
    final isCardio = mg == 'cardio';
    final sets = e['sets']?.toString() ?? '';
    final reps = e['reps']?.toString() ?? '';
    final rest = e['rest_seconds']?.toString() ?? '';
    final duration = e['duration_minutes']?.toString() ?? '';
    final distance = e['distance']?.toString() ?? '';
    final notes = e['optional_notes']?.toString() ?? '';
    final detail = isCardio
        ? '$duration min${distance.isNotEmpty ? '  •  $distance' : ''}'
        : '$sets series × $reps  •  Descanso ${rest}s';
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
                  detail,
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
  final _distance = TextEditingController();

  String _muscleGroup = 'chest';
  int _sets = 3;
  int _restSeconds = 60;
  int _durationMinutes = 20;
  String? _exerciseId;
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = const [];

  bool get _isCardio => _muscleGroup == 'cardio';

  /// Mapea `muscle_group_primary` del catálogo (español) al código que usa
  /// el dropdown del form (inglés). Si no hay match exacto, devuelve null
  /// para no pisar la selección manual.
  static const _muscleMap = {
    'Pecho': 'chest',
    'Espalda': 'back',
    'Cuádriceps': 'legs',
    'Femoral': 'legs',
    'Pantorrillas': 'legs',
    'Glúteos': 'glutes',
    'Hombros': 'shoulders',
    'Bíceps': 'biceps',
    'Tríceps': 'triceps',
    'Core': 'core',
    'Lumbar': 'core',
    'Cardio': 'cardio',
    'Cadena posterior': 'full_body',
    'Deportes': 'full_body',
  };

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
    _distance.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onNameChanged(String value) {
    // Si el usuario edita el texto después de elegir un canónico,
    // se invalida el match.
    if (_exerciseId != null) {
      setState(() => _exerciseId = null);
    }
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final rows = await ExerciseService.instance
            .searchForAutocomplete(q, limit: 6);
        if (!mounted) return;
        setState(() => _suggestions = rows);
      } catch (_) {
        if (!mounted) return;
        setState(() => _suggestions = const []);
      }
    });
  }

  void _pickSuggestion(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    final name = row['name_es']?.toString() ?? '';
    final mg = row['muscle_group_primary']?.toString();
    final mapped = mg != null ? _muscleMap[mg] : null;
    setState(() {
      _name.text = name;
      _exerciseId = id;
      _suggestions = const [];
      if (mapped != null) _muscleGroup = mapped;
    });
    FocusScope.of(context).unfocus();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final base = <String, dynamic>{
      'name': InputSanitizers.cleanText(_name.text, maxLen: 60),
      'muscle_group': _muscleGroup,
      'optional_notes': InputSanitizers.cleanOptional(_notes.text, maxLen: 160),
      'exercise_id': _exerciseId,
      'is_custom': _exerciseId == null,
    };
    if (_isCardio) {
      base['duration_minutes'] = _durationMinutes;
      final dist = InputSanitizers.cleanOptional(_distance.text, maxLen: 20);
      if (dist != null && dist.isNotEmpty) base['distance'] = dist;
    } else {
      base['sets'] = _sets;
      base['reps'] = InputSanitizers.cleanText(_reps.text, maxLen: 30);
      base['rest_seconds'] = _restSeconds;
    }
    Navigator.pop<Map<String, dynamic>>(context, base);
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
                  decoration: InputDecoration(
                    labelText: 'Nombre del ejercicio',
                    hintText: 'Ej. Press banca',
                    suffixIcon: _exerciseId != null
                        ? const Icon(Icons.verified, color: Colors.green, size: 20)
                        : null,
                  ),
                  onChanged: _onNameChanged,
                  validator: InputSanitizers.validateExerciseName,
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      children: _suggestions.map((s) {
                        return InkWell(
                          onTap: () => _pickSuggestion(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(Icons.fitness_center,
                                    size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s['name_es']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  s['muscle_group_primary']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else if (_name.text.trim().length >= 2 && _exerciseId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'No coincide con nuestro catálogo: lo guardaremos como ejercicio personalizado.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade700),
                    ),
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
                if (_isCardio) ...[
                  _numberStepper(
                    label: 'Duración (minutos)',
                    value: _durationMinutes,
                    min: 5,
                    max: 180,
                    step: 5,
                    onChanged: (v) => setState(() => _durationMinutes = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _distance,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Distancia o intensidad (opcional)',
                      hintText: 'Ej. 5 km, ritmo moderado',
                    ),
                  ),
                ] else ...[
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
                ],
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

class _CopyDaySheet extends StatefulWidget {
  const _CopyDaySheet({
    required this.sourceDay,
    required this.sourceDayName,
    required this.dayNames,
    required this.dayLabels,
  });

  final int sourceDay;
  final String sourceDayName;
  final List<String> dayNames;
  final List<String> dayLabels;

  @override
  State<_CopyDaySheet> createState() => _CopyDaySheetState();
}

class _CopyDaySheetState extends State<_CopyDaySheet> {
  final Set<int> _targets = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              'Copiar día',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Copiar los ejercicios de ${widget.sourceDayName} a:',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              if (i == widget.sourceDay) return const SizedBox.shrink();
              final selected = _targets.contains(i);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _targets.remove(i);
                  } else {
                    _targets.add(i);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.black26,
                    ),
                  ),
                  child: Text(
                    widget.dayLabels[i],
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sobrescribe los ejercicios del día destino.',
            style: TextStyle(fontSize: 11, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: _targets.isEmpty
                ? 'Selecciona al menos un día'
                : 'Copiar a ${_targets.length} día(s)',
            onPressed: _targets.isEmpty
                ? null
                : () => Navigator.pop<List<int>>(context, _targets.toList()),
          ),
        ],
      ),
    );
  }
}
