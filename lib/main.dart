import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'routes.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://qnrpyaoyzecjbryejccm.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFucnB5YW95emVjamJyeWVqY2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcyMjEwNTcsImV4cCI6MjA5Mjc5NzA1N30.zdXwiC18nkHkg2mLtAckN4rBfHdGSU2Vjove0wlPMr0',
);
const _mixpanelToken = String.fromEnvironment(
  'MIXPANEL_TOKEN',
  defaultValue: 'ce943eb2569a59d5a8e46a9c16be65ec',
);

Future<void> main() async {
  await runZonedGuarded(_boot, (error, stack) {
    debugPrint('GymGram fatal: $error\n$stack');
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(
                'GymGram error de arranque:\n\n$error\n\n$stack',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ));
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      theme: ThemeData(fontFamily: 'Roboto'),
      initialRoute: '/',
      routes: appRoutes,
    );
  }
}
