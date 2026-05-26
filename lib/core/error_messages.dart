String humanizeError(Object e) {
  final raw = e.toString().replaceFirst('Exception: ', '').trim();
  final lower = raw.toLowerCase();

  if (lower.contains('duplicate key') && lower.contains('username')) {
    return 'Ese nombre de usuario ya existe.';
  }
  if (lower.contains('duplicate key') &&
      (lower.contains('email') || lower.contains('users_email'))) {
    return 'Ese correo ya está registrado.';
  }
  if (lower.contains('user already registered')) {
    return 'Ya existe una cuenta con ese correo.';
  }
  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid login')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (lower.contains('email not confirmed')) {
    return 'Confirma tu correo antes de iniciar sesión.';
  }
  if (lower.contains('password should be') || lower.contains('weak password')) {
    return 'La contraseña es muy débil. Usa al menos 8 caracteres.';
  }
  if (lower.contains('rate limit') || lower.contains('too many')) {
    return 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network')) {
    return 'Sin conexión a internet. Inténtalo de nuevo.';
  }
  if (lower.contains('timeout') || lower.contains('timed out')) {
    return 'La conexión tardó demasiado. Inténtalo de nuevo.';
  }

  if (raw.isNotEmpty && raw.length < 120 && !raw.contains('Exception')) {
    return raw;
  }
  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}
