/// Catálogo único del orden de pantallas del onboarding y helpers para
/// calcular progreso y siguiente ruta de forma dinámica.
///
/// Algunas pantallas se saltan según las respuestas previas:
/// - `signup_equipment` se omite si el lugar elegido es GYM (default `full_gym`).
/// - `signup_experience_path` se omite si el nivel es `beginner` (default `create_ai_routine`).
/// - `signup_import_routine` se muestra sólo si el path es `analyze_existing_routine`.
class OnboardingFlow {
  OnboardingFlow._();

  /// Orden lineal completo. `signup_step_1` (cuenta) queda fuera porque
  /// no usa barra de progreso.
  static const List<String> _routes = [
    '/signup_consent',
    '/signup_gender_birthdate',
    '/signup_body_metrics',
    '/signup_place',
    '/signup_equipment',
    '/signup_experience_level',
    '/signup_experience_path',
    '/signup_import_routine',
    '/signup_step_5',
    '/signup_split',
    '/signup_days_duration',
    '/signup_injuries',
    '/signup_diet_meals',
    '/signup_allergies',
    '/signup_cooking_time',
    '/signup_disliked_foods',
    '/signup_step_13',
  ];

  static List<String> _activeFor(Map<String, dynamic> userData) {
    final place = userData['trainingPlace'] as String?;
    final level = userData['trainingLevel'] as String?;
    final path = userData['experiencePath'] as String?;
    return _routes.where((r) {
      if (r == '/signup_equipment' && place == 'GYM') return false;
      if (r == '/signup_experience_path' && level == 'beginner') return false;
      if (r == '/signup_import_routine' && path != 'analyze_existing_routine') {
        return false;
      }
      return true;
    }).toList();
  }

  /// Devuelve `(step, total)` para la pantalla actual.
  /// Si la pantalla no está activa para los datos actuales, devuelve el total.
  static ({int step, int total}) progressFor(
    String route,
    Map<String, dynamic> userData,
  ) {
    final active = _activeFor(userData);
    final idx = active.indexOf(route);
    if (idx < 0) {
      return (step: active.length, total: active.length);
    }
    return (step: idx + 1, total: active.length);
  }

  /// Siguiente ruta activa, o `null` si esta es la última.
  static String? nextRoute(
    String currentRoute,
    Map<String, dynamic> userData,
  ) {
    final active = _activeFor(userData);
    final idx = active.indexOf(currentRoute);
    if (idx < 0 || idx + 1 >= active.length) return null;
    return active[idx + 1];
  }
}
