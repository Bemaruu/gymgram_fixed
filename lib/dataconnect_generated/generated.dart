library dataconnect_generated;

import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

part 'add_water_tracking.dart';
part 'create_comment.dart';
part 'create_like.dart';
part 'create_post.dart';
part 'create_profile.dart';
part 'create_user.dart';
part 'list_posts.dart';
part 'get_my_profile.dart';

// ── Enum wrappers ─────────────────────────────────────────────────────────────

abstract class EnumValue<T> {
  String get stringValue;
  const EnumValue();
}

class Known<T> extends EnumValue<T> {
  final T value;
  const Known(this.value);
  @override
  String get stringValue => value.toString().split('.').last;
}

class Unknown<T> extends EnumValue<T> {
  final String rawValue;
  const Unknown(this.rawValue);
  @override
  String get stringValue => rawValue;
}

// ── Enums ─────────────────────────────────────────────────────────────────────

enum FitnessGoal { LOSE_WEIGHT, GAIN_MUSCLE, MAINTAIN }

enum Gender { MALE, FEMALE, OTHER, PREFER_NOT_TO_SAY }

enum TrainingLocation { GYM, HOME }

enum MediaType { IMAGE, VIDEO }

// ── Serializers / Deserializers ───────────────────────────────────────────────

String fitnessGoalSerializer(EnumValue<FitnessGoal> e) => e.stringValue;
EnumValue<FitnessGoal> fitnessGoalDeserializer(dynamic data) {
  switch (data) {
    case 'LOSE_WEIGHT':
      return const Known(FitnessGoal.LOSE_WEIGHT);
    case 'GAIN_MUSCLE':
      return const Known(FitnessGoal.GAIN_MUSCLE);
    case 'MAINTAIN':
      return const Known(FitnessGoal.MAINTAIN);
    default:
      return Unknown(data?.toString() ?? '');
  }
}

String genderSerializer(EnumValue<Gender> e) => e.stringValue;
EnumValue<Gender> genderDeserializer(dynamic data) {
  switch (data) {
    case 'MALE':
      return const Known(Gender.MALE);
    case 'FEMALE':
      return const Known(Gender.FEMALE);
    case 'OTHER':
      return const Known(Gender.OTHER);
    case 'PREFER_NOT_TO_SAY':
      return const Known(Gender.PREFER_NOT_TO_SAY);
    default:
      return Unknown(data?.toString() ?? '');
  }
}

String trainingLocationSerializer(EnumValue<TrainingLocation> e) => e.stringValue;
EnumValue<TrainingLocation> trainingLocationDeserializer(dynamic data) {
  switch (data) {
    case 'GYM':
      return const Known(TrainingLocation.GYM);
    case 'HOME':
      return const Known(TrainingLocation.HOME);
    default:
      return Unknown(data?.toString() ?? '');
  }
}

String mediaTypeSerializer(EnumValue<MediaType> e) => e.stringValue.toLowerCase();
EnumValue<MediaType> mediaTypeDeserializer(dynamic data) {
  switch ((data?.toString() ?? '').toLowerCase()) {
    case 'video':
      return const Known(MediaType.VIDEO);
    case 'image':
    default:
      return const Known(MediaType.IMAGE);
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

@immutable
class ListPostsPostsUser {
  final String username;
  final String email;
  final String? avatarUrl;
  final String userId;

  const ListPostsPostsUser({required this.username, this.email = '', this.avatarUrl, this.userId = ''});
}

@immutable
class ListPostsPosts {
  final String id;
  final String mediaUrl;
  final EnumValue<MediaType> mediaType;
  final String description;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final ListPostsPostsUser user;

  const ListPostsPosts({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.description,
    required this.createdAt,
    required this.likesCount,
    required this.commentsCount,
    required this.user,
  });
}

@immutable
class ListPostsData {
  final List<ListPostsPosts> posts;
  const ListPostsData({required this.posts});
}

@immutable
class GetMyProfileProfilesUser {
  final String username;
  final String email;
  const GetMyProfileProfilesUser({required this.username, this.email = ''});
}

@immutable
class GetMyProfileProfiles {
  final String id;
  final String displayName;
  final String bio;
  final int age;
  final EnumValue<Gender> gender;
  final double weight;
  final double height;
  final double targetWeight;
  final EnumValue<FitnessGoal> fitnessGoal;
  final EnumValue<TrainingLocation> trainingLocation;
  final String timeAvailability;
  final String? photoUrl;
  final List<String>? foodPreferences;
  final List<String>? exercisePreferences;
  final GetMyProfileProfilesUser user;

  const GetMyProfileProfiles({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    required this.targetWeight,
    required this.fitnessGoal,
    required this.trainingLocation,
    required this.timeAvailability,
    this.photoUrl,
    this.foodPreferences,
    this.exercisePreferences,
    required this.user,
  });
}

@immutable
class GetMyProfileData {
  final List<GetMyProfileProfiles> profiles;
  const GetMyProfileData({required this.profiles});
}

// ── Generic result wrapper ────────────────────────────────────────────────────

class DataResult<T> {
  final T? data;
  const DataResult({this.data});
}

// ── Operation builders ────────────────────────────────────────────────────────

class ListPostsVariablesBuilder {
  Future<DataResult<ListPostsData>> execute() async {
    try {
      final rawPosts = await SupabaseService.instance.getRawPosts();
      final posts = rawPosts.map((json) {
        final profile = json['profiles'] as Map<String, dynamic>? ?? {};
        return ListPostsPosts(
          id: json['id'] as String? ?? '',
          mediaUrl: json['media_url'] as String? ?? '',
          mediaType: mediaTypeDeserializer(json['media_type']),
          description: json['caption'] as String? ?? '',
          createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
          likesCount: json['likes_count'] as int? ?? 0,
          commentsCount: json['comments_count'] as int? ?? 0,
          user: ListPostsPostsUser(
            username: profile['username'] as String? ?? 'usuario',
            avatarUrl: profile['avatar_url'] as String?,
            userId: json['user_id'] as String? ?? '',
          ),
        );
      }).toList();
      return DataResult(data: ListPostsData(posts: posts));
    } catch (e) {
      debugPrint('ListPostsVariablesBuilder error: $e');
      return const DataResult(data: ListPostsData(posts: []));
    }
  }
}

class GetMyProfileVariablesBuilder {
  Future<DataResult<GetMyProfileData>> execute() async {
    try {
      final raw = await SupabaseService.instance.getRawMyProfile();
      if (raw == null) {
        return const DataResult(data: GetMyProfileData(profiles: []));
      }

      final profile = GetMyProfileProfiles(
        id: raw['id'] as String? ?? '',
        displayName: raw['full_name'] as String? ?? raw['username'] as String? ?? '',
        bio: raw['bio'] as String? ?? '',
        age: raw['age'] as int? ?? 18,
        gender: genderDeserializer(raw['gender']),
        weight: (raw['weight'] as num?)?.toDouble() ?? 0.0,
        height: (raw['height'] as num?)?.toDouble() ?? 0.0,
        targetWeight: (raw['target_weight'] as num?)?.toDouble() ?? 0.0,
        fitnessGoal: fitnessGoalDeserializer(raw['fitness_goal']),
        trainingLocation: trainingLocationDeserializer(raw['training_location']),
        timeAvailability: raw['time_availability'] as String? ?? '',
        photoUrl: raw['avatar_url'] as String?,
        user: GetMyProfileProfilesUser(
          username: raw['username'] as String? ?? '',
          email: raw['email'] as String? ?? '',
        ),
      );

      return DataResult(data: GetMyProfileData(profiles: [profile]));
    } catch (e) {
      debugPrint('GetMyProfileVariablesBuilder error: $e');
      return const DataResult(data: GetMyProfileData(profiles: []));
    }
  }
}

class CreateUserVariablesBuilder {
  final String username;
  final String email;

  CreateUserVariablesBuilder({required this.username, required this.email});

  Future<void> execute() async {
    // El usuario Auth ya fue creado por AuthService.registerWithEmail().
    // Guardamos username/email para que CreateProfileVariablesBuilder los use.
    ExampleConnector.instance._pendingUsername = username;
    ExampleConnector.instance._pendingEmail = email;
  }
}

class CreateProfileVariablesBuilder {
  final String displayName;
  final int age;
  final Gender gender;
  final double weight;
  final double height;
  final double targetWeight;
  final FitnessGoal fitnessGoal;
  final TrainingLocation trainingLocation;
  final String timeAvailability;
  final String? birthDate;

  CreateProfileVariablesBuilder({
    required this.displayName,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    required this.targetWeight,
    required this.fitnessGoal,
    required this.trainingLocation,
    required this.timeAvailability,
    this.birthDate,
  });

  Future<void> execute() async {
    final userId = SupabaseService.instance.currentUser?.id;
    if (userId == null) throw Exception('No hay usuario autenticado');

    final username = ExampleConnector.instance._pendingUsername ?? '';
    final email = ExampleConnector.instance._pendingEmail ?? '';

    await SupabaseService.instance.createProfile(
      userId: userId,
      username: username,
      email: email,
      fullName: displayName,
      age: age,
      gender: gender.name,
      weight: weight,
      height: height,
      targetWeight: targetWeight,
      fitnessGoal: fitnessGoal.name,
      trainingLocation: trainingLocation.name,
      timeAvailability: timeAvailability,
      birthDate: birthDate,
    );

    ExampleConnector.instance._pendingUsername = null;
    ExampleConnector.instance._pendingEmail = null;
  }
}

// ── ExampleConnector ──────────────────────────────────────────────────────────

class ExampleConnector {
  static final ExampleConnector instance = ExampleConnector._();
  ExampleConnector._();

  String? _pendingUsername;
  String? _pendingEmail;

  ListPostsVariablesBuilder listPosts() => ListPostsVariablesBuilder();

  GetMyProfileVariablesBuilder getMyProfile() => GetMyProfileVariablesBuilder();

  CreateUserVariablesBuilder createUser({
    required String username,
    required String email,
  }) =>
      CreateUserVariablesBuilder(username: username, email: email);

  CreateProfileVariablesBuilder createProfile({
    required String displayName,
    required int age,
    required Gender gender,
    required double weight,
    required double height,
    required double targetWeight,
    required FitnessGoal fitnessGoal,
    required TrainingLocation trainingLocation,
    required String timeAvailability,
    String? birthDate,
  }) =>
      CreateProfileVariablesBuilder(
        displayName: displayName,
        age: age,
        gender: gender,
        weight: weight,
        height: height,
        targetWeight: targetWeight,
        fitnessGoal: fitnessGoal,
        trainingLocation: trainingLocation,
        timeAvailability: timeAvailability,
        birthDate: birthDate,
      );
}
