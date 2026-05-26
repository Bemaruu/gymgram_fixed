import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/country_utils.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._();
  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => client.auth.currentUser?.id;

  // Crea el perfil completo del usuario tras el registro
  Future<void> createProfile({
    required String userId,
    required String username,
    String? email,
    required String fullName,
    required int age,
    required String gender,
    required double weight,
    required double height,
    required double targetWeight,
    required String fitnessGoal,
    required String trainingLocation,
    required String timeAvailability,
    String? birthDate,
    String? countryCode,
  }) async {
    final row = <String, dynamic>{
      'id': userId,
      'username': username,
      'full_name': fullName.isNotEmpty ? fullName : username,
      'age': age,
      'gender': gender,
      'weight': weight,
      'height': height,
      'target_weight': targetWeight,
      'fitness_goal': fitnessGoal,
      'training_location': trainingLocation,
      'country_code': CountryUtils.normalize(countryCode),
      'bio': '',
    };
    if (birthDate != null && birthDate.isNotEmpty) {
      row['birth_date'] = birthDate;
    }
    await client.from('profiles').upsert(row);
  }

  // Devuelve el perfil del usuario actual como mapa crudo
  Future<Map<String, dynamic>?> getRawMyProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return await client
        .from('profiles')
        .select(
          'id, username, full_name, bio, avatar_url, weight, height, '
          'target_weight, fitness_goal, training_location, gender, age, '
          'country_code',
        )
        .eq('id', uid)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> getOnboardingData() async {
    final uid = currentUserId;
    if (uid == null) return null;
    final rows = await client
        .from('user_onboarding_data')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> saveOnboardingData({
    required String userId,
    List<String> availableDays = const [],
    int? mealsPerDay,
    List<String> allergies = const [],
    List<String> foodPreferences = const [],
    List<String> exercisePreferences = const [],
    String timeAvailability = '',
    String experienceLevel = '',
    // Nuevos campos (todos opcionales para no romper callers viejos)
    String? trainingLevel,
    String? experiencePath,
    List<String> equipmentAvailable = const [],
    int? sessionDurationMinutes,
    String? routineSplitPreference,
    List<String> injuries = const [],
    String? injuryNotes,
    String? cookingTimePreference,
    List<String> dislikedFoods = const [],
    String? coachingStyle,
    bool? notificationsEnabled,
    DateTime? privacyConsentAt,
    DateTime? termsConsentAt,
    String? countryCode,
  }) async {
    final row = <String, dynamic>{
      'user_id': userId,
      'available_days': availableDays,
      'allergies': allergies,
      'food_preferences': foodPreferences,
      'exercise_preferences': exercisePreferences,
      'time_availability': timeAvailability,
      'experience_level': experienceLevel,
      'country_code': CountryUtils.normalize(countryCode),
      'equipment_available': equipmentAvailable,
      'injuries': injuries,
      'disliked_foods': dislikedFoods,
    };
    if (mealsPerDay != null) row['meals_per_day'] = mealsPerDay;
    if (trainingLevel != null) row['training_level'] = trainingLevel;
    if (experiencePath != null) row['experience_path'] = experiencePath;
    if (sessionDurationMinutes != null) row['session_duration_minutes'] = sessionDurationMinutes;
    if (routineSplitPreference != null) row['routine_split_preference'] = routineSplitPreference;
    if (injuryNotes != null && injuryNotes.isNotEmpty) row['injury_notes'] = injuryNotes;
    if (cookingTimePreference != null) row['cooking_time_preference'] = cookingTimePreference;
    if (coachingStyle != null) row['coaching_style'] = coachingStyle;
    if (notificationsEnabled != null) row['notifications_enabled'] = notificationsEnabled;
    if (privacyConsentAt != null) row['privacy_consent_at'] = privacyConsentAt.toIso8601String();
    if (termsConsentAt != null) row['terms_consent_at'] = termsConsentAt.toIso8601String();
    await client.from('user_onboarding_data').insert(row);
  }

  /// Importa la rutina semanal del usuario desde el flujo `analyze_existing_routine`.
  /// Crea las entradas en `routines` (kind='personal', source='user_imported') y
  /// deja `routine_analysis` con status='pending' para una IA futura.
  ///
  /// [days] tiene la forma: `[{ 'day_of_week': 0, 'title': 'Lunes',
  /// 'exercises': [{name, muscle_group, sets, reps, rest_seconds, optional_notes}] }]`.
  Future<void> importUserRoutine({
    required String userId,
    required List<Map<String, dynamic>> days,
    required String trainingLocation,
    String goal = 'CUSTOM',
  }) async {
    if (days.isEmpty) return;

    final analysisStub = {
      'status': 'pending',
      'source': 'simulated',
      'created_at': DateTime.now().toIso8601String(),
    };

    for (final day in days) {
      final exercises = (day['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (exercises.isEmpty) continue;

      // Archiva la rutina personal activa del dia (si existe) para respetar
      // "un dia = una rutina activa" (indice unico) y poder restaurarla luego.
      final dow = day['day_of_week'];
      if (dow != null) {
        await client
            .from('routines')
            .update({'is_archived': true, 'is_public': false})
            .eq('user_id', userId)
            .eq('kind', 'personal')
            .eq('day_of_week', dow)
            .eq('is_archived', false);
      }

      final routine = await client.from('routines').insert({
        'user_id': userId,
        'title': day['title'] ?? 'Día',
        'goal': goal,
        'training_location': trainingLocation,
        'day_of_week': day['day_of_week'],
        'kind': 'personal',
        'is_public': false,
        'source': 'user_imported',
        'routine_analysis': analysisStub,
      }).select().single();

      final routineId = routine['id'] as String;
      final rows = exercises.asMap().entries.map((e) {
        final ex = e.value;
        return {
          'routine_id': routineId,
          'name': ex['name'],
          'sets': ex['sets'],
          'reps': ex['reps'],
          'rest_seconds': ex['rest_seconds'],
          'muscle_group': ex['muscle_group'],
          'order_index': e.key,
          if (ex['optional_notes'] != null) 'notes': ex['optional_notes'],
        };
      }).toList();
      await client.from('routine_exercises').insert(rows);
    }
  }

  // ── Búsqueda de perfiles ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final uid = currentUserId;
    if (query.trim().isEmpty) return [];
    var q = client
        .from('public_profiles')
        .select('id, username, full_name, avatar_url, bio, fitness_goal')
        .ilike('username', '%${query.trim()}%');
    if (uid != null) q = q.neq('id', uid);
    final result = await q.limit(25);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Perfiles sugeridos para descubrir/seguir (cold-start). Excluye al usuario
  /// actual. El estado de "siguiendo" se resuelve por tarjeta en la UI.
  Future<List<Map<String, dynamic>>> getSuggestedProfiles({int limit = 20}) async {
    final uid = currentUserId;
    var q = client
        .from('public_profiles')
        .select('id, username, full_name, avatar_url, bio, fitness_goal');
    if (uid != null) q = q.neq('id', uid);
    final result = await q.limit(limit);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    return await client
        .from('public_profiles')
        .select('id, username, full_name, avatar_url, bio, fitness_goal, training_location')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getPostsByUserId(String userId) async {
    final result = await client
        .from('posts')
        .select('id, media_url, media_type, caption, likes_count, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  // ── Sistema de seguimiento ────────────────────────────────────────────────

  Future<bool> isFollowing(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final result = await client
        .from('follows')
        .select('id')
        .eq('follower_id', uid)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return result != null;
  }

  Future<void> followUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await client.from('follows').insert({
      'follower_id': uid,
      'following_id': targetUserId,
    });
    // La medalla "Referente" la recalcula el propio dueno via syncSelfBadges al abrir
    // su perfil (award_badge solo permite auto-otorgar, no otorgar a terceros).
    try {
      await client.rpc('notify_follow', params: {'p_following_id': targetUserId});
    } catch (_) {}
  }

  Future<void> unfollowUser(String targetUserId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await client
        .from('follows')
        .delete()
        .eq('follower_id', uid)
        .eq('following_id', targetUserId);
  }

  Future<Map<String, int>> getFollowCounts(String userId) async {
    final followersRes = await client
        .from('follows')
        .select()
        .eq('following_id', userId)
        .count(CountOption.exact);
    final followingRes = await client
        .from('follows')
        .select()
        .eq('follower_id', userId)
        .count(CountOption.exact);
    return {
      'followers': followersRes.count,
      'following': followingRes.count,
    };
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final rows = await client
        .from('follows')
        .select('follower_id')
        .eq('following_id', userId);
    if ((rows as List).isEmpty) return [];
    final ids = rows.map((r) => r['follower_id'] as String).toList();
    final profiles = await client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', ids);
    return (profiles as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final rows = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    if ((rows as List).isEmpty) return [];
    final ids = rows.map((r) => r['following_id'] as String).toList();
    final profiles = await client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', ids);
    return (profiles as List).cast<Map<String, dynamic>>();
  }

  Future<String> uploadAvatar(File file) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('No autenticado');

    // Borrar avatar anterior usando la URL almacenada en el perfil
    try {
      final profile = await getRawMyProfile();
      final oldUrl = profile?['avatar_url'] as String?;
      if (oldUrl != null && oldUrl.isNotEmpty) {
        // Extraer path relativo desde la URL pública
        final uri = Uri.parse(oldUrl);
        final segments = uri.pathSegments;
        // La URL tiene forma: .../object/public/posts/{path}
        final bucketIndex = segments.indexOf('posts');
        if (bucketIndex != -1 && bucketIndex < segments.length - 1) {
          final oldPath = segments.sublist(bucketIndex + 1).join('/');
          await client.storage.from('posts').remove([oldPath]);
        }
      }
    } catch (_) {}

    // Nombre único por timestamp → URL siempre diferente → sin conflicto ni cache
    final ext = file.path.split('.').last.toLowerCase();
    final uploadPath = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from('posts').upload(uploadPath, file);
    final url = client.storage.from('posts').getPublicUrl(uploadPath);
    await updateProfile(avatarUrl: url);
    return url;
  }

  Future<void> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? fitnessGoal,
    String? trainingLocation,
    String? foodMode,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (username != null) updates['username'] = username;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (fitnessGoal != null) updates['fitness_goal'] = fitnessGoal;
    if (trainingLocation != null) updates['training_location'] = trainingLocation;
    if (foodMode != null) updates['food_mode'] = foodMode;
    if (updates.isNotEmpty) {
      await client.from('profiles').update(updates).eq('id', uid);
    }
  }
}
