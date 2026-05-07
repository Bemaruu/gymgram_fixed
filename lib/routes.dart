import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Onboarding
import 'ui/onboarding/welcome_screen.dart';
import 'ui/onboarding/login_screen.dart';
import 'ui/onboarding/signup_step_1.dart';
import 'ui/onboarding/signup_step_2.dart';
import 'ui/onboarding/signup_step_3.dart';
import 'ui/onboarding/signup_step_4.dart';
import 'ui/onboarding/signup_step_5.dart';
import 'ui/onboarding/signup_step_6.dart';
import 'ui/onboarding/signup_step_7.dart';
import 'ui/onboarding/signup_step_8.dart';
import 'ui/onboarding/signup_step_9.dart';
import 'ui/onboarding/signup_step_10.dart';
import 'ui/onboarding/signup_step_11.dart';
import 'ui/onboarding/signup_step_12.dart';
import 'ui/onboarding/signup_step_13.dart';

// Menú principal (nuevas pantallas con bottom nav)
import 'ui/main_screens/main_navigation_screen.dart';
import 'ui/main_screens/home_screen.dart';
import 'ui/main_screens/rutina_screen.dart';
import 'ui/main_screens/alimentacion_screen.dart';
import 'ui/main_screens/perfil_screen.dart';
import 'ui/main_screens/edit_profile_screen.dart';
import 'ui/main_screens/food_search_screen.dart';
import 'ui/medals/user_medals_screen.dart';
import 'ui/search/search_screen.dart';
import 'ui/main_screens/create_custom_routine_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  // Onboarding
  '/': (_) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return MainNavigationScreen(userData: const <String, dynamic>{});
    }
    return const WelcomeScreen();
  },
  '/login': (_) => const LoginScreen(),
  '/signup_step_1': (_) => const SignupStep1(),
  '/signup_step_2': (_) => const SignupStep2(),
  '/signup_step_3': (_) => const SignupStep3(),
  '/signup_step_4': (_) => const SignupStep4(),
  '/signup_step_5': (_) => const SignupStep5(),
  '/signup_step_6': (_) => const SignupStep6(),
  '/signup_step_7': (_) => const SignupStep7(),
  '/signup_step_8': (_) => const SignupStep8(),
  '/signup_step_9': (_) => const SignupStep9(),
  '/signup_step_10': (_) => const SignupStep10(),
  '/signup_step_11': (_) => const SignupStep11(),
  '/signup_step_12': (_) => const SignupStep12(),
  '/signup_step_13': (_) => const SignupStep13(),

  // Pantalla con navegación inferior
  '/main_navigation_screen': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return MainNavigationScreen(userData: args);
  },

  // Estas rutas se usan internamente por el bottom nav (opcionalmente)
  '/home_screen': (_) => const HomeScreen(),
  '/rutina_screen': (_) => const RoutineScreen(),
  '/alimentacion_screen': (_) => const AlimentacionScreen(),
  '/profile_screen': (_) => const ProfileScreen(
    initialUsername: '',
    initialBio: '',
  ),

  '/search': (_) => const SearchScreen(),
  '/food-search': (_) => const FoodSearchScreen(),

  '/edit_profile': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return EditProfileScreen(
      currentUsername: args['username'],
      currentBio: args['bio'],
    );
  },

  '/medals': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return UserMedalsScreen(
      userId: args['userId'] as String,
      isOwner: args['isOwner'] as bool? ?? false,
    );
  },

  '/create-routine': (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final initialDay = args is Map ? args['selectedDay'] as int? : null;
    final availableDays = args is Map ? args['availableDays'] as List<bool>? : null;
    return CreateCustomRoutineScreen(initialDay: initialDay, availableDays: availableDays);
  },
};
