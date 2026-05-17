import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF63C8FC);      // Celeste brillante
  static const Color mediumBlue = Color(0xFF1479AA);   // Azul medio
  static const Color darkBlue = Color(0xFF0E4568);     // Azul oscuro
  static const Color deepBlue = Color(0xFF091D2E);     // Azul más profundo
  static const Color accentOrange = Color(0xFFFD6D2F); // Naranja central
  static const Color background = Color(0xFFF5F5F5); // fondo claro neutro
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color lightGray = Color(0xFFF5F5F5);     // Fondo claro para inputs

  // Tokens pantalla Account Settings
  static const settingsSurface = Color(0xFF0A0A0A);
  static const settingsElevated = Color(0xFF1C1C1E);
  static const settingsDivider = Color(0x0FFFFFFF); // white 6%
  static const settingsDanger = Color(0xFFFF5252);
  static const settingsWarning = Color(0xFFFFB341);
  static const settingsSuccess = Color(0xFF2ECC71);

  // === Escala SKY (primary celeste extendida) ===
  static const Color sky50  = Color(0xFFE8F6FE);
  static const Color sky100 = Color(0xFFC5E9FD);
  static const Color sky200 = Color(0xFF9CDAFC);
  static const Color sky300 = Color(0xFF7DCFFC);
  static const Color sky400 = Color(0xFF63C8FC); // = primary
  static const Color sky500 = Color(0xFF3DB4F0);
  static const Color sky600 = Color(0xFF1F9BDE);
  static const Color sky700 = Color(0xFF1479AA); // = mediumBlue
  static const Color sky800 = Color(0xFF0E4568); // = darkBlue
  static const Color sky900 = Color(0xFF091D2E); // = deepBlue

  // === Escala EMBER (naranja acento extendida) ===
  static const Color ember50  = Color(0xFFFFF1E9);
  static const Color ember100 = Color(0xFFFFD9C2);
  static const Color ember200 = Color(0xFFFFBC97);
  static const Color ember300 = Color(0xFFFE9A6A);
  static const Color ember400 = Color(0xFFFD6D2F); // = accentOrange
  static const Color ember500 = Color(0xFFE85718);
  static const Color ember600 = Color(0xFFC44510);
  static const Color ember700 = Color(0xFF9A3509);
  static const Color ember800 = Color(0xFF6E2606);
  static const Color ember900 = Color(0xFF421604);

  // === Neutros ===
  static const Color neutral0   = Color(0xFFFFFFFF);
  static const Color neutral50  = Color(0xFFF7F9FB);
  static const Color neutral100 = Color(0xFFF0F2F5);
  static const Color neutral200 = Color(0xFFE1E5EB);
  static const Color neutral400 = Color(0xFF9AA3AE);
  static const Color neutral600 = Color(0xFF525B66);
  static const Color neutral800 = Color(0xFF1C1C1E); // = settingsElevated
  static const Color neutral900 = Color(0xFF0A0A0A); // = settingsSurface

  // === Semánticos ===
  static const Color info = sky400;
  static const Color successSoft = Color(0xFF0F3D24);

  // === Surfaces Dark "Deep Sky" ===
  static const Color darkSurface         = Color(0xFF091D2E); // = sky900
  static const Color darkSurfaceCard     = Color(0xFF0E2238);
  static const Color darkSurfaceElevated = Color(0xFF13314E);
  static const Color darkBorder          = Color(0xFF1F4368);
  static const Color darkTextPrimary     = Color(0xFFF0F6FB);
  static const Color darkTextSecondary   = Color(0xFF9CB5C9);

  // === Gradientes signature ===
  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sky400, ember400],
  );

  static const LinearGradient deepSkyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [sky900, sky800, sky700],
  );

  static const LinearGradient morningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sky50, ember50],
  );

  static const LinearGradient medalGoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE08A), ember400, ember600],
  );

  static const RadialGradient streakFireGradient = RadialGradient(
    colors: [Color(0xFFFFB341), ember400, Color(0xFFFF5252)],
  );
}
