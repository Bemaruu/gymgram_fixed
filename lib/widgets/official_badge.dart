import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Insignia de cuenta oficial de GymGram: círculo con una mancuerna (en vez del
/// clásico tick de verificado) para que tenga sentido con la app.
///
/// Se usa junto al @usuario en feed y perfiles cuando `profiles.is_official`.
class OfficialBadge extends StatelessWidget {
  const OfficialBadge({super.key, this.size = 16});

  /// Diámetro del círculo en píxeles.
  final double size;

  /// Atajo: devuelve la insignia si [isOfficial], o un widget vacío si no.
  static Widget when(bool? isOfficial, {double size = 16}) =>
      (isOfficial == true) ? OfficialBadge(size: size) : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00BFFF), Color(0xFF0077FF)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIconsFill.barbell,
        size: size * 0.66,
        color: Colors.white,
      ),
    );
  }
}
