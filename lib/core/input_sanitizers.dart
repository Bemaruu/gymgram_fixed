// Sanitización mínima de inputs de texto del onboarding y la rutina importada.
// Reglas: sin URLs, sin tags HTML, sin saltos de línea, trim, largo acotado.

class InputSanitizers {
  InputSanitizers._();

  static final _urlRegex = RegExp(
    r'(https?:\/\/|www\.|[a-z0-9-]+\.(com|net|org|io|co|app|me|xyz|tk))',
    caseSensitive: false,
  );
  static final _tagRegex = RegExp(r'<[^>]*>');
  static final _whitespaceRegex = RegExp(r'\s+');

  static bool looksLikeUrl(String value) => _urlRegex.hasMatch(value);

  /// Limpia un texto corto: quita tags, URLs, saltos de línea, colapsa espacios,
  /// y recorta a [maxLen]. Devuelve cadena vacía si tras sanitizar queda vacía.
  static String cleanText(String raw, {int maxLen = 160}) {
    var v = raw.trim();
    if (v.isEmpty) return '';
    v = v.replaceAll(_tagRegex, '');
    v = v.replaceAll(_urlRegex, '');
    v = v.replaceAll(_whitespaceRegex, ' ').trim();
    if (v.length > maxLen) v = v.substring(0, maxLen).trim();
    return v;
  }

  /// Valida un nombre de usuario: 3-20 chars, sólo letras/números/_/.
  static String? validateUsername(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 3 || s.length > 20) return 'Entre 3 y 20 caracteres';
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(s)) {
      return 'Sólo letras, números, "." y "_"';
    }
    return null;
  }

  /// Valida un nombre completo: 2-50 chars, sin URLs.
  static String? validateFullName(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 2 || s.length > 50) return 'Entre 2 y 50 caracteres';
    if (looksLikeUrl(s)) return 'No se permiten enlaces';
    return null;
  }

  static String? validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty || s.length > 254) return 'Correo inválido';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s);
    return ok ? null : 'Correo inválido';
  }

  static String? validatePassword(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Mínimo 8 caracteres';
    final hasLower = RegExp(r'[a-z]').hasMatch(s);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(s);
    final hasDigit = RegExp(r'\d').hasMatch(s);
    final hasSymbol =
        RegExp(r'''[!@#$%^&*()_+\-=\[\]{};:'"|<>?,./`~]''').hasMatch(s);
    if (!hasLower || !hasUpper || !hasDigit || !hasSymbol) {
      return 'Debe incluir mayúscula, minúscula, número y símbolo';
    }
    return null;
  }

  /// Para campos opcionales de texto corto (lesiones específicas, alimentos
  /// que evita). Devuelve null si está vacío o queda vacío tras sanitizar.
  static String? cleanOptional(String? raw, {int maxLen = 200}) {
    if (raw == null) return null;
    final s = cleanText(raw, maxLen: maxLen);
    return s.isEmpty ? null : s;
  }

  // ── Rutina importada ──────────────────────────────────────────────────
  static String? validateExerciseName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Obligatorio';
    if (s.length > 60) return 'Máximo 60 caracteres';
    if (looksLikeUrl(s)) return 'No se permiten enlaces';
    return null;
  }

  static String? validateExerciseNotes(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (s.length > 160) return 'Máximo 160 caracteres';
    if (looksLikeUrl(s)) return 'No se permiten enlaces';
    return null;
  }

  static String? validateReps(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Obligatorio';
    if (s.length > 30) return 'Máximo 30 caracteres';
    if (!RegExp(r'^[\d\-x×\s]+$', caseSensitive: false).hasMatch(s)) {
      return 'Sólo números, "-" o "x"';
    }
    return null;
  }
}
