import 'package:flutter/material.dart';
import 'account_settings_screen.dart';

/// Alias historico. La pantalla real es `AccountSettingsScreen`.
/// Mantenemos el constructor antiguo para no romper imports en `routes.dart`
/// ni en `perfil_screen.dart`.
class EditProfileScreen extends StatelessWidget {
  final String currentUsername;
  final String currentBio;

  const EditProfileScreen({
    super.key,
    required this.currentUsername,
    required this.currentBio,
  });

  @override
  Widget build(BuildContext context) {
    return AccountSettingsScreen(
      currentUsername: currentUsername,
      currentBio: currentBio,
    );
  }
}
