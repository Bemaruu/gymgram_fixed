import 'package:supabase_flutter/supabase_flutter.dart';

// Extension para compatibilidad con código que usa .uid (Firebase style)
extension UserCompatExt on User {
  String get uid => id;
}

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      // Supabase no crea sesión automáticamente si la confirmación de email
      // está activada. En ese caso hacemos signIn para obtener la sesión.
      if (response.session == null && response.user != null) {
        try {
          return await _client.auth.signInWithPassword(
            email: email.trim(),
            password: password.trim(),
          );
        } on AuthException catch (e) {
          final lower = e.message.toLowerCase();
          if (lower.contains('rate limit') || lower.contains('too many')) {
            throw Exception(
              'Cuenta creada. Espera unos minutos y usa "Iniciar sesión".',
            );
          }
          throw Exception(_mapAuthError(e.message));
        }
      }

      return response;
    } on AuthException catch (e) {
      throw Exception(_mapAuthError(e.message));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Ocurrió un error inesperado al registrar el usuario.');
    }
  }

  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on AuthException catch (e) {
      throw Exception(_mapAuthError(e.message));
    } catch (_) {
      throw Exception('Ocurrió un error inesperado al iniciar sesión.');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      throw Exception('No se pudo cerrar la sesión.');
    }
  }

  Future<void> deleteAccount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('No hay sesión activa.');

    try {
      await _client.functions.invoke('delete-user');
    } on AuthException catch (e) {
      throw Exception(_mapAuthError(e.message));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('No se pudo eliminar la cuenta.');
    } finally {
      await _client.auth.signOut();
    }
  }

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'Ese correo ya está en uso.';
    }
    if (lower.contains('invalid email')) return 'El correo no es válido.';
    if (lower.contains('should be at least') || lower.contains('weak password') ||
        lower.contains('password is too') || lower.contains('too short')) {
      return 'La contraseña es demasiado débil.';
    }
    if (lower.contains('invalid login') || lower.contains('invalid credentials') ||
        lower.contains('email not confirmed')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (lower.contains('user already registered') || lower.contains('email already')) {
      return 'Ese correo ya tiene una cuenta. Usa "Iniciar sesión".';
    }
    if (lower.contains('network')) return 'Error de red. Revisa tu conexión.';
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Demasiados intentos. Intenta más tarde.';
    }
    return 'Error de autenticación: $message';
  }
}
