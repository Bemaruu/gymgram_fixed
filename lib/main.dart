import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_colors.dart';
import 'core/app_radius.dart';
import 'firebase_options.dart';
import 'routes.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';

const _supabaseUrl     = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _mixpanelToken   = String.fromEnvironment('MIXPANEL_TOKEN');

Future<void> main() async {
  await runZonedGuarded(_boot, (error, stack) {
    if (kDebugMode) debugPrint('GymGram fatal: $error\n$stack');
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Algo salió mal al iniciar la app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw StateError(
      'Credenciales no configuradas. Usa:\n'
      'flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
    );
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // En release usamos providers reales (Play Integrity / DeviceCheck) y en
    // debug seguimos con providers debug para no bloquear sideload/dev.
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
      appleProvider:
          kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase init error (notificaciones no disponibles): $e');
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  // Listener de sesión: redirige según eventos de auth.
  Supabase.instance.client.auth.onAuthStateChange.listen(
    (data) {
      void navigate(String route) {
        final state = NotificationService.navigatorKey.currentState;
        if (state != null) {
          state.pushNamedAndRemoveUntil(route, (r) => false);
        } else {
          // Cold start: el navigator aún no está listo; diferir al próximo frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationService.navigatorKey.currentState
                ?.pushNamedAndRemoveUntil(route, (r) => false);
          });
        }
      }

      if (data.event == AuthChangeEvent.signedOut) {
        navigate('/');
      }
      if (data.event == AuthChangeEvent.passwordRecovery) {
        navigate('/reset-password');
      }
      if (data.event == AuthChangeEvent.signedIn) {
        unawaited(NotificationService.instance.initialize().catchError((_) {}));
      }
    },
    onError: (error, stackTrace) {
      // Errores del stream de auth (ej: fallo de intercambio PKCE al abrir
      // la app desde un deep link) no deben crashear la app. Redirigir a inicio.
      if (kDebugMode) debugPrint('Auth stream error: $error');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (r) => false);
      });
    },
  );

  // Deep links con token_hash (email template con link directo a la app).
  unawaited(_listenForAuthDeepLinks());

  // Analytics no bloquea el arranque — se inicializa en segundo plano
  unawaited(Future(() async {
    try {
      await AnalyticsService.instance.initIfConsented(_mixpanelToken);
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && AnalyticsService.instance.isInitialized) {
        AnalyticsService.instance.identify(user.id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Mixpanel init error: $e');
    }
  }));

  // Inicializar notificaciones solo si el usuario ya está autenticado
  unawaited(Future(() async {
    try {
      if (Supabase.instance.client.auth.currentUser != null) {
        await NotificationService.instance.initialize();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService init error: $e');
    }
  }));

  // Pagos (RevenueCat) — no bloquea el arranque. Si las claves no están
  // configuradas, simplemente queda inactivo.
  unawaited(Future(() async {
    try {
      await PurchaseService.instance.init();
    } catch (e) {
      if (kDebugMode) debugPrint('PurchaseService init error: $e');
    }
  }));

  runApp(const GymGramApp());
}

// Escucha deep links con ?token_hash=...&type=recovery generados por el
// email template personalizado. supabase_flutter ignora estos URIs porque no
// contienen ?code= (PKCE), así que los procesamos manualmente.
Future<void> _listenForAuthDeepLinks() async {
  try {
    final links = AppLinks();
    final initial = await links.getInitialLink();
    if (initial != null) unawaited(_handleTokenHashUri(initial));
    links.uriLinkStream.listen(
      (uri) => unawaited(_handleTokenHashUri(uri)),
      onError: (_) {},
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Deep link setup error: $e');
  }
}

Future<void> _handleTokenHashUri(Uri uri) async {
  // PKCE flow (Supabase default): Supabase verifies server-side and redirects to
  // com.gymgram.app://password-reset?code=CODE. Exchange the code for a session.
  final code = uri.queryParameters['code'];
  if (code != null) {
    try {
      await Supabase.instance.client.auth.exchangeCodeForSession(code);
      // Navegar explícitamente: exchangeCodeForSession puede disparar signedIn
      // en vez de passwordRecovery, así que no confiamos en el listener.
      void go() {
        NotificationService.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/reset-password', (r) => false);
      }
      if (NotificationService.navigatorKey.currentState != null) {
        go();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => go());
      }
    } catch (e) {
      if (kDebugMode) debugPrint('exchangeCodeForSession error: $e');
    }
    return;
  }

  // Legacy OTP fallback: token_hash in query params.
  final tokenHash = uri.queryParameters['token_hash'];
  final type = uri.queryParameters['type'];
  if (tokenHash != null && type == 'recovery') {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.recovery,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('OTP verify error: $e');
    }
    return;
  }

  // access_token in fragment (implicit flow fallback).
  final fragment = uri.fragment;
  if (fragment.isEmpty) return;
  final fragParams = Uri.splitQueryString(fragment);
  final accessToken = fragParams['access_token'];
  final refreshToken = fragParams['refresh_token'];
  if (accessToken == null || refreshToken == null) return;
  try {
    await Supabase.instance.client.auth.setSession(refreshToken, accessToken: accessToken);
    void go() {
      NotificationService.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/reset-password', (r) => false);
    }
    if (NotificationService.navigatorKey.currentState != null) {
      go();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => go());
    }
  } catch (e) {
    if (kDebugMode) debugPrint('setSession error: $e');
  }
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
