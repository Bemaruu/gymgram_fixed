import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/country_utils.dart';
import 'badge_service.dart';
import 'image_compressor.dart';

class ProfileService {
  static final ProfileService instance = ProfileService._();
  ProfileService._();

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> getMyProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    return await _client.from('profiles').select().eq('id', uid).maybeSingle();
  }

  Future<Map<String, dynamic>?> getProfileByUsername(String username) async {
    return await _client
        .from('profiles')
        .select()
        .eq('username', username)
        .maybeSingle();
  }

  Future<void> createProfile({
    required String userId,
    required String username,
    String? fullName,
    int? age,
    String? gender,
    double? weight,
    double? height,
    double? targetWeight,
    String? fitnessGoal,
    String? trainingLocation,
    String? foodMode,
    String? countryCode,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'username': username,
      'full_name': (fullName?.isNotEmpty == true) ? fullName : username,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (weight != null) 'weight': weight,
      if (height != null) 'height': height,
      if (targetWeight != null) 'target_weight': targetWeight,
      if (fitnessGoal != null) 'fitness_goal': fitnessGoal,
      if (trainingLocation != null) 'training_location': trainingLocation,
      if (foodMode != null) 'food_mode': foodMode,
      'country_code': CountryUtils.normalize(countryCode),
      'bio': '',
    });
    await BadgeService.instance.checkAndAwardBadges(userId, 'profile_completed');
  }

  Future<void> updateProfile({
    String? username,
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? fitnessGoal,
    String? trainingLocation,
    String? foodMode,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (fullName != null) data['full_name'] = fullName;
    if (bio != null) data['bio'] = bio;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (fitnessGoal != null) data['fitness_goal'] = fitnessGoal;
    if (trainingLocation != null) data['training_location'] = trainingLocation;
    if (foodMode != null) data['food_mode'] = foodMode;
    if (data.isNotEmpty) {
      await _client.from('profiles').update(data).eq('id', uid);
    }
  }

  // Sube la foto de perfil al bucket 'avatars' y devuelve la URL pública
  Future<String?> uploadAvatar(File file) async {
    final uid = _uid;
    if (uid == null) return null;
    const maxBytes = 5 * 1024 * 1024;
    const allowed = ['jpg', 'jpeg', 'png', 'heic', 'webp'];
    final ext = file.path.split('.').last.toLowerCase();
    if (!allowed.contains(ext)) {
      throw Exception('Formato de imagen no permitido.');
    }
    final size = await file.length();
    if (size > maxBytes) {
      throw Exception('La imagen supera el límite de 5 MB.');
    }
    final compressed = await ImageCompressor.compress(file, maxDimension: 400);
    const path = 'avatar.jpg';
    await _client.storage.from('avatars').upload(
      '$uid/$path',
      compressed,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    return _client.storage.from('avatars').getPublicUrl('$uid/$path');
  }
}
