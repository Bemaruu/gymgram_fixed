import 'package:flutter/material.dart';
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

final Map<String, WidgetBuilder> appRoutes = {
  '/': (_) => const WelcomeScreen(),
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
  // Agrega más pantallas aquí
};
