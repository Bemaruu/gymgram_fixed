// Modelo tipado del onboarding. Reemplaza el Map<String, dynamic> que circulaba
// por Navigator.arguments. Los pasos siguen pasando un Map por compatibilidad
// con el flujo actual (Navigator.pushNamed), pero ahora hay un único contrato
// de claves que también sirve para serializar en Supabase al final.

class UserRegisterModel {
  // ── Auth + identidad ─────────────────────────────────────────────────
  String? fullName;
  String? email;
  String? username;
  String? password;
  String? birthDate; // ISO-8601

  // ── Consentimiento ───────────────────────────────────────────────────
  DateTime? privacyConsentAt;
  DateTime? termsConsentAt;

  // ── Físicos ──────────────────────────────────────────────────────────
  String? gender; // MALE | FEMALE | OTHER | PREFER_NOT_TO_SAY
  double? weight; // kg
  double? height; // cm
  double? targetWeight; // kg

  // ── Objetivo y entrenamiento ─────────────────────────────────────────
  String? fitnessGoal; // LOSE_WEIGHT | GAIN_MUSCLE | RECOMPOSITION | MAINTAIN | IMPROVE_ENDURANCE | TONE_BODY
  String? trainingLocation; // HOME | GYM | OUTDOOR | HYBRID
  List<String> equipmentAvailable = [];
  String? trainingLevel; // beginner | intermediate_lt_1y | intermediate_1y_3y | advanced_gt_3y
  String? experiencePath; // create_ai_routine | analyze_existing_routine
  List<int> availableDays = []; // 0..6
  int? sessionDurationMinutes;
  String? trainingTime; // morning_early | morning_late | afternoon | evening | variable
  String? routineSplitPreference;
  List<String> injuries = []; // catálogo cerrado
  String? injuryNotes; // texto libre opcional sanitizado

  // ── Alimentación ─────────────────────────────────────────────────────
  List<String> foodPreferences = [];
  List<String> dietaryRestrictions = [];
  String? cookingTimePreference;
  List<String> dislikedFoods = [];
  String? mealsPerDayRaw; // '2'|'3'|...|'intermittent_fasting'|'flexible'

  // ── Coaching ─────────────────────────────────────────────────────────
  String? coachingStyle; // gentle | balanced | strict | no_notifications
  bool notificationsEnabled = false;

  UserRegisterModel();

  /// Hidrata desde el `Map<String, dynamic>` que circula por Navigator.arguments.
  /// Acepta también claves legacy en español por compatibilidad puente.
  factory UserRegisterModel.fromMap(Map<String, dynamic> m) {
    final r = UserRegisterModel();
    r.fullName = _s(m, ['fullName', 'nombreCompleto', 'name']);
    r.email = _s(m, ['email', 'correo']);
    r.username = _s(m, ['username', 'userName', 'nombreUsuario']);
    r.password = _s(m, ['password', 'contraseña']);
    r.birthDate = _s(m, ['birthDate', 'fechaNacimiento']);

    r.privacyConsentAt = _dt(m['privacyConsentAt']);
    r.termsConsentAt = _dt(m['termsConsentAt']);

    r.gender = _s(m, ['gender', 'genero']);
    r.weight = _d(m, ['weight', 'pesoActual', 'weightKg', 'currentWeight']);
    r.height = _d(m, ['height', 'estatura', 'heightCm']);
    r.targetWeight = _d(m, ['targetWeight', 'pesoObjetivo']);

    r.fitnessGoal = _s(m, ['fitnessGoal', 'goal', 'objetivo']);
    r.trainingLocation =
        _s(m, ['trainingLocation', 'workoutPlace', 'lugarEntrenamiento', 'trainingPlace']);
    r.equipmentAvailable = _ls(m['equipmentAvailable']);
    r.trainingLevel = _s(m, ['trainingLevel', 'experienceLevel', 'nivelExperiencia']);
    r.experiencePath = _s(m, ['experiencePath']);
    r.availableDays = _li(m['availableDays'] ?? m['trainingDays']);
    r.sessionDurationMinutes = _i(m, ['sessionDurationMinutes']);
    r.trainingTime =
        _s(m, ['trainingTime', 'timeAvailability', 'availability', 'tiempoEntrenar']);
    r.routineSplitPreference = _s(m, ['routineSplitPreference']);
    r.injuries = _ls(m['injuries']);
    r.injuryNotes = _s(m, ['injuryNotes']);

    r.foodPreferences = _ls(m['foodPreferences']);
    r.dietaryRestrictions = _ls(m['dietaryRestrictions'] ?? m['allergies']);
    r.cookingTimePreference = _s(m, ['cookingTimePreference']);
    r.dislikedFoods = _ls(m['dislikedFoods']);
    r.mealsPerDayRaw = _s(m, ['mealsPerDay']);

    r.coachingStyle = _s(m, ['coachingStyle', 'motivationalNotifications']);
    r.notificationsEnabled = (m['notificationsEnabled'] as bool?) ?? false;
    return r;
  }

  /// Serializa a Map para volver a viajar por Navigator.arguments.
  Map<String, dynamic> toMap() => {
        if (fullName != null) 'fullName': fullName,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        if (password != null) 'password': password,
        if (birthDate != null) 'birthDate': birthDate,
        if (privacyConsentAt != null) 'privacyConsentAt': privacyConsentAt!.toIso8601String(),
        if (termsConsentAt != null) 'termsConsentAt': termsConsentAt!.toIso8601String(),
        if (gender != null) 'gender': gender,
        if (weight != null) 'weight': weight,
        if (height != null) 'height': height,
        if (targetWeight != null) 'targetWeight': targetWeight,
        if (fitnessGoal != null) 'fitnessGoal': fitnessGoal,
        if (trainingLocation != null) 'trainingLocation': trainingLocation,
        'equipmentAvailable': equipmentAvailable,
        if (trainingLevel != null) 'trainingLevel': trainingLevel,
        if (experiencePath != null) 'experiencePath': experiencePath,
        'availableDays': availableDays,
        if (sessionDurationMinutes != null) 'sessionDurationMinutes': sessionDurationMinutes,
        if (trainingTime != null) 'trainingTime': trainingTime,
        if (routineSplitPreference != null) 'routineSplitPreference': routineSplitPreference,
        'injuries': injuries,
        if (injuryNotes != null) 'injuryNotes': injuryNotes,
        'foodPreferences': foodPreferences,
        'dietaryRestrictions': dietaryRestrictions,
        if (cookingTimePreference != null) 'cookingTimePreference': cookingTimePreference,
        'dislikedFoods': dislikedFoods,
        if (mealsPerDayRaw != null) 'mealsPerDay': mealsPerDayRaw,
        if (coachingStyle != null) 'coachingStyle': coachingStyle,
        'notificationsEnabled': notificationsEnabled,
      };

  /// Si el usuario está en path "analizar rutina existente" el siguiente paso
  /// es importar; si no, sigue el flujo normal.
  bool get shouldImportExistingRoutine =>
      experiencePath == 'analyze_existing_routine';

  bool get isBeginner => trainingLevel == 'beginner';

  // ── helpers privados ─────────────────────────────────────────────────
  static String? _s(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return null;
  }

  static double? _d(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is num) return v.toDouble();
      final parsed = double.tryParse(v.toString().replaceAll(',', '.').trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static int? _i(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      if (v is int) return v;
      final parsed = int.tryParse(v.toString().trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static List<String> _ls(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    if (v is String) {
      return v
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  static List<int> _li(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .where((n) => n >= 0 && n <= 6)
          .toList();
    }
    if (v is String) {
      return v
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .where((n) => n >= 0 && n <= 6)
          .toList();
    }
    return [];
  }

  static DateTime? _dt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
