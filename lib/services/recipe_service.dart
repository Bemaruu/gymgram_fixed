import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_service.dart';

class RecipeIngredientInput {
  final String? foodId;
  final String? foodNameManual;
  final double grams;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  const RecipeIngredientInput({
    required this.grams,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.foodId,
    this.foodNameManual,
  });
}

class RecipeMacros {
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  const RecipeMacros({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  static const zero = RecipeMacros(kcal: 0, protein: 0, carbs: 0, fat: 0);
}

/// Recetas creadas por el usuario.
/// Free puede publicar hasta 5 recetas. Plus/Premium ilimitado.
class RecipeService {
  static final RecipeService instance = RecipeService._();
  RecipeService._();

  static const int freePublishLimit = 5;

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<String?> createRecipe({
    required String name,
    required double servings,
    int? prepTimeMin,
    String? imageUrl,
    String? instructions,
    required bool isPublic,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final inserted = await _client
          .from('user_recipes')
          .insert({
            'user_id': uid,
            'name': name,
            'servings': servings,
            'prep_time_min': prepTimeMin,
            'image_url': imageUrl,
            'instructions': instructions,
            'is_public': isPublic,
          })
          .select('id')
          .single();
      final recipeId = inserted['id'] as String;

      if (ingredients.isNotEmpty) {
        await _client
            .from('user_recipe_ingredients')
            .insert(_ingredientRows(recipeId, ingredients));
      }
      return recipeId;
    } catch (e) {
      debugPrint('RecipeService.createRecipe error: $e');
      return null;
    }
  }

  /// Edita una receta existente (solo del propio usuario, por RLS) y
  /// reemplaza por completo su lista de ingredientes.
  Future<bool> updateRecipe({
    required String recipeId,
    required String name,
    required double servings,
    int? prepTimeMin,
    String? imageUrl,
    String? instructions,
    required bool isPublic,
    required List<RecipeIngredientInput> ingredients,
  }) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('user_recipes').update({
        'name': name,
        'servings': servings,
        'prep_time_min': prepTimeMin,
        'image_url': imageUrl,
        'instructions': instructions,
        'is_public': isPublic,
      }).eq('id', recipeId);

      // Reemplazo total de ingredientes.
      await _client
          .from('user_recipe_ingredients')
          .delete()
          .eq('recipe_id', recipeId);
      if (ingredients.isNotEmpty) {
        await _client
            .from('user_recipe_ingredients')
            .insert(_ingredientRows(recipeId, ingredients));
      }
      return true;
    } catch (e) {
      debugPrint('RecipeService.updateRecipe error: $e');
      return false;
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      // Los ingredientes caen por ON DELETE CASCADE / RLS de receta propia.
      await _client.from('user_recipes').delete().eq('id', recipeId);
      return true;
    } catch (e) {
      debugPrint('RecipeService.deleteRecipe error: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _ingredientRows(
    String recipeId,
    List<RecipeIngredientInput> ingredients,
  ) {
    return ingredients
        .map((i) => {
              'recipe_id': recipeId,
              'food_id': i.foodId,
              'food_name_manual': i.foodNameManual,
              'grams': i.grams,
              'kcal_per_100g': i.kcalPer100g,
              'protein_per_100g': i.proteinPer100g,
              'carbs_per_100g': i.carbsPer100g,
              'fat_per_100g': i.fatPer100g,
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyRecipes({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('user_recipes')
          .select(
            'id, name, servings, prep_time_min, image_url, is_public, saves_count, created_at',
          )
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('RecipeService.getMyRecipes error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPublicRecipesOf(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final rows = await _client
          .from('user_recipes')
          .select(
            'id, name, servings, prep_time_min, image_url, saves_count, created_at',
          )
          .eq('user_id', userId)
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('RecipeService.getPublicRecipesOf error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRecipe(String recipeId) async {
    try {
      final row = await _client
          .from('user_recipes')
          .select(
            'id, user_id, name, servings, prep_time_min, image_url, instructions, is_public, saves_count, created_at',
          )
          .eq('id', recipeId)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('RecipeService.getRecipe error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getIngredients(String recipeId) async {
    try {
      final rows = await _client
          .from('user_recipe_ingredients')
          .select(
            'id, food_id, food_name_manual, grams, '
            'kcal_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g',
          )
          .eq('recipe_id', recipeId);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('RecipeService.getIngredients error: $e');
      return [];
    }
  }

  Future<bool> saveRecipe(String recipeId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _client.from('saved_recipes').insert({
        'user_id': uid,
        'recipe_id': recipeId,
      });
      return true;
    } catch (e) {
      debugPrint('RecipeService.saveRecipe error: $e');
      return false;
    }
  }

  Future<void> unsaveRecipe(String recipeId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client
          .from('saved_recipes')
          .delete()
          .eq('user_id', uid)
          .eq('recipe_id', recipeId);
    } catch (e) {
      debugPrint('RecipeService.unsaveRecipe error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSavedRecipes({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('saved_recipes')
          .select(
            'recipe_id, saved_at, user_recipes!inner(id, user_id, name, servings, prep_time_min, image_url, saves_count)',
          )
          .eq('user_id', uid)
          .order('saved_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('RecipeService.getSavedRecipes error: $e');
      return [];
    }
  }

  Future<bool> isSaved(String recipeId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final row = await _client
          .from('saved_recipes')
          .select('id')
          .eq('user_id', uid)
          .eq('recipe_id', recipeId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Calcula macros totales (no por porcion) sumando los ingredientes.
  RecipeMacros calculateMacros(List<RecipeIngredientInput> ingredients) {
    double kcal = 0, protein = 0, carbs = 0, fat = 0;
    for (final i in ingredients) {
      final f = i.grams / 100.0;
      kcal += i.kcalPer100g * f;
      protein += i.proteinPer100g * f;
      carbs += i.carbsPer100g * f;
      fat += i.fatPer100g * f;
    }
    return RecipeMacros(kcal: kcal, protein: protein, carbs: carbs, fat: fat);
  }

  Future<String?> uploadRecipeImage(File file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ext = file.path.split('.').last.toLowerCase();
      // El bucket 'posts' exige que la primera carpeta sea el uid (RLS).
      final path = '$uid/recipes/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('posts').upload(path, file);
      return _client.storage.from('posts').getPublicUrl(path);
    } catch (e) {
      debugPrint('RecipeService.uploadRecipeImage error: $e');
      return null;
    }
  }

  /// Si el usuario puede publicar mas recetas publicas.
  /// Free: max 5. Plus/Premium: ilimitado.
  Future<bool> canPublishMore() async {
    final uid = _uid;
    if (uid == null) return false;
    final tier = await SubscriptionService.instance.currentTier();
    if (tier != SubscriptionTier.free) return true;
    try {
      final rows = await _client
          .from('user_recipes')
          .select('id')
          .eq('user_id', uid)
          .eq('is_public', true);
      return (rows as List).length < freePublishLimit;
    } catch (_) {
      return false;
    }
  }
}
