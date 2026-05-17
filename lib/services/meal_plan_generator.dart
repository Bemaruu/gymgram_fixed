import 'simulated_ai_service.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// Capa de abstracción del generador de dietas.
///
/// Hoy la app usa una IA simulada (`SimulatedAIService`). Cuando se conecte la
/// IA real (Edge Function de Supabase llamando OpenAI / Claude / Gemini, o un
/// modelo on-device), basta con:
///
///   1. Implementar una nueva clase `RealMealPlanGenerator implements
///      MealPlanGenerator` que internamente haga `supabase.functions.invoke(
///      'generate-meal-plan', body: input.toJson())` y devuelva el mismo
///      mapa de claves (`total_calories`, `items`, `protein_grams`, …).
///   2. Cambiar la línea final de este archivo:
///        MealPlanGeneratorProvider.current = const RealMealPlanGenerator();
///   3. Si la UI quiere streaming/loading, migrar `alimentacion_screen` a
///      llamar `MealPlanGeneratorProvider.current.generate(input)` en vez de
///      `SimulatedAIService.generateMealPlan` directamente.
///
/// La firma `generate(MealPlanInput) -> Future<Map<String, dynamic>>` ya es
/// asincrónica, así que el día que cambie a IA real no hay que tocar la UI.
/// ════════════════════════════════════════════════════════════════════════════

/// Datos consumidos por cualquier generador de planes (simulado o IA real).
/// Mantener este contrato estable permite cambiar la implementación interna
/// (Supabase Edge Function, OpenAI, Claude, Gemini…) sin tocar la UI.
class MealPlanInput {
  final String goal;
  final String gender;
  final double weightKg;
  final int age;
  final double heightCm;
  final double targetWeightKg;
  final int trainingDaysPerWeek;
  final String dailyActivityLevel;
  final String mealsPerDay;
  final List<String> foodPreferences;
  final List<String> allergies;
  final List<String> dislikedFoods;
  final String? cookingTime;
  final String? userId;
  final int weekIndex;
  final int dayIndex;

  const MealPlanInput({
    required this.goal,
    required this.gender,
    required this.weightKg,
    this.age = 30,
    this.heightCm = 170.0,
    this.targetWeightKg = 0,
    this.trainingDaysPerWeek = 3,
    this.dailyActivityLevel = 'moderate',
    this.mealsPerDay = '3',
    this.foodPreferences = const [],
    this.allergies = const [],
    this.dislikedFoods = const [],
    this.cookingTime,
    this.userId,
    this.weekIndex = 0,
    this.dayIndex = 0,
  });
}

/// Contrato común. Permite inyectar `SimulatedMealPlanGenerator` hoy y
/// reemplazarlo por una implementación basada en IA real (con la misma
/// firma) cuando esté lista.
abstract class MealPlanGenerator {
  /// Genera el plan. Debe devolver el mismo mapa de claves que la UI
  /// consume hoy (total_calories, protein_grams, items, etc.) para no
  /// romper la pantalla al hacer el swap.
  Future<Map<String, dynamic>> generate(MealPlanInput input);
}

/// Implementación actual: usa el motor heurístico simulado.
/// Cuando llegue la IA real basta crear `RealMealPlanGenerator` y
/// cambiar el binding en [MealPlanGeneratorProvider].
class SimulatedMealPlanGenerator implements MealPlanGenerator {
  const SimulatedMealPlanGenerator();

  @override
  Future<Map<String, dynamic>> generate(MealPlanInput input) async {
    final plan = SimulatedAIService.generateMealPlan(
      goal: input.goal,
      gender: input.gender,
      weightKg: input.weightKg,
      age: input.age,
      heightCm: input.heightCm,
      targetWeightKg: input.targetWeightKg,
      trainingDaysPerWeek: input.trainingDaysPerWeek,
      dailyActivityLevel: input.dailyActivityLevel,
      mealsPerDay: input.mealsPerDay,
      foodPreferences: input.foodPreferences,
      allergies: input.allergies,
      dislikedFoods: input.dislikedFoods,
      cookingTime: input.cookingTime,
      userId: input.userId,
      weekIndex: input.weekIndex,
      dayIndex: input.dayIndex,
    );
    return plan;
  }
}

/// Punto único de inyección. La UI (alimentacion_screen) puede seguir
/// llamando directamente a [SimulatedAIService.generateMealPlan] como hoy,
/// pero cuando se migre a IA real basta cambiar el `current` aquí.
class MealPlanGeneratorProvider {
  MealPlanGeneratorProvider._();

  static MealPlanGenerator current = const SimulatedMealPlanGenerator();
}
