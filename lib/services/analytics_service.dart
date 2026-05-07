import 'package:mixpanel_flutter/mixpanel_flutter.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  AnalyticsService._();

  Mixpanel? _mp;

  Future<void> init(String token) async {
    _mp = await Mixpanel.init(token, trackAutomaticEvents: true);
    _mp?.setLoggingEnabled(false);
  }

  // Asocia todos los eventos futuros al usuario autenticado
  void identify(String userId, {String? username, String? fitnessGoal}) {
    _mp?.identify(userId);
    final people = _mp?.getPeople();
    if (username != null) people?.set(r'$username', username);
    if (fitnessGoal != null) people?.set('fitness_goal', fitnessGoal);
  }

  // Limpia identidad al cerrar sesión
  void reset() => _mp?.reset();

  // Método genérico de tracking
  void track(String event, {Map<String, dynamic>? props}) {
    _mp?.track(event, properties: props);
  }

  // ── Eventos de autenticación ──────────────────────────────────────────────

  void loginSuccess() => track('login');

  void signupCompleted({
    required String fitnessGoal,
    required String trainingLocation,
    required String gender,
  }) =>
      track('signup_completed', props: {
        'fitness_goal': fitnessGoal,
        'training_location': trainingLocation,
        'gender': gender,
      });

  // ── Eventos del feed ──────────────────────────────────────────────────────

  void feedViewed() => track('feed_viewed');

  void postLiked(String postId) =>
      track('post_liked', props: {'post_id': postId});

  void postUnliked(String postId) =>
      track('post_unliked', props: {'post_id': postId});

  void commentSent(String postId) =>
      track('comment_sent', props: {'post_id': postId});

  // ── Eventos de posts ──────────────────────────────────────────────────────

  void postDetailViewed(String postId) =>
      track('post_detail_viewed', props: {'post_id': postId});

  void postCreated({required bool hasCaption}) =>
      track('post_created', props: {'has_caption': hasCaption});

  void postDeleted(String postId) =>
      track('post_deleted', props: {'post_id': postId});

  void postEdited(String postId) =>
      track('post_edited', props: {'post_id': postId});

  // ── Eventos de perfil y social ────────────────────────────────────────────

  void ownProfileViewed() => track('own_profile_viewed');

  void userProfileViewed(String targetUserId) =>
      track('user_profile_viewed', props: {'target_user_id': targetUserId});

  void followAction(String targetUserId) =>
      track('follow', props: {'target_user_id': targetUserId});

  void unfollowAction(String targetUserId) =>
      track('unfollow', props: {'target_user_id': targetUserId});

  // ── Eventos de navegación ─────────────────────────────────────────────────

  void tabChanged(String tabName) =>
      track('tab_changed', props: {'tab': tabName});

  // ── Eventos de búsqueda ───────────────────────────────────────────────────

  void searchPerformed(String query, int resultsCount) =>
      track('search_performed', props: {
        'query_length': query.length,
        'results_count': resultsCount,
      });

  // ── Eventos de pantallas específicas ─────────────────────────────────────

  void routineScreenViewed() => track('routine_screen_viewed');

  void nutritionScreenViewed() => track('nutrition_screen_viewed');

  void medalViewed(String badgeId) =>
      track('medal_viewed', props: {'badge_id': badgeId});
}
