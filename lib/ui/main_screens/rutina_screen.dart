import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/analytics_service.dart';
import '../../services/exercise_service.dart';
import '../../services/rankable_exercise_lookup.dart';
import '../../services/routine_service.dart';
import '../../services/simulated_ai_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/skeletons/routine_skeleton.dart';
import '../ai_trainer/workout_feedback_prompt.dart';
import '../ranked/set_logger_sheet.dart';
import 'exercise_search_sheet.dart';

class RoutineScreen extends StatefulWidget {
  final int resetToken;
  const RoutineScreen({super.key, this.resetToken = 0});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _dayKeys = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  List<bool> _availableDays = List.filled(7, false);
  int _selectedDayIndex = 0;

  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  bool _isLoggingWorkout = false;

  // ID de la rutina guardada en Supabase para el día actual (null = solo IA)
  String? _savedRoutineId;
  List<Map<String, dynamic>> _savedRoutines = [];
  bool _hasArchivedForDay = false;
  bool _isRestoring = false;

  // ID del workout_log de hoy (se crea/recupera la primera vez que se
  // intenta registrar un set). Necesario para set_logs.
  String? _workoutLogId;
  // Cuantos sets se han registrado por ejercicio en el workout actual.
  final Map<String, int> _setCounts = {};
  // Por indice de ejercicio en _exercises: el match contra el catalogo
  // rankeable (si existe). Null = no rankea, solo checkbox.
  final Map<int, RankableExercise?> _rankableMatches = {};

  String _goal = 'MAINTAIN';
  String _location = 'GYM';
  String _gender = 'MALE';
  double _bmi = 22.0;
  int _age = 30;

  List<_Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = DateTime.now().weekday - 1;
    AnalyticsService.instance.routineScreenViewed();
    _load();
  }

  @override
  void didUpdateWidget(RoutineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      // Al volver a la tab de rutina: recarga todo desde BD para reflejar
      // rutinas copiadas / editadas en otras pantallas.
      setState(() {
        _selectedDayIndex = DateTime.now().weekday - 1;
        _isEditMode = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.instance.getRawMyProfile(),
        SupabaseService.instance.getOnboardingData(),
        RoutineService.instance.getMyRoutines(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final onboarding = results[1] as Map<String, dynamic>?;
      final savedRoutines = results[2] as List<Map<String, dynamic>>;

      final weight = (profile?['weight'] as num?)?.toDouble() ?? 70.0;
      final height = (profile?['height'] as num?)?.toDouble() ?? 170.0;
      final bmi = SimulatedAIService.calculateBMI(weight, height);

      // available_days puede venir en dos formatos:
      //   - Nuevo (onboarding extendido): ['0','1','3','4']  (índices 0..6)
      //   - Legacy: ['lunes','martes',...]  (strings en español)
      // Aceptamos ambos para no romper cuentas viejas ni nuevas.
      final rawDays = (onboarding?['available_days'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final available = List<bool>.generate(7, (i) {
        final idxStr = i.toString();
        final legacyKey = _dayKeys[i];
        return rawDays.contains(idxStr) || rawDays.contains(legacyKey);
      });
      final anySelected = available.any((d) => d);
      final finalDays = anySelected ? available : List<bool>.filled(7, true);

      final goal =
          (profile?['fitness_goal'] as String? ?? 'MAINTAIN').toUpperCase();
      final location =
          (profile?['training_location'] as String? ?? 'GYM').toUpperCase();
      final gender =
          (profile?['gender'] as String? ?? 'MALE').toUpperCase();
      final age = (profile?['age'] as num?)?.toInt() ?? 30;

      if (!mounted) return;
      setState(() {
        _availableDays = finalDays;
        _goal = goal;
        _location = location;
        _gender = gender;
        _bmi = bmi;
        _age = age;
        _savedRoutines = savedRoutines;
        _isLoading = false;
      });

      _generateExercises();
      _checkTodayCompleted();
    } catch (e) {
      debugPrint('RoutineScreen load error: $e');
      if (!mounted) return;
      setState(() {
        _availableDays = List.filled(7, true);
        _isLoading = false;
      });
      _generateExercises();
      _checkTodayCompleted();
    }
  }

  void _generateExercises() {
    // Si el día seleccionado NO está marcado como día de entrenamiento en el
    // onboarding, es día de descanso: limpiar la pantalla y NO mostrar ninguna
    // rutina previamente guardada. Esto evita que una rutina auto-guardada en
    // sesiones anteriores (cuando _availableDays podía caer al fallback de 7
    // días) siga apareciendo tras configurar el descanso.
    if (!_availableDays[_selectedDayIndex]) {
      setState(() {
        _savedRoutineId = null;
        _exercises = [];
        _hasArchivedForDay = false;
        _rankableMatches.clear();
      });
      return;
    }

    // Día de entrenamiento: primero revisar si hay rutina guardada
    final saved = _savedRoutines
        .where((r) => r['day_of_week'] == _selectedDayIndex)
        .firstOrNull;

    if (saved != null) {
      final exercises =
          (saved['routine_exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _savedRoutineId = saved['id'] as String;
        _exercises = exercises
            .map((e) => _Exercise(
                  name: e['name'] as String? ?? '',
                  muscleGroup: e['muscle_group'] as String? ?? '',
                  sets: (e['sets'] as num?)?.toInt() ?? 3,
                  reps: e['reps'] as String? ?? '',
                  restSeconds: (e['rest_seconds'] as num?)?.toInt() ?? 60,
                ))
            .toList();
      });
      _resolveRankableMatches();
      _resolveMediaUrls();
      _checkArchivedForDay();
      return;
    }

    // No hay rutina guardada → generar con IA
    _savedRoutineId = null;

    final trainingDayIndices = <int>[];
    for (int i = 0; i < 7; i++) {
      if (_availableDays[i]) trainingDayIndices.add(i);
    }

    final totalDays = trainingDayIndices.length;
    final positionInCycle = trainingDayIndices.indexOf(_selectedDayIndex);

    if (positionInCycle < 0) {
      setState(() => _exercises = []);
      return;
    }

    final raw = SimulatedAIService.generateRoutine(
      goal: _goal,
      trainingLocation: _location,
      gender: _gender,
      bmi: _bmi,
      age: _age,
      trainingDayIndex: positionInCycle,
      totalTrainingDays: totalDays > 0 ? totalDays : 3,
    );

    setState(() {
      _exercises = raw
          .map((e) => _Exercise(
                name: e['name'] as String? ?? '',
                muscleGroup: e['muscle_group'] as String? ?? '',
                sets: (e['sets'] as num?)?.toInt() ?? 3,
                reps: e['reps'] as String? ?? '',
                restSeconds: (e['rest_seconds'] as num?)?.toInt() ?? 60,
              ))
          .toList();
    });

    _resolveRankableMatches();
    _resolveMediaUrls();

    // Auto-persistir la rutina IA para que aparezca en el perfil del user
    // y otros puedan copiarla. Silencioso, sin snackbar.
    if (_exercises.isNotEmpty) {
      _autoSavePersonal(raw);
    }
    _checkArchivedForDay();
  }

  /// Resuelve, en paralelo, qué ejercicios del listado actual matchean con
  /// el catalogo rankeable. Solo los que matchean abriran SetLoggerSheet;
  /// el resto sigue siendo checkbox simple.
  Future<void> _resolveRankableMatches() async {
    final snapshot = List<_Exercise>.from(_exercises);
    if (snapshot.isEmpty) {
      if (mounted) setState(_rankableMatches.clear);
      return;
    }
    try {
      final results = await Future.wait(snapshot.map(
        (e) => RankableExerciseLookup.instance.findMatch(e.name),
      ));
      if (!mounted) return;
      // Si el listado cambió mientras resolvíamos (ej. cambio de día),
      // descartamos resultados obsoletos.
      if (!_sameExerciseList(snapshot, _exercises)) return;
      setState(() {
        _rankableMatches.clear();
        for (var i = 0; i < results.length; i++) {
          _rankableMatches[i] = results[i];
        }
      });
    } catch (e) {
      debugPrint('resolveRankableMatches error: $e');
    }
  }

  Future<void> _resolveMediaUrls() async {
    final snapshot = List<_Exercise>.from(_exercises);
    if (snapshot.isEmpty) return;
    try {
      final names = snapshot.map((e) => e.name).toList();
      final urlMap = await ExerciseService.instance.mediaUrlsByName(names);
      if (!mounted) return;
      if (!_sameExerciseList(snapshot, _exercises)) return;
      setState(() {
        _exercises = _exercises.map((e) => _Exercise(
          name: e.name,
          muscleGroup: e.muscleGroup,
          sets: e.sets,
          reps: e.reps,
          restSeconds: e.restSeconds,
          mediaUrl: urlMap[e.name],
          isChecked: e.isChecked,
        )).toList();
      });
    } catch (e) {
      debugPrint('resolveMediaUrls error: $e');
    }
  }

  bool _sameExerciseList(List<_Exercise> a, List<_Exercise> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name) return false;
    }
    return true;
  }

  Future<void> _checkArchivedForDay() async {
    try {
      final has = await RoutineService.instance
          .hasArchivedRoutineForDay(_selectedDayIndex);
      if (!mounted) return;
      setState(() => _hasArchivedForDay = has);
    } catch (_) {}
  }

  Future<void> _checkTodayCompleted() async {
    final uid = SupabaseService.instance.currentUserId;
    if (uid == null || _exercises.isEmpty) return;
    try {
      final now = DateTime.now();
      final daysDiff = _selectedDayIndex - (now.weekday - 1);
      final target = DateTime(now.year, now.month, now.day).add(Duration(days: daysDiff));
      final dateStr =
          '${target.year}-${target.month.toString().padLeft(2, '0')}-${target.day.toString().padLeft(2, '0')}';
      final log = await SupabaseService.instance.client
          .from('workout_logs')
          .select('id')
          .eq('user_id', uid)
          .eq('logged_at', dateStr)
          .maybeSingle();
      if (!mounted) return;
      if (log != null) {
        final logId = log['id'] as String?;
        setState(() {
          _workoutLogId = logId;
          for (final e in _exercises) {
            e.isChecked = true;
          }
        });
        if (logId != null) {
          await _refreshSetCounts(logId);
        }
      }
    } catch (_) {}
  }

  /// Carga cuantos sets se han registrado por exercise_name en este workout.
  Future<void> _refreshSetCounts(String workoutLogId) async {
    final uid = SupabaseService.instance.currentUserId;
    if (uid == null) return;
    try {
      final rows = await SupabaseService.instance.client
          .from('set_logs')
          .select('exercise_name')
          .eq('user_id', uid)
          .eq('workout_log_id', workoutLogId);
      final counts = <String, int>{};
      for (final r in (rows as List)) {
        final name = (r as Map)['exercise_name'] as String?;
        if (name == null) continue;
        counts[name] = (counts[name] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() {
        _setCounts
          ..clear()
          ..addAll(counts);
        for (final e in _exercises) {
          if ((counts[e.name] ?? 0) > 0) e.isChecked = true;
        }
      });
    } catch (_) {}
  }

  /// Garantiza que exista un workout_log para hoy y devuelve su id.
  Future<String?> _ensureWorkoutLogId() async {
    if (_workoutLogId != null) return _workoutLogId;
    final id = await RoutineService.instance
        .logWorkoutExecution(routineId: _savedRoutineId);
    if (mounted) setState(() => _workoutLogId = id);
    return id;
  }

  Future<void> _openSetLoggerFor(_Exercise e, RankableExercise match) async {
    final logId = await _ensureWorkoutLogId();
    if (logId == null || !mounted) return;
    final added = await SetLoggerSheet.show(
      context,
      exerciseName: e.name,
      muscleGroup: e.muscleGroup,
      exerciseId: match.id,
      movementPattern: match.movementPattern,
      targetSets: e.sets,
      targetReps: e.reps,
      workoutLogId: logId,
    );
    if (!mounted) return;
    await _refreshSetCounts(logId);
    if (added == true) {
      setState(() => e.isChecked = true);
    }
  }

  /// Toggle simple para ejercicios NO rankeables: solo marca/desmarca el
  /// checkbox local y se asegura de que exista un workout_log para el dia
  /// (igual que los rankeables, asi "Completar entrenamiento" sigue
  /// funcionando consistentemente).
  Future<void> _toggleSimpleExercise(_Exercise e) async {
    await _ensureWorkoutLogId();
    if (!mounted) return;
    setState(() => e.isChecked = !e.isChecked);
  }

  Future<void> _restorePreviousRoutine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Volver a tu rutina anterior',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          'Se reemplazará la rutina actual de este día por la que tenías antes de copiar.',
          style: TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Restaurar',
              style: TextStyle(
                color: Color(0xFF00BFFF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    try {
      await RoutineService.instance.restorePersonalDay(_selectedDayIndex);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(PhosphorIconsFill.checkCircle,
                color: Color(0xFF00BFFF), size: 20),
            SizedBox(width: 10),
            Text('Rutina anterior restaurada'),
          ]),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2200),
        ),
      );
    } catch (e) {
      debugPrint('restore error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restaurar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _autoSavePersonal(List<Map<String, dynamic>> raw) async {
    const dayNames = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves',
      'Viernes', 'Sábado', 'Domingo',
    ];
    try {
      final exerciseMaps = raw
          .map((e) => {
                'name': e['name'],
                'muscle_group': e['muscle_group'],
                'sets': e['sets'],
                'reps': e['reps'],
                'rest_seconds': e['rest_seconds'],
              })
          .toList();
      final newId = await RoutineService.instance.saveRoutine(
        title: dayNames[_selectedDayIndex],
        goal: _goal,
        trainingLocation: _location,
        dayOfWeek: _selectedDayIndex,
        exercises: exerciseMaps,
      );
      if (!mounted) return;
      setState(() {
        _savedRoutineId = newId;
        _savedRoutines.removeWhere((r) => r['day_of_week'] == _selectedDayIndex);
        _savedRoutines.add({
          'id': newId,
          'day_of_week': _selectedDayIndex,
          'routine_exercises': exerciseMaps,
        });
      });
    } catch (e) {
      debugPrint('autoSavePersonal error: $e');
    }
  }

  void _selectDay(int index) {
    if (!_availableDays[index]) return;
    setState(() {
      _selectedDayIndex = index;
      _isEditMode = false;
    });
    _generateExercises();
    _checkTodayCompleted();
  }

  Future<void> _saveEdit() async {
    setState(() { _isEditMode = false; _isSaving = true; });
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

      if (_savedRoutineId != null) {
        await RoutineService.instance.updateExercises(_savedRoutineId!, exerciseMaps);
      } else {
        const dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
        final newId = await RoutineService.instance.saveRoutine(
          title: dayNames[_selectedDayIndex],
          goal: _goal,
          trainingLocation: _location,
          dayOfWeek: _selectedDayIndex,
          exercises: exerciseMaps,
        );
        _savedRoutineId = newId;
        _savedRoutines.removeWhere((r) => r['day_of_week'] == _selectedDayIndex);
        _savedRoutines.add({'id': newId, 'day_of_week': _selectedDayIndex, 'routine_exercises': exerciseMaps});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(PhosphorIconsFill.checkCircle, color: Color(0xFF00BFFF), size: 20),
            SizedBox(width: 10),
            Text('Rutina guardada'),
          ]),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2000),
        ));
      }
    } catch (e) {
      debugPrint('Error guardando rutina: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logWorkoutExecution() async {
    setState(() {
      _isLoggingWorkout = true;
      for (final e in _exercises) {
        e.isChecked = true;
      }
    });
    try {
      final id = await RoutineService.instance
          .logWorkoutExecution(routineId: _savedRoutineId);
      if (!mounted) return;
      if (id != null) setState(() => _workoutLogId = id);
      _showCompletionSheet();
    } catch (e) {
      debugPrint('_logWorkoutExecution error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingWorkout = false);
    }
  }

  void _showCompletionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CompletionSheet(),
    );
  }

  void _confirmDelete(_Exercise e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar ejercicio?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Se eliminara '${e.name}' de tu rutina de hoy.",
          style: const TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _exercises.remove(e));
              Navigator.pop(context);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Color(0xFFEF5350),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openExerciseSearch({String? preselectedMuscle, int? replaceIndex}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseSearchSheet(
        preselectedMuscle: preselectedMuscle,
        userLocation: _location.toLowerCase(),
        onExerciseSelected: (exercise) {
          final newEx = _Exercise(
            name: exercise['name_es'] as String,
            muscleGroup: exercise['muscle_group_primary'] as String,
            sets: 3,
            reps: '8-12',
            restSeconds: 60,
            mediaUrl: exercise['media_url'] as String?,
          );
          setState(() {
            if (replaceIndex != null && replaceIndex < _exercises.length) {
              _exercises[replaceIndex] = newEx;
            } else {
              _exercises.add(newEx);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    PhosphorIconsFill.checkCircle,
                    color: Color(0xFF00BFFF),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${exercise['name_es']} agregado')),
                ],
              ),
              backgroundColor: const Color(0xFF1A1A2E),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(milliseconds: 2500),
            ),
          );
        },
      ),
    );
  }

  int get _completed => _exercises.where((e) => e.isChecked).length;

  void _showImagePreview(String imageUrl, String exerciseName) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  exerciseName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Toca para cerrar',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exerciseIconFallback() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF00BFFF).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(PhosphorIconsDuotone.barbell, color: Color(0xFF00BFFF)),
      );

  Widget _buildExerciseCard(
    _Exercise e, {
    required bool editMode,
    bool rankable = false,
    Key? key,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: editMode
            ? Colors.grey[100]
            : (e.isChecked ? Colors.green[50] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(16),
        border: editMode
            ? Border.all(color: const Color(0xFF00BFFF), width: 1.5)
            : (e.isChecked ? Border.all(color: Colors.green.shade300) : null),
        boxShadow: editMode
            ? [
                BoxShadow(
                  color: const Color(0xFF00BFFF).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          if (editMode)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(PhosphorIconsRegular.dotsSixVertical, color: Colors.black38, size: 24),
            ),
          (e.mediaUrl != null && e.mediaUrl!.isNotEmpty)
              ? GestureDetector(
                  onTap: () => _showImagePreview(e.mediaUrl!, e.name),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: e.mediaUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _exerciseIconFallback(),
                      errorWidget: (_, __, ___) => _exerciseIconFallback(),
                    ),
                  ),
                )
              : _exerciseIconFallback(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        e.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          decoration: (!editMode && e.isChecked)
                              ? TextDecoration.lineThrough
                              : null,
                          color: (!editMode && e.isChecked)
                              ? Colors.black45
                              : Colors.black,
                        ),
                      ),
                    ),
                    if (!editMode && rankable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsBold.medal,
                              size: 12,
                              color: AppColors.accentOrange,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Ranked',
                              style: TextStyle(
                                color: AppColors.accentOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  e.muscleGroup,
                  style: const TextStyle(
                    color: Color(0xFF00BFFF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${e.sets} series x ${e.reps}  -  Descanso ${e.restSeconds}s',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                if (!editMode && rankable) ...[
                  const SizedBox(height: 4),
                  Builder(builder: (_) {
                    final count = _setCounts[e.name] ?? 0;
                    if (count > 0) {
                      return Row(
                        children: [
                          const Icon(
                            PhosphorIconsFill.barbell,
                            size: 12,
                            color: Color(0xFF00BFFF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$count set${count == 1 ? '' : 's'} registrado${count == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Color(0xFF00BFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }
                    return const Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.handTap,
                          size: 12,
                          color: Colors.black38,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Toca para registrar peso y reps',
                          style: TextStyle(
                            color: Colors.black38,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
                if (editMode) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _openExerciseSearch(
                      preselectedMuscle: e.muscleGroup,
                      replaceIndex: _exercises.indexOf(e),
                    ),
                    icon: const Icon(
                      PhosphorIconsRegular.arrowsLeftRight,
                      size: 16,
                      color: Color(0xFF00BFFF),
                    ),
                    label: const Text(
                      'Cambiar',
                      style: TextStyle(
                        color: Color(0xFF00BFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (editMode)
            IconButton(
              icon: const Icon(
                PhosphorIconsRegular.x,
                color: Color(0xFFEF5350),
                size: 20,
              ),
              onPressed: () => _confirmDelete(e),
            )
          else
            Icon(
              e.isChecked
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsRegular.circle,
              color: e.isChecked ? Colors.green : Colors.grey,
            ),
        ],
      ),
    );
  }

  Widget _buildNormalList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _exercises.length + 1,
      itemBuilder: (context, i) {
        if (i == _exercises.length) return _buildCustomRoutineCta();
        final e = _exercises[i];
        final match = _rankableMatches[i];
        return GestureDetector(
          onTap: () {
            if (match != null) {
              _openSetLoggerFor(e, match);
            } else {
              _toggleSimpleExercise(e);
            }
          },
          child: _buildExerciseCard(
            e,
            editMode: false,
            rankable: match != null,
          ),
        );
      },
    );
  }

  Widget _buildEditList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _exercises.length + 1,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex >= _exercises.length || newIndex > _exercises.length) {
          return;
        }
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _exercises.removeAt(oldIndex);
          _exercises.insert(newIndex, item);
        });
      },
      itemBuilder: (context, i) {
        if (i == _exercises.length) {
          return Container(
            key: const ValueKey('add_button'),
            margin: const EdgeInsets.only(bottom: 12, top: 4),
            child: GestureDetector(
              onTap: () => _openExerciseSearch(),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF00BFFF),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIconsFill.plusCircle,
                      color: Color(0xFF00BFFF),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Agregar ejercicio',
                      style: TextStyle(
                        color: Color(0xFF00BFFF),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        final e = _exercises[i];
        return _buildExerciseCard(
          e,
          editMode: true,
          key: ValueKey(e.name + i.toString()),
        );
      },
    );
  }

  Widget _buildCustomRoutineCta() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF00BFFF).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00BFFF).withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.star,
            color: Color(0xFF00BFFF),
            size: 18,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tienes tu propio programa?',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  'Crea tu rutina personalizada',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
                final created = await Navigator.pushNamed(
                  context,
                  '/create-routine',
                  arguments: {
                    'selectedDay': _selectedDayIndex,
                    'availableDays': _availableDays,
                  },
                );
                if (created == true) _load();
              },
            child: const Text(
              'Crear ->',
              style: TextStyle(
                color: Color(0xFF00BFFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      margin: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final isSelected = i == _selectedDayIndex;
          final isToday = i == todayIndex;
          final isAvailable = _availableDays[i];

          return GestureDetector(
            onTap: () => _selectDay(i),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00BFFF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: const Color(0xFF00BFFF), width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _dayLabels[i],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? const Color(0xFF00BFFF)
                              : isAvailable
                                  ? Colors.black54
                                  : Colors.orange.shade300,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday && !isSelected
                        ? const Color(0xFF00BFFF)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: RoutineSkeletonList(count: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _isEditMode
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: TextButton(
                onPressed: () => setState(() => _isEditMode = false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ),
              title: const Text(
                'Editando',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              centerTitle: true,
              actions: [
                _isSaving
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00BFFF))),
                      )
                    : TextButton(
                        onPressed: _saveEdit,
                        child: const Text(
                          'Guardar',
                          style: TextStyle(
                            color: Color(0xFF00BFFF),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ],
            )
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.black87, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  : (_hasArchivedForDay
                      ? (_isRestoring
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00BFFF),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                PhosphorIconsDuotone.clockCounterClockwise,
                                color: Color(0xFF00BFFF),
                              ),
                              tooltip: 'Volver a tu rutina anterior',
                              onPressed: _restorePreviousRoutine,
                            ))
                      : null),
              title: const Text(
                'Rutina del Dia',
                style: TextStyle(color: Colors.black),
              ),
              centerTitle: true,
              actions: [
                if (_hasArchivedForDay && Navigator.canPop(context))
                  (_isRestoring
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00BFFF),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            PhosphorIconsDuotone.clockCounterClockwise,
                            color: Color(0xFF00BFFF),
                          ),
                          tooltip: 'Volver a tu rutina anterior',
                          onPressed: _restorePreviousRoutine,
                        )),
                if (_exercises.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      PhosphorIconsRegular.pencilSimple,
                      color: Color(0xFF00BFFF),
                    ),
                    tooltip: 'Editar rutina',
                    onPressed: () => setState(() => _isEditMode = true),
                  ),
              ],
            ),
      body: Column(
        children: [
          _buildDaySelector(),

          if (_availableDays.where((d) => d).length >= 6)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.warning,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Recuerda incluir al menos 1 dia de descanso por semana para recuperarte.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_completed/${_exercises.length} ejercicios completados',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _exercises.isEmpty
                          ? 0
                          : _completed / _exercises.length,
                      backgroundColor: Colors.grey[300],
                      color: const Color(0xFF00BFFF),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _exercises.isEmpty
                ? const Center(
                    child: Text(
                      'Dia de descanso. Aprovecha para recuperarte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 16),
                    ),
                  )
                : _isEditMode
                    ? _buildEditList()
                    : _buildNormalList(),
          ),

          if (_savedRoutineId != null && !_isEditMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoggingWorkout ? null : _logWorkoutExecution,
                  icon: _isLoggingWorkout
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(PhosphorIconsRegular.checks, size: 20),
                  label: const Text(
                    'Completar entrenamiento',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              SimulatedAIService.disclaimer,
              style: const TextStyle(color: Colors.black38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionSheet extends StatelessWidget {
  const _CompletionSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsFill.checkCircle,
                  color: Color(0xFF00C853),
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Entrenamiento completado',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Un dia mas de progreso',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 8),
              // Solo visible para usuarios Premium (WorkoutFeedbackPrompt
              // maneja internamente el tier check y muestra SizedBox.shrink
              // para Free/Plus).
              const WorkoutFeedbackPrompt(),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Exercise {
  final String name;
  final String muscleGroup;
  final int sets;
  final String reps;
  final int restSeconds;
  final String? mediaUrl;
  bool isChecked;

  _Exercise({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.mediaUrl,
    this.isChecked = false,
  });
}
