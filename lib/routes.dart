import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Onboarding
import 'ui/onboarding/welcome_screen.dart';
import 'ui/onboarding/login_screen.dart';
import 'ui/onboarding/reset_password_screen.dart';
import 'ui/onboarding/signup_step_1.dart';
import 'ui/onboarding/signup_step_5.dart';
import 'ui/onboarding/signup_step_13.dart';
import 'ui/onboarding/signup_consent.dart';
import 'ui/onboarding/signup_gender_birthdate.dart';
import 'ui/onboarding/signup_body_metrics.dart';
import 'ui/onboarding/signup_place.dart';
import 'ui/onboarding/signup_equipment.dart';
import 'ui/onboarding/signup_experience_level.dart';
import 'ui/onboarding/signup_experience_path.dart';
import 'ui/onboarding/signup_import_routine.dart';
import 'ui/onboarding/signup_split.dart';
import 'ui/onboarding/signup_days_duration.dart';
import 'ui/onboarding/signup_daily_activity.dart';
import 'ui/onboarding/signup_health_gate.dart';
import 'ui/onboarding/signup_parq.dart';
import 'ui/onboarding/signup_injuries.dart';
import 'ui/onboarding/signup_diet_meals.dart';
import 'ui/onboarding/signup_food_gate.dart';
import 'ui/onboarding/signup_scoff.dart';
import 'ui/onboarding/signup_menstrual_health.dart';
import 'ui/onboarding/signup_allergies.dart';
import 'ui/onboarding/signup_cooking_time.dart';
import 'ui/onboarding/signup_disliked_foods.dart';

// Menú principal (nuevas pantallas con bottom nav)
import 'ui/main_screens/main_navigation_screen.dart';
import 'ui/main_screens/home_screen.dart';
import 'ui/main_screens/rutina_screen.dart';
import 'ui/main_screens/alimentacion_screen.dart';
import 'ui/main_screens/perfil_screen.dart';
import 'ui/main_screens/edit_profile_screen.dart';
import 'ui/main_screens/settings/legal_document_screen.dart';
import 'ui/main_screens/food_search_screen.dart';
import 'ui/medals/user_medals_screen.dart';
import 'ui/search/search_screen.dart';
import 'ui/main_screens/create_custom_routine_screen.dart';
import 'ui/main_screens/create_community_routine_screen.dart';
import 'ui/messaging/chat_list_screen.dart';
import 'ui/admin/usage_dashboard_screen.dart';
import 'ui/admin/moderation_screen.dart';
import 'ui/main_screens/weight_log_screen.dart';

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
  '/reset-password': (_) => const ResetPasswordScreen(),
  '/signup_step_1': (_) => const SignupStep1(),
  '/signup_step_5': (_) => const SignupStep5(),
  '/signup_step_13': (_) => const SignupStep13(),
  '/signup_consent': (_) => const SignupConsent(),

  // Flujo de onboarding dividido (una pregunta por pantalla)
  '/signup_gender_birthdate': (_) => const SignupGenderBirthdate(),
  '/signup_body_metrics': (_) => const SignupBodyMetrics(),
  '/signup_place': (_) => const SignupPlace(),
  '/signup_equipment': (_) => const SignupEquipment(),
  '/signup_experience_level': (_) => const SignupExperienceLevel(),
  '/signup_experience_path': (_) => const SignupExperiencePath(),
  '/signup_import_routine': (_) => const SignupImportRoutine(),
  '/signup_split': (_) => const SignupSplit(),
  '/signup_days_duration': (_) => const SignupDaysDuration(),
  '/signup_daily_activity': (_) => const SignupDailyActivity(),
  '/signup_health_gate': (_) => const SignupHealthGate(),
  '/signup_parq': (_) => const SignupParq(),
  '/signup_injuries': (_) => const SignupInjuries(),
  '/signup_diet_meals': (_) => const SignupDietMeals(),
  '/signup_food_gate': (_) => const SignupFoodGate(),
  '/signup_scoff': (_) => const SignupScoff(),
  '/signup_menstrual_health': (_) => const SignupMenstrualHealth(),
  '/signup_allergies': (_) => const SignupAllergies(),
  '/signup_cooking_time': (_) => const SignupCookingTime(),
  '/signup_disliked_foods': (_) => const SignupDislikedFoods(),

  // Pantalla con navegación inferior
  '/main_navigation_screen': (context) {
    final raw = ModalRoute.of(context)?.settings.arguments;
    final args = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
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

  '/create-community-routine': (_) => const CreateCommunityRoutineScreen(),

  '/messages': (_) => const ChatListScreen(),

  '/weight-log': (_) => const WeightLogScreen(),

  '/legal/privacy': (_) => const LegalDocumentScreen(slug: 'privacy'),
  '/legal/terms': (_) => const LegalDocumentScreen(slug: 'terms'),
  '/legal/community': (_) => const LegalDocumentScreen(slug: 'community'),

  '/admin/usage': (_) {
    const adminUid = String.fromEnvironment('ADMIN_UID', defaultValue: '');
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (adminUid.isEmpty || currentUid != adminUid) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No autorizado', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    return const UsageDashboardScreen();
  },

  '/admin/reports': (_) {
    const adminUid = String.fromEnvironment('ADMIN_UID', defaultValue: '');
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (adminUid.isEmpty || currentUid != adminUid) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No autorizado', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    return const ModerationScreen();
  },
};
