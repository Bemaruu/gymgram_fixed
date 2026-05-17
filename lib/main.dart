import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_colors.dart';
import 'core/app_radius.dart';
import 'firebase_options.dart';
import 'routes.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';

const _supabaseUrl     = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _mixpanelToken   = String.fromEnvironment('MIXPANEL_TOKEN');

Future<void> main() async {
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError(
      'Credenciales no configuradas. Usa:\n'
      'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\n'
      'O configura .vscode/launch.json con los valores reales.',
    );
  }
  await runZonedGuarded(_boot, (error, stack) {
    debugPrint('GymGram fatal: $error\n$stack');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Error al iniciar la app. Por favor reiníciala.')),
      ),
    ));
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
  } catch (e) {
    debugPrint('Firebase init error (notificaciones no disponibles): $e');
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  // Analytics no bloquea el arranque — se inicializa en segundo plano
  unawaited(Future(() async {
    try {
      await AnalyticsService.instance.init(_mixpanelToken);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) AnalyticsService.instance.identify(user.id);
    } catch (e) {
      debugPrint('Mixpanel init error: $e');
    }
  }));

  // Inicializar notificaciones solo si el usuario ya está autenticado
  unawaited(Future(() async {
    try {
      if (Supabase.instance.client.auth.currentUser != null) {
        await NotificationService.instance.initialize();
      }
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }));

  runApp(const GymGramApp());
}

class GymGramApp extends StatelessWidget {
  const GymGramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymGram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkSurface,
        primaryColor: AppColors.sky400,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.sky400,
          onPrimary: AppColors.neutral900,
          secondary: AppColors.ember400,
          onSecondary: AppColors.neutral0,
          surface: AppColors.darkSurfaceCard,
          onSurface: AppColors.darkTextPrimary,
          error: Color(0xFFFF5252),
          onError: AppColors.neutral0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkTextPrimary,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppColors.darkSurfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
        dividerColor: AppColors.darkBorder,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: AppColors.darkTextPrimary,
          displayColor: AppColors.darkTextPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.sky300,
          unselectedItemColor: AppColors.darkTextSecondary,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextSecondary),
      ),
      themeMode: ThemeMode.light,
      navigatorKey: NotificationService.navigatorKey,
      initialRoute: '/',
      routes: appRoutes,
    );
  }
}
