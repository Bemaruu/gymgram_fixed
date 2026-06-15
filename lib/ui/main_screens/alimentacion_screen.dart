import 'dart:convert';
import 'dart:io';
import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/country_utils.dart';
import '../../models/food_log.dart';
import '../../services/analytics_service.dart';
import '../../services/food_scan_service.dart';
import '../../services/food_service.dart';
import '../../services/nutrition_calculator.dart';
import '../../services/subscription_service.dart';
import '../../services/supabase_service.dart';
import '../../services/water_service.dart';
import '../../widgets/ai_plan_loading.dart';
import '../../widgets/food_icon.dart';
import '../../widgets/skeletons/meal_skeleton.dart';
import '../shared/first_use_disclaimer_modal.dart';
import 'food_scan_animation_screen.dart';
import 'food_search_screen.dart';

class AlimentacionScreen extends StatefulWidget {
  final int resetToken;
  const AlimentacionScreen({super.key, this.resetToken = 0});

  @override
  State<AlimentacionScreen> createState() => _AlimentacionScreenState();
}

class _AlimentacionScreenState extends State<AlimentacionScreen> {
  bool _isLoading = true;
  bool _isPaid = false; // Plus/Premium: habilita el escáner de comida.
  int _selectedDayIndex = DateTime.now().weekday - 1;
  int _waterCount = 0;

  Map<String, dynamic>? _plan;
  List<Map<String, dynamic>> _items = [];
  // Plan semanal cacheado en memoria. Cada elemento = { day, meals: [...] }.
  // Se carga 1 vez por week_index desde nutrition_plans (DB) o edge fallback.
  List<Map<String, dynamic>>? _weekDays;
  int? _weekPlanIndex;
  // Unidad checkeable = "itemIndex:compIndex" (compIndex -1 = item completo/receta).
  final Set<String> _checkedKeys = {};
  // Mapea la unidad del plan al id de su food_log registrado.
  Map<String, String> _registeredLogIds = {};
  String _togglingKey = '';
  // Variación por comida (slotIndex → nº de cambios), persistida por día.
  Map<int, int> _slotVariations = {};

  List<FoodLog> _dailyLogs = [];
  Map<String, double> _dailyTotals = {};
  bool _logsLoading = false;

  String _goal = 'MAINTAIN';
  String _gender = 'MALE';
  double _weight = 70.0;
  double _targetWeight = 0;
  int _age = 30;
  double _height = 170.0;
  int _trainingDaysPerWeek = 3;
  String _dailyActivityLevel = DailyActivityLevel.moderate;
  bool _eatingDisorderRisk = false;
  String? _cookingTime;
  String? _userId;
  String _countryCode = CountryUtils.defaultCountry;
  // Si food_preferences incluye 'vegan'/'vegana', mostramos warning B12
  // (NIH DRI: la B12 no se obtiene de fuentes 100% vegetales).
  bool _isVegan = false;

  static const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealLabel = {
    'breakfast': 'Desayuno',
    'lunch': 'Almuerzo',
    'dinner': 'Cena',
    'snack': 'Merienda / Snack',
    'pre_workout': 'Pre-entreno',
    'post_workout': 'Post-entreno',
  };
  static const _mealIcon = {
    'breakfast': PhosphorIconsRegular.sun,
    'lunch': PhosphorIconsRegular.forkKnife,
    'dinner': PhosphorIconsRegular.moon,
    'snack': PhosphorIconsRegular.cookie,
    'pre_workout': PhosphorIconsRegular.lightning,
    'post_workout': PhosphorIconsRegular.barbell,
  };

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.nutritionScreenViewed();
    _load();
    _loadTier();
  }

  Future<void> _loadTier() async {
    final status = await SubscriptionService.instance.currentStatus();
    if (mounted) setState(() => _isPaid = status.isPaid);
  }

  @override
  void didUpdateWidget(AlimentacionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetToken != widget.resetToken) {
      // TODO: si el onboarding cambio (peso/objetivo/restricciones), invalidar
      // el plan semanal cacheado en DB:
      //   await Supabase.instance.client
      //     .from('nutrition_plans').delete().eq('user_id', _userId);
      // y forzar regeneracion. Por ahora solo limpia cache en memoria.
      _weekDays = null;
      _weekPlanIndex = null;
      final today = DateTime.now().weekday - 1;
      if (_selectedDayIndex != today) {
        setState(() => _selectedDayIndex = today);
      }
      _refreshSelectedDay();
    }
  }

  DateTime _dateForDayIndex(int i) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: i));
  }

  Future<void> _load() async {
    try {
      final profile = await SupabaseService.instance.getRawMyProfile();
      final onboarding = await SupabaseService.instance.getOnboardingData();
      final water = await WaterService.instance.getGlassesToday();

      final goal = (profile?['fitness_goal'] as String? ?? 'MAINTAIN').toUpperCase();
      final gender = (profile?['gender'] as String? ?? 'MALE').toUpperCase();
      final weight = (profile?['weight'] as num?)?.toDouble() ?? 70.0;
      final age = (profile?['age'] as num?)?.toInt() ?? 30;
      final height = (profile?['height'] as num?)?.toDouble() ?? 170.0;
      final targetWeight = (profile?['target_weight'] as num?)?.toDouble() ?? weight;

      final rawDays = (onboarding?['available_days'] as List?)?.cast<String>() ?? [];
      final trainingDaysPerWeek = rawDays.isEmpty ? 3 : rawDays.length.clamp(1, 7);

      final dailyActivityLevel =
          (onboarding?['daily_activity_level'] as String?) ??
              DailyActivityLevel.moderate;

      final cookingTime = onboarding?['cooking_time_preference'] as String?;
      final eatingDisorderRisk =
          profile?['eating_disorder_risk'] == true;
      final foodPrefs =
          (onboarding?['food_preferences'] as List?)?.cast<String?>() ?? const [];
      final isVegan = foodPrefs.any((p) {
        final s = (p ?? '').toLowerCase();
        return s == 'vegan' || s == 'vegana';
      });
      final countryCode = CountryUtils.normalize(
        profile?['country_code'] as String? ??
            onboarding?['country_code'] as String?,
        fallback: CountryUtils.detectDeviceCountry(),
      );
      final userId = SupabaseService.instance.currentUserId;

      if (!mounted) return;
      setState(() {
        _goal = goal;
        _gender = gender;
        _weight = weight;
        _targetWeight = targetWeight;
        _age = age;
        _height = height;
        _trainingDaysPerWeek = trainingDaysPerWeek;
        _dailyActivityLevel = dailyActivityLevel;
        _cookingTime = cookingTime;
        _eatingDisorderRisk = eatingDisorderRisk;
        _isVegan = isVegan;
        _userId = userId;
        _countryCode = countryCode;
        _waterCount = water;
        // _isLoading se mantiene true hasta que el plan esté listo
      });

      await _generatePlan();
      if (mounted) setState(() => _isLoading = false);
      await _loadDailyLogs(DateTime.now());
      _reconcilePlanChecks();
      _maybeShowFirstUseDisclaimer();
    } catch (e) {
      debugPrint('AlimentacionScreen load error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSelectedDay() async {
    // No invoca edge: solo re-mapea el dia del plan semanal cacheado y
    // refresca los logs reales del dia.
    await _generatePlan();
    await _loadDailyLogs(_dateForDayIndex(_selectedDayIndex));
    _reconcilePlanChecks();
  }

  void _maybeShowFirstUseDisclaimer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FirstUseDisclaimerModal.ensureAcceptedFor(context);
    });
  }

  /// Construye el plan diario que ve la UI. NO invoca IA: lee del plan semanal
  /// cacheado (`_weekDays`). Si la semana actual aun no esta cargada en memoria,
  /// llama a `_loadWeekPlan()` que consulta DB y como ultimo recurso la edge.
  Future<void> _generatePlan() async {
    final selectedDate = _dateForDayIndex(_selectedDayIndex);
    final weekIndex = _weeksSinceEpoch(selectedDate);

    _slotVariations = await _loadVariations(weekIndex);

    // Targets nutricionales (locales, deterministas).
    final effectiveTarget = _targetWeight > 0 ? _targetWeight : _weight;
    final nutrition = NutritionCalculator.calculate(
      gender: _gender,
      age: _age,
      weightKg: _weight,
      heightCm: _height,
      targetWeightKg: effectiveTarget,
      fitnessGoal: _goal,
      trainingDaysPerWeek: _trainingDaysPerWeek,
      dailyActivityLevel: _dailyActivityLevel,
      eatingDisorderRisk: _eatingDisorderRisk,
    );

    // Carga plan semanal solo si no esta cacheado para este weekIndex.
    if (_weekDays == null || _weekPlanIndex != weekIndex) {
      await _loadWeekPlan(weekIndex);
    }

    final items = _mapDayToItems(_selectedDayIndex);

    if (!mounted) return;

    final plan = <String, dynamic>{
      'title': 'Plan ${_goalLabel(_goal)}',
      'country_code': _countryCode,
      'total_calories': nutrition.recommendedCalories,
      'maintenance_calories': nutrition.maintenanceCalories,
      'bmr': nutrition.bmr,
      'calorie_adjustment': nutrition.calorieAdjustment,
      'goal_interpretation': nutrition.goalInterpretation,
      'strategy': nutrition.strategy,
      'explanation_text': nutrition.explanationText,
      'protein_grams': nutrition.proteinGrams,
      'carbs_grams': nutrition.carbsGrams,
      'fats_grams': nutrition.fatsGrams,
      'fiber_grams': nutrition.fiberGrams,
      'water_ml': nutrition.waterMl,
      'sodium_max_mg': nutrition.sodiumMaxMg,
      'disclaimer': _disclaimerText,
      'week_index': weekIndex,
      'cooking_time': _cookingTime,
      'items': items,
    };

    setState(() {
      _plan = plan;
      _items = items;
      _checkedKeys.clear();
    });
  }

  /// Carga el plan semanal: 1) lee `nutrition_plans` (cache DB), 2) si no
  /// existe, invoca edge `generate-nutrition-plan` con `week_index` actual.
  /// La edge persiste en DB asi que la siguiente apertura no quema IA.
  Future<void> _loadWeekPlan(int weekIndex, {bool forceRegenerate = false}) async {
    if (!forceRegenerate) {
      try {
        final row = await Supabase.instance.client
            .from('nutrition_plans')
            .select('plan_json')
            .eq('user_id', _userId ?? '')
            .eq('week_index', weekIndex)
            .maybeSingle();
        if (row != null) {
          final planJson = row['plan_json'];
          final week = planJson is Map ? (planJson['week'] as List?) : null;
          if (week != null && week.isNotEmpty) {
            _weekDays = week
                .whereType<Map>()
                .map((d) => Map<String, dynamic>.from(d))
                .toList();
            _weekPlanIndex = weekIndex;
            return;
          }
        }
      } catch (e) {
        debugPrint('nutrition_plans cache read error: $e');
      }
    }

    // Fallback: invocar edge (la edge upsert-ea en DB).
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'generate-nutrition-plan',
        body: <String, dynamic>{'week_index': weekIndex},
      );

      if (res.status == 429) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Llegaste al límite mensual de IA. Vuelve el próximo mes.',
              ),
            ),
          );
        }
        _weekDays = [];
        _weekPlanIndex = weekIndex;
        return;
      }
      if (res.status >= 400) {
        // La edge a veces timeoutea (502) pero alcanza a persistir el plan
        // antes de que el gateway corte. Re-leemos DB antes de rendirnos.
        if (await _loadCachedPlan(weekIndex)) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pudimos generar tu plan, intenta más tarde.'),
            ),
          );
        }
        _weekDays = [];
        _weekPlanIndex = weekIndex;
        return;
      }

      final data = res.data;
      if (data is Map) {
        final plan = data['plan'];
        final week = plan is Map ? (plan['week'] as List?) : null;
        if (week != null) {
          _weekDays = week
              .whereType<Map>()
              .map((d) => Map<String, dynamic>.from(d))
              .toList();
          _weekPlanIndex = weekIndex;
          return;
        }
      }
      _weekDays = [];
      _weekPlanIndex = weekIndex;
    } catch (e) {
      debugPrint('generate-nutrition-plan edge error: $e');
      // Mismo caso que el 502: el plan puede haberse persistido aunque la
      // invocación del cliente haya fallado/timeoutado.
      if (await _loadCachedPlan(weekIndex)) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos generar tu plan, intenta más tarde.'),
          ),
        );
      }
      _weekDays = [];
      _weekPlanIndex = weekIndex;
    }
  }

  /// Re-lee `nutrition_plans` y, si encuentra un plan válido para [weekIndex],
  /// hidrata `_weekDays`/`_weekPlanIndex` y devuelve true. Caso contrario, false.
  Future<bool> _loadCachedPlan(int weekIndex) async {
    try {
      final row = await Supabase.instance.client
          .from('nutrition_plans')
          .select('plan_json')
          .eq('user_id', _userId ?? '')
          .eq('week_index', weekIndex)
          .maybeSingle();
      if (row == null) return false;
      final planJson = row['plan_json'];
      final week = planJson is Map ? (planJson['week'] as List?) : null;
      if (week == null || week.isEmpty) return false;
      _weekDays = week
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
      _weekPlanIndex = weekIndex;
      return true;
    } catch (e) {
      debugPrint('nutrition_plans recheck error: $e');
      return false;
    }
  }

  /// Convierte el dia indicado del plan semanal a la lista plana de items
  /// que consume la UI (formato historico: meal_type/name/calories/macros/porcion_g).
  List<Map<String, dynamic>> _mapDayToItems(int dayIndex) {
    final days = _weekDays;
    if (days == null || days.isEmpty) return const [];
    // Plan tiene "day": 1..7. Mapeamos dayIndex (0..6) con el orden de la lista.
    if (dayIndex < 0 || dayIndex >= days.length) return const [];
    final day = days[dayIndex];
    final meals = (day['meals'] as List?) ?? const [];
    final out = <Map<String, dynamic>>[];
    for (final m in meals) {
      if (m is! Map) continue;
      final mealType = m['meal_type']?.toString() ?? 'snack';
      final foods = (m['foods'] as List?) ?? const [];
      for (final f in foods) {
        if (f is! Map) continue;
        final grams = (f['grams'] as num?)?.toDouble() ?? 0;
        out.add({
          'meal_type': mealType,
          'name': f['name']?.toString() ?? '',
          'ingredients': const <String>[],
          'calories': (f['kcal'] as num?)?.round() ?? 0,
          'protein': (f['protein'] as num?)?.toDouble() ?? 0,
          'carbs': (f['carbs'] as num?)?.toDouble() ?? 0,
          'fats': (f['fat'] as num?)?.toDouble() ?? 0,
          'porcion_g': grams.round(),
        });
      }
    }
    return out;
  }

  // Disclaimer reforzado: GymGram entrega estimaciones nutricionales. NO
  // sustituye consulta con nutricionista, médico o profesional habilitado.
  // Macros de marcas comerciales tomadas de etiqueta oficial pública. Macros
  // de platos caseros LATAM son estimaciones basadas en INTA/LATINFOODS.
  static const String _disclaimerText =
      'Estimación nutricional. No reemplaza la asesoría de un nutricionista o '
      'médico. Marcas comerciales: macros de etiqueta oficial. Platos caseros: '
      'aproximación basada en tablas INTA/LATINFOODS.';

  static String _goalLabel(String goal) {
    switch (goal.toUpperCase()) {
      case 'LOSE_WEIGHT':
        return 'pérdida de grasa';
      case 'GAIN_MUSCLE':
        return 'ganancia muscular';
      default:
        return 'mantenimiento';
    }
  }

  // ── Persistencia de "cambios de comida" (swap) por día ──────────────────
  String _variationsKey(int weekIndex) =>
      'mealvar_${_userId ?? 'anon'}_${weekIndex}_$_selectedDayIndex';

  Future<Map<int, int>> _loadVariations(int weekIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_variationsKey(weekIndex));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveVariations(int weekIndex, Map<int, int> v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(v.map((k, val) => MapEntry(k.toString(), val)));
      await prefs.setString(_variationsKey(weekIndex), encoded);
    } catch (_) {}
  }

  /// Swap LOCAL de una comida: rota entre alimentos del mismo meal_type
  /// presentes en OTROS dias de la misma semana cacheada. NO invoca IA.
  Future<void> _swapMeal(int itemIndex) async {
    if (itemIndex < 0 || itemIndex >= _items.length) return;
    final current = _items[itemIndex];
    final mealType = current['meal_type']?.toString();
    final currentName = current['name']?.toString();
    if (mealType == null) return;

    final days = _weekDays;
    if (days == null || days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin alternativas disponibles.')),
      );
      return;
    }

    // Junta candidatos de OTROS dias con mismo meal_type, excluyendo el actual
    // y los nombres ya presentes en el dia actual (evita duplicados visuales).
    final inDayNames = _items
        .where((i) => i['meal_type'] == mealType)
        .map((i) => i['name']?.toString().toLowerCase())
        .whereType<String>()
        .toSet();

    final candidates = <Map<String, dynamic>>[];
    for (var d = 0; d < days.length; d++) {
      if (d == _selectedDayIndex) continue;
      final meals = (days[d]['meals'] as List?) ?? const [];
      for (final m in meals) {
        if (m is! Map) continue;
        if (m['meal_type']?.toString() != mealType) continue;
        final foods = (m['foods'] as List?) ?? const [];
        for (final f in foods) {
          if (f is! Map) continue;
          final name = f['name']?.toString() ?? '';
          if (name.isEmpty) continue;
          if (name.toLowerCase() == (currentName ?? '').toLowerCase()) continue;
          if (inDayNames.contains(name.toLowerCase())) continue;
          candidates.add(Map<String, dynamic>.from(f));
        }
      }
    }

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin alternativas disponibles.')),
      );
      return;
    }

    // Persistir el contador (sirve para elegir distinta opcion en clicks repetidos).
    final selectedDate = _dateForDayIndex(_selectedDayIndex);
    final weekIndex = _weeksSinceEpoch(selectedDate);
    final next = Map<int, int>.from(_slotVariations);
    final n = (next[itemIndex] ?? 0) + 1;
    next[itemIndex] = n;
    await _saveVariations(weekIndex, next);

    final pick = candidates[n % candidates.length];
    final grams = (pick['grams'] as num?)?.toDouble() ?? 0;
    final replaced = <String, dynamic>{
      'meal_type': mealType,
      'name': pick['name']?.toString() ?? '',
      'ingredients': const <String>[],
      'calories': (pick['kcal'] as num?)?.round() ?? 0,
      'protein': (pick['protein'] as num?)?.toDouble() ?? 0,
      'carbs': (pick['carbs'] as num?)?.toDouble() ?? 0,
      'fats': (pick['fat'] as num?)?.toDouble() ?? 0,
      'porcion_g': grams.round(),
    };

    if (!mounted) return;
    setState(() {
      _items[itemIndex] = replaced;
      _slotVariations = next;
      _checkedKeys.removeWhere((k) => k.startsWith('$itemIndex:'));
      _registeredLogIds.removeWhere((k, _) => k.startsWith('$itemIndex:'));
    });
    _reconcilePlanChecks();
  }

  /// Número de semana absoluto desde una referencia fija. Cambia cada lunes
  /// a medianoche LOCAL del usuario y sirve como semilla determinista para
  /// rotar el plan semanal. Antes usábamos date.toUtc() y la semana saltaba
  /// al UTC midnight (= 20:00 hora Chile del domingo), generando un plan
  /// "de la próxima semana" un día antes.
  static int _weeksSinceEpoch(DateTime date) {
    // Comparamos día calendario LOCAL contra el lunes 1 enero 2024 local.
    // Construir ambas como UTC desde los componentes locales evita el drift
    // por horarios de verano cuando calculamos .inDays.
    final localDay = DateTime.utc(date.year, date.month, date.day);
    final epoch = DateTime.utc(2024, 1, 1); // lunes 1 enero 2024
    final daysDiff = localDay.difference(epoch).inDays;
    return daysDiff ~/ 7;
  }

  Future<void> _loadDailyLogs(DateTime date) async {
    setState(() => _logsLoading = true);
    try {
      final results = await Future.wait([
        FoodService.instance.getDailyLog(date),
        FoodService.instance.getDailyTotals(date),
      ]);
      if (!mounted) return;
      setState(() {
        _dailyLogs = results[0] as List<FoodLog>;
        _dailyTotals = results[1] as Map<String, double>;
        _logsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _logsLoading = false);
    }
  }

  int get _totalCalories => _plan?['total_calories'] as int? ?? 2000;
  int get _consumedCalories => (_dailyTotals['kcal'] ?? 0).round();
  int get _consumedProtein => (_dailyTotals['protein'] ?? 0).round();
  int get _consumedCarbs => (_dailyTotals['carbs'] ?? 0).round();
  int get _consumedFat => (_dailyTotals['fat'] ?? 0).round();
  int get _targetProtein => _plan?['protein_grams'] as int? ?? 0;
  int get _targetCarbs => _plan?['carbs_grams'] as int? ?? 0;
  int get _targetFat => _plan?['fats_grams'] as int? ?? 0;

  /// Marca como registradas las unidades del plan (alimento o receta) que ya
  /// existen en food_logs del día. Empareja 1-a-1 por tipo + nombre para no
  /// checkear dos unidades con el mismo log.
  void _reconcilePlanChecks() {
    final checked = <String>{};
    final ids = <String, String>{};
    final consumed = <String>{}; // ids de logs ya emparejados

    void match(int i, int c, String? name, String mealType) {
      if (name == null) return;
      for (final log in _dailyLogs) {
        if (consumed.contains(log.id)) continue;
        if (log.mealType == mealType && log.foodName == name) {
          final key = '$i:$c';
          checked.add(key);
          ids[key] = log.id;
          consumed.add(log.id);
          break;
        }
      }
    }

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final mealType = item['meal_type'] as String?;
      if (mealType == null) continue;
      final comps =
          (item['components'] as List?)?.cast<Map<String, dynamic>>() ??
              const [];
      if (comps.isEmpty) {
        match(i, -1, item['name'] as String?, mealType);
      } else {
        for (var c = 0; c < comps.length; c++) {
          match(i, c, comps[c]['name'] as String?, mealType);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _checkedKeys
        ..clear()
        ..addAll(checked);
      _registeredLogIds = ids;
    });
  }

  /// Registra (o elimina) una unidad del plan (alimento simple o receta) en el
  /// registro real del día. key = "itemIndex:compIndex" (compIndex -1 = receta).
  Future<void> _togglePlanUnit(String key) async {
    if (_togglingKey.isNotEmpty) return; // evita doble tap mientras procesa
    final messenger = ScaffoldMessenger.of(context);
    final date = _dateForDayIndex(_selectedDayIndex);
    final parts = key.split(':');
    final itemIndex = int.parse(parts[0]);
    final compIndex = int.parse(parts[1]);
    if (itemIndex >= _items.length) return;
    final item = _items[itemIndex];
    final existingId = _registeredLogIds[key];

    setState(() => _togglingKey = key);
    try {
      if (existingId != null) {
        await FoodService.instance.deleteFoodLog(existingId);
      } else if (compIndex < 0) {
        final cals = item['calories'] as int? ?? 0;
        if (cals <= 0) {
          setState(() => _togglingKey = '');
          return;
        }
        await FoodService.instance.logPlanMeal(item, date: date);
      } else {
        final comps =
            (item['components'] as List).cast<Map<String, dynamic>>();
        await FoodService.instance.logPlanComponent(
          comps[compIndex],
          item['meal_type'] as String? ?? 'snack',
          date: date,
        );
      }
      await _loadDailyLogs(date);
      _reconcilePlanChecks();
      if (mounted && existingId == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Registrado en tu día'),
          backgroundColor: Color(0xFF00BFFF),
          duration: Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('No se pudo actualizar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _togglingKey = '');
    }
  }

  // Fija el contador exacto al tocar un vaso (permite subir o bajar).
  Future<void> _setWater(int count) async {
    final safe = count < 0 ? 0 : count;
    setState(() => _waterCount = safe);
    await WaterService.instance.setGlasses(safe);
  }

  Future<void> _resetWater() async {
    await WaterService.instance.resetToday();
    if (!mounted) return;
    setState(() => _waterCount = 0);
  }

  String _suggestedMealType() {
    final h = DateTime.now().hour;
    if (h < 10) return 'breakfast';
    if (h < 15) return 'lunch';
    if (h < 18) return 'snack';
    return 'dinner';
  }

  /// Flujo del escáner de comida (Plus/Premium): elegir foto → IA estima
  /// alimentos → el usuario edita porciones y confirma el registro.
  Future<void> _scanFood() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(PhosphorIconsFill.camera,
                  color: Color(0xFF00BFFF)),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(PhosphorIconsFill.image,
                  color: Color(0xFF00BFFF)),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // maxWidth evita cargar 12MP en memoria; la compresion final la hace
    // ImageCompressor.compressForVision (896/70) dentro del servicio.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
    );
    if (picked == null || !mounted) return;

    // Cinemática full-screen mientras la IA analiza la foto.
    final scanFuture = FoodScanService.instance.scan(File(picked.path));
    final animResult = await Navigator.of(context).push<FoodScanAnimationResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FoodScanAnimationScreen(
          imageFile: File(picked.path),
          scanFuture: scanFuture,
        ),
      ),
    );

    if (!mounted) return;
    final result = animResult?.success;
    final scanError = animResult?.error;

    if (scanError != null) {
      // NSFW o suspensión → diálogo rojo bloqueante. Resto → SnackBar.
      if (scanError.isNsfw || scanError.isSuspended) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(PhosphorIconsFill.warningOctagon,
                color: Color(0xFFE53935), size: 36),
            title: Text(
              scanError.isSuspended
                  ? 'Cuenta suspendida'
                  : 'Solo fotos de comida',
            ),
            content: Text(scanError.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(scanError.message)));
      }
      return;
    }
    if (result == null || result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result?.message ?? 'No detectamos comida en la foto.')),
      );
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScanResultsSheet(
        result: result,
        mealType: _suggestedMealType(),
        date: _dateForDayIndex(_selectedDayIndex),
      ),
    );
    if (saved == true) _loadDailyLogs(_dateForDayIndex(_selectedDayIndex));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // SmartAiLoading: skeleton primero, AiPlanLoading despues de 2.5s
      // si la edge function aun no responde (caso primera vez sin cache).
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: SafeArea(
          child: SmartAiLoading(
            kind: AiPlanKind.nutrition,
            skeleton: MealSkeletonList(count: 3),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isPaid) ...[
            FloatingActionButton.small(
              heroTag: 'scanFood',
              onPressed: _scanFood,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00BFFF),
              elevation: 2,
              child: const Icon(PhosphorIconsFill.camera),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'addFood',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FoodSearchScreen(initialMealType: _suggestedMealType()),
                ),
              );
              if (result == true) {
                _loadDailyLogs(_dateForDayIndex(_selectedDayIndex));
              }
            },
            backgroundColor: const Color(0xFF00BFFF),
            foregroundColor: Colors.white,
            icon: const Icon(PhosphorIconsFill.plusCircle),
            label: const Text(
              'Agregar alimento',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(
              'Alimentación',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
          ),

          // Selector de día
          SliverToBoxAdapter(child: _buildDaySelector()),

          if (_eatingDisorderRisk)
            SliverToBoxAdapter(child: _buildSafetyInfoBanner()),
            if (_isVegan) SliverToBoxAdapter(child: _buildVeganB12Banner()),

          // Tarjeta de calorías + macros
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _CalorieCard(
                consumed: _consumedCalories,
                target: _totalCalories,
                consumedProtein: _consumedProtein,
                consumedCarbs: _consumedCarbs,
                consumedFat: _consumedFat,
                targetProtein: _targetProtein,
                targetCarbs: _targetCarbs,
                targetFat: _targetFat,
              ),
            ),
          ),

          // Mi registro del día
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _MyLogSection(
                logs: _dailyLogs,
                loading: _logsLoading,
                mealLabel: _mealLabel,
                mealIcon: _mealIcon,
                mealOrder: _mealOrder,
                onDelete: (logId) async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await FoodService.instance.deleteFoodLog(logId);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('No se pudo eliminar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  if (mounted) {
                    await _loadDailyLogs(_dateForDayIndex(_selectedDayIndex));
                    _reconcilePlanChecks();
                  }
                },
              ),
            ),
          ),

          // Plan sugerido (colapsable)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _PlanSection(
                plan: _plan,
                items: _items,
                checkedKeys: _checkedKeys,
                mealOrder: _mealOrder,
                mealLabel: _mealLabel,
                hasLogs: _dailyLogs.isNotEmpty,
                onToggle: _togglePlanUnit,
                togglingKey: _togglingKey,
                onSwap: _swapMeal,
              ),
            ),
          ),

          // Hidratación
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _WaterSection(
                count: _waterCount,
                targetMl: _plan?['water_ml'] as int?,
                onSetGlasses: _setWater,
                onReset: _resetWater,
              ),
            ),
          ),

          // Disclaimer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Text(
                _disclaimerText,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // Warning B12: dieta vegana requiere suplementación obligatoria de B12
  // (NIH DRI / Academy of Nutrition and Dietetics 2016). No es opinión nuestra
  // — es estándar clínico documentado. No bloqueamos, solo informamos.
  Widget _buildVeganB12Banner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dieta vegana detectada. La vitamina B12 no se obtiene de '
                'fuentes 100% vegetales. Se recomienda suplementación '
                '(B12) y supervisión de un nutricionista.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange.shade900,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyInfoBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: Colors.blue.shade700,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Por tu bienestar ajustamos tu plan con un enfoque seguro (sin '
                'déficits agresivos). Te recomendamos acompañarte de un '
                'profesional de la salud —nutricionista o médico— para una guía '
                'personalizada.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final isSelected = i == _selectedDayIndex;
          final isToday = i == todayIndex;

          return GestureDetector(
            onTap: () {
              if (_selectedDayIndex == i) return;
              setState(() => _selectedDayIndex = i);
              _refreshSelectedDay();
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00BFFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(color: const Color(0xFF00BFFF), width: 1.5)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _days[i],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? const Color(0xFF00BFFF)
                              : Colors.black54,
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
}

// ─── Calorie Arc Card ────────────────────────────────────────────────────────

class _CalorieCard extends StatelessWidget {
  final int consumed;
  final int target;
  final int consumedProtein;
  final int consumedCarbs;
  final int consumedFat;
  final int targetProtein;
  final int targetCarbs;
  final int targetFat;

  const _CalorieCard({
    required this.consumed,
    required this.target,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final remaining = target - consumed;
    final over = remaining < 0;
    const overColor = Color(0xFFE67E22);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(180, 150),
                  painter: _CalorieArcPainter(progress: progress, over: over),
                ),
                // Texto anclado arriba para que la separación con el arco
                // sea determinista en cualquier dispositivo (no se solapa).
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 62),
                      Text(
                        '$consumed',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'de $target kcal',
                      style: const TextStyle(fontSize: 13, color: Colors.black45),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      over
                          ? '+${-remaining} kcal sobre la meta'
                          : 'te faltan $remaining kcal',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: over ? overColor : const Color(0xFF00BFFF),
                      ),
                    ),
                  ],
                ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroBar(
                label: 'Proteína',
                consumed: consumedProtein,
                target: targetProtein,
                color: const Color(0xFF5B8DEF),
              ),
              const SizedBox(width: 12),
              _MacroBar(
                label: 'Carbos',
                consumed: consumedCarbs,
                target: targetCarbs,
                color: const Color(0xFFF5A623),
              ),
              const SizedBox(width: 12),
              _MacroBar(
                label: 'Grasas',
                consumed: consumedFat,
                target: targetFat,
                color: const Color(0xFF7ED321),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalorieArcPainter extends CustomPainter {
  final double progress;
  final bool over;
  const _CalorieArcPainter({required this.progress, this.over = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final radius = size.width * 0.44;
    final strokeW = 12.0;

    final trackPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = over ? const Color(0xFFE67E22) : const Color(0xFF00BFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final startAngle = pi;
    final sweepAngle = pi;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CalorieArcPainter old) =>
      old.progress != progress || old.over != over;
}

class _MacroBar extends StatelessWidget {
  final String label;
  final int consumed;
  final int target;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.consumed,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final remaining = target - consumed;
    final over = remaining < 0;
    final met = remaining <= 0;
    // Verde al cumplir; naranja si se pasa bastante (>10%).
    const overColor = Color(0xFFE67E22);
    final barColor = (over && consumed > target * 1.10) ? overColor : color;
    final String statusText;
    if (over) {
      statusText = '+${(-remaining)}g';
    } else if (met) {
      statusText = '✓ meta';
    } else {
      statusText = 'faltan ${remaining}g';
    }
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$consumed / ${target}g',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: barColor,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              color: over
                  ? overColor
                  : (met ? const Color(0xFF4CAF50) : Colors.black38),
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── My Log Section ──────────────────────────────────────────────────────────

class _MyLogSection extends StatelessWidget {
  final List<FoodLog> logs;
  final bool loading;
  final Map<String, String> mealLabel;
  final Map<String, IconData> mealIcon;
  final List<String> mealOrder;
  final Future<void> Function(String logId) onDelete;

  const _MyLogSection({
    required this.logs,
    required this.loading,
    required this.mealLabel,
    required this.mealIcon,
    required this.mealOrder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Mi registro del día',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (logs.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFFF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${logs.length} alimento${logs.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00BFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (logs.isEmpty)
            _EmptyLog()
          else
            _LogList(
              logs: logs,
              mealLabel: mealLabel,
              mealIcon: mealIcon,
              mealOrder: mealOrder,
              onDelete: onDelete,
            ),
        ],
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(PhosphorIconsRegular.bowlFood, size: 40, color: Colors.black12),
          const SizedBox(height: 10),
          const Text(
            'Sin registros aún',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca "Agregar alimento" para registrar lo que comiste',
            style: TextStyle(fontSize: 12, color: Colors.black38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<FoodLog> logs;
  final Map<String, String> mealLabel;
  final Map<String, IconData> mealIcon;
  final List<String> mealOrder;
  final Future<void> Function(String) onDelete;

  const _LogList({
    required this.logs,
    required this.mealLabel,
    required this.mealIcon,
    required this.mealOrder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<FoodLog>>{};
    for (final log in logs) {
      grouped.putIfAbsent(log.mealType, () => []).add(log);
    }

    final orderedTypes = [
      ...mealOrder.where(grouped.containsKey),
      ...grouped.keys.where((k) => !mealOrder.contains(k)),
    ];

    return Column(
      children: orderedTypes.map((type) {
        final group = grouped[type]!;
        final label = mealLabel[type] ?? type;
        final icon = mealIcon[type] ?? PhosphorIconsRegular.bowlFood;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Colors.black45),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            ...group.map((log) => _LogItem(log: log, onDelete: onDelete)),
          ],
        );
      }).toList(),
    );
  }
}

class _LogItem extends StatelessWidget {
  final FoodLog log;
  final Future<void> Function(String) onDelete;

  const _LogItem({required this.log, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D4D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(PhosphorIconsRegular.trash, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onDelete(log.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            FoodIcon(foodName: log.foodName, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.foodName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.portionLabel,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (log.kcalTotal != null)
                  Text(
                    '${log.kcalTotal!.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (log.proteinTotal != null)
                      _MiniChip(
                        label: 'P ${log.proteinTotal!.toStringAsFixed(0)}g',
                        color: const Color(0xFF5B8DEF),
                      ),
                    if (log.carbsTotal != null)
                      _MiniChip(
                        label: 'C ${log.carbsTotal!.toStringAsFixed(0)}g',
                        color: const Color(0xFFF5A623),
                      ),
                    if (log.fatTotal != null)
                      _MiniChip(
                        label: 'G ${log.fatTotal!.toStringAsFixed(0)}g',
                        color: const Color(0xFF7ED321),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Plan Section ────────────────────────────────────────────────────────────

class _PlanSection extends StatelessWidget {
  final Map<String, dynamic>? plan;
  final List<Map<String, dynamic>> items;
  final Set<String> checkedKeys;
  final List<String> mealOrder;
  final Map<String, String> mealLabel;
  final bool hasLogs;
  final void Function(String) onToggle;
  final String togglingKey;
  final void Function(int) onSwap;

  const _PlanSection({
    required this.plan,
    required this.items,
    required this.checkedKeys,
    required this.mealOrder,
    required this.mealLabel,
    required this.hasLogs,
    required this.onToggle,
    required this.togglingKey,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    if (plan == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !hasLogs,
          leading: const Icon(
            PhosphorIconsRegular.sparkle,
            color: Color(0xFF00BFFF),
            size: 20,
          ),
          title: const Text(
            'Plan sugerido por IA',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          subtitle: const Text(
            'Toca un alimento para registrarlo · "Cambiar" para otra opción',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NutritionSummaryCard(plan: plan!),
                  const SizedBox(height: 12),
                  ...mealOrder.map((type) {
                    final group =
                        items.where((m) => m['meal_type'] == type).toList();
                    if (group.isEmpty) return const SizedBox.shrink();
                    return _MealSection(
                      title: mealLabel[type] ?? type,
                      items: group,
                      allItems: items,
                      checkedKeys: checkedKeys,
                      onToggle: onToggle,
                      togglingKey: togglingKey,
                      onSwap: onSwap,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Water Section ───────────────────────────────────────────────────────────

class _WaterSection extends StatelessWidget {
  final int count;
  // Meta diaria de hidratación en ML calculada por NutritionCalculator
  // (ACSM 35 ml/kg + 500 ml por sesión de entreno repartida en la semana).
  // Convertido a vasos asumiendo 250 ml por vaso, mínimo 6, máximo 14.
  final int? targetMl;
  final ValueChanged<int> onSetGlasses;
  final VoidCallback onReset;

  static const Color _blue = Color(0xFF00BFFF);

  const _WaterSection({
    required this.count,
    required this.targetMl,
    required this.onSetGlasses,
    required this.onReset,
  });

  int get _targetGlasses {
    final ml = targetMl ?? 2000;
    return (ml / 250).round().clamp(6, 14);
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetGlasses;
    final done = count.clamp(0, target);
    final progress = target == 0 ? 0.0 : done / target;
    final ml = done * 250;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsRegular.drop, color: _blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Hidratación',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${(ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1)} L',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$done / $target vasos',
                style: const TextStyle(
                  fontSize: 13,
                  color: _blue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso global que se llena con animación.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: const Color(0xFFEAF7FE),
                valueColor: const AlwaysStoppedAnimation(_blue),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Vasos en Wrap: si no caben en la fila, bajan a la siguiente.
          Wrap(
            spacing: 10,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: List.generate(target, (i) {
              final filled = i < done;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Tocar el último vaso lleno lo vacía; si no, llena hasta ahí.
                  onSetGlasses(i + 1 == done ? i : i + 1);
                },
                behavior: HitTestBehavior.opaque,
                child: _WaterGlass(filled: filled),
              );
            }),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                onReset();
              },
              icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise,
                  size: 14, color: Colors.black38),
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                foregroundColor: Colors.black38,
              ),
              label: const Text(
                'Reiniciar contador',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un vaso individual que se llena con una ola animada al marcarse.
class _WaterGlass extends StatelessWidget {
  final bool filled;
  const _WaterGlass({required this.filled});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: filled ? 1 : 0),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, fill, _) => CustomPaint(
        size: const Size(30, 44),
        painter: _GlassPainter(fill: fill),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final double fill; // 0..1 nivel de agua
  const _GlassPainter({required this.fill});

  static const Color _blue = Color(0xFF00BFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Copa ligeramente cónica: más ancha arriba que abajo.
    const topInset = 1.0;
    final botInset = w * 0.16;
    final glass = Path()
      ..moveTo(topInset, 2)
      ..lineTo(w - topInset, 2)
      ..lineTo(w - botInset, h - 2)
      ..lineTo(botInset, h - 2)
      ..close();

    // Fondo del vaso.
    canvas.drawPath(
      glass,
      Paint()..color = const Color(0xFFF3FAFE),
    );

    // Agua recortada al interior del vaso.
    if (fill > 0.01) {
      canvas.save();
      canvas.clipPath(glass);
      final level = (h - 2) - fill * (h - 4);
      final amp = 1.6; // amplitud de la ola
      final wave = Path()..moveTo(0, level);
      for (double x = 0; x <= w; x += 1) {
        final y = level + amp * sin((x / w * 2 * pi) + fill * 6);
        wave.lineTo(x, y);
      }
      wave
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        wave,
        Paint()..color = _blue.withValues(alpha: 0.85),
      );
      // Brillo superior del agua.
      canvas.drawPath(
        wave,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..blendMode = BlendMode.softLight,
      );
      canvas.restore();
    }

    // Contorno del vaso.
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = fill > 0.01 ? _blue : const Color(0xFFD7E6EE),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) => old.fill != fill;
}

// ─── Nutrition Summary Card (plan IA) ────────────────────────────────────────

class _NutritionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  const _NutritionSummaryCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final explanation = plan['explanation_text'] as String? ?? '';
    final maintenance = plan['maintenance_calories'] as int? ?? 0;
    final recommended = plan['total_calories'] as int? ?? 0;
    final protein = plan['protein_grams'] as int? ?? 0;
    final carbs = plan['carbs_grams'] as int? ?? 0;
    final fats = plan['fats_grams'] as int? ?? 0;
    final interpretation = plan['goal_interpretation'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (interpretation.isNotEmpty) ...[
            Text(
              interpretation,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (explanation.isNotEmpty) ...[
            Text(
              explanation,
              style: const TextStyle(
                  fontSize: 12, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              _CalStat(
                label: 'Mantenimiento',
                value: '$maintenance kcal',
                icon: PhosphorIconsRegular.scales,
              ),
              const SizedBox(width: 12),
              _CalStat(
                label: 'Objetivo',
                value: '$recommended kcal',
                icon: PhosphorIconsRegular.flag,
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroChipPlan(
                  label: 'Proteína', grams: protein, color: const Color(0xFF5B8DEF)),
              _MacroChipPlan(
                  label: 'Carbos', grams: carbs, color: const Color(0xFFF5A623)),
              _MacroChipPlan(
                  label: 'Grasas', grams: fats, color: const Color(0xFF7ED321)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  const _CalStat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: highlight ? AppColors.primary : Colors.black54),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: highlight ? AppColors.primary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChipPlan extends StatelessWidget {
  final String label;
  final int grams;
  final Color color;
  const _MacroChipPlan(
      {required this.label, required this.grams, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${grams}g',
          style:
              TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}

// ─── Meal Section (plan IA items) ────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> allItems;
  final Set<String> checkedKeys;
  final void Function(String) onToggle;
  final String togglingKey;
  final void Function(int) onSwap;

  const _MealSection({
    required this.title,
    required this.items,
    required this.allItems,
    required this.checkedKeys,
    required this.onToggle,
    required this.togglingKey,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        ...items.expand((item) => _itemWidgets(item)),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _itemWidgets(Map<String, dynamic> item) {
    final itemIndex = allItems.indexOf(item);
    final isSupplement = item['is_supplement'] == true;
    final components =
        (item['components'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    // Receta sola (sin componentes) → una fila checkeable.
    if (components.isEmpty) {
      final ingredients =
          (item['ingredients'] as List?)?.cast<String>() ?? const [];
      return [
        _unitTile(
          unitKey: '$itemIndex:-1',
          name: item['name'] as String? ?? 'Comida',
          detail: ingredients.isNotEmpty ? ingredients.join(' · ') : null,
          kcal: item['calories'] as int? ?? 0,
          bold: true,
          onSwap: isSupplement ? null : () => onSwap(itemIndex),
        ),
      ];
    }

    // Combo / suplemento → encabezado + una fila por alimento.
    return [
      _blockHeader(
        item['name'] as String? ?? '',
        isSupplement: isSupplement,
        onSwap: isSupplement ? null : () => onSwap(itemIndex),
      ),
      ...components.asMap().entries.map((e) {
        final comp = e.value;
        final units = comp['units'] as int? ?? 1;
        final g = comp['grams'];
        final parts = <String>[];
        if (units > 1) parts.add('×$units');
        if (g != null) parts.add('${(g as num).toStringAsFixed(0)}g');
        return _unitTile(
          unitKey: '$itemIndex:${e.key}',
          name: comp['name'] as String? ?? '',
          detail: parts.join(' · '),
          kcal: (comp['calories'] as num?)?.round() ?? 0,
          bold: false,
        );
      }),
      const SizedBox(height: 4),
    ];
  }

  Widget _blockHeader(String name,
      {required bool isSupplement, VoidCallback? onSwap}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: isSupplement
                ? Row(
                    children: const [
                      Icon(PhosphorIconsRegular.sparkle,
                          size: 14, color: Color(0xFF00BFFF)),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Para completar tus macros',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00BFFF)),
                        ),
                      ),
                    ],
                  )
                : Text(
                    name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (onSwap != null) _swapButton(onSwap),
        ],
      ),
    );
  }

  Widget _swapButton(VoidCallback onSwap, {bool compact = false}) {
    if (compact) {
      return InkWell(
        onTap: onSwap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00BFFF).withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.swap_horiz,
              size: 18, color: Color(0xFF00BFFF)),
        ),
      );
    }
    return InkWell(
      onTap: onSwap,
      borderRadius: BorderRadius.circular(8),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 16, color: Color(0xFF00BFFF)),
            SizedBox(width: 3),
            Text('Cambiar',
                style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00BFFF),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _unitTile({
    required String unitKey,
    required String name,
    String? detail,
    required int kcal,
    required bool bold,
    VoidCallback? onSwap,
  }) {
    final isChecked = checkedKeys.contains(unitKey);
    final isToggling = togglingKey == unitKey;
    return GestureDetector(
      onTap: () => onToggle(unitKey),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isChecked ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border:
              isChecked ? Border.all(color: Colors.green.shade300) : null,
        ),
        child: Row(
          children: [
            isToggling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isChecked
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    color: isChecked ? Colors.green : Colors.grey,
                    size: 22,
                  ),
            const SizedBox(width: 10),
            FoodIcon(foodName: name, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                      fontSize: bold ? 14 : 13,
                      height: 1.15,
                      decoration:
                          isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked ? Colors.black45 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail != null && detail.isNotEmpty
                        ? '$kcal kcal · $detail'
                        : '$kcal kcal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (onSwap != null) ...[
              const SizedBox(width: 6),
              _swapButton(onSwap, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Hoja de resultados del escáner de comida ────────────────────────────────

class _ScanResultsSheet extends StatefulWidget {
  final ScanResult result;
  final String mealType;
  final DateTime date;

  const _ScanResultsSheet({
    required this.result,
    required this.mealType,
    required this.date,
  });

  @override
  State<_ScanResultsSheet> createState() => _ScanResultsSheetState();
}

class _ScanResultsSheetState extends State<_ScanResultsSheet> {
  late List<ScannedFood> _items;
  late List<double> _grams;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.result.items);
    _grams = _items.map((e) => e.grams).toList();
  }

  double get _totalKcal {
    var t = 0.0;
    for (var i = 0; i < _items.length; i++) {
      final f = _items[i].grams > 0 ? _grams[i] / _items[i].grams : 1.0;
      t += _items[i].kcal * f;
    }
    return t;
  }

  Future<void> _confirm() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      for (var i = 0; i < _items.length; i++) {
        await FoodService.instance.logPlanComponent(
          _items[i].toLogComponent(_grams[i]),
          widget.mealType,
          date: widget.date,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar. Intenta de nuevo.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final warnings = widget.result.allergyWarnings;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Icon(PhosphorIconsFill.sparkle, color: Color(0xFF00BFFF)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alimentos detectados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Valores estimados por IA. Ajusta la porción antes de guardar.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
            if (warnings.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsFill.warning,
                        color: Color(0xFFE67E22), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ojo: ${warnings.join(", ")} podría chocar con tus alergias.',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFB35900)),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, i) => _itemTile(i),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total: ${_totalKcal.round()} kcal',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _items.isEmpty || _saving ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('Registrar (${_items.length})'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(int i) {
    final item = _items[i];
    final f = item.grams > 0 ? _grams[i] / item.grams : 1.0;
    final kcal = (item.kcal * f).round();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '$kcal kcal',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 72,
          child: TextFormField(
            initialValue: _grams[i].round().toString(),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              suffixText: 'g',
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              final g = double.tryParse(v) ?? 0;
              setState(() => _grams[i] = g > 0 ? g : 0);
            },
          ),
        ),
        IconButton(
          icon: const Icon(PhosphorIconsRegular.x, size: 18),
          color: Colors.black38,
          onPressed: () => setState(() {
            _items.removeAt(i);
            _grams.removeAt(i);
          }),
        ),
      ],
    );
  }
}
