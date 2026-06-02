import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/ranked/ranked_screen.dart';
import '../ui/ranked/match/match_screen.dart';

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  final _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Solicitar permiso (Android 13+ lo necesita declarado en el manifest).
    // El token se guarda independientemente — el permiso solo controla si el
    // sistema muestra la UI de la notificación, no si se puede recibir.
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _saveToken();
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateToken);
    FirebaseMessaging.onMessage.listen(_handleForeground);
    // Tap en la notificación (app en background o cerrada).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNavigation);
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleNavigation(initial);
  }

  /// Envía una notificación push a otro usuario vía la edge function send-push.
  Future<void> sendPushToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke('send-push-notification', body: {
        'user_id': userId,
        'title': title,
        'body': body,
        if (data != null) 'data': data,
      });
    } catch (e) {
      debugPrint('sendPushToUser error: $e');
    }
  }

  void _handleNavigation(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final nav = navigatorKey.currentState;
    if (nav == null || type == null) return;
    switch (type) {
      case 'match_challenge':
        nav.push(MaterialPageRoute(builder: (_) => const RankedScreen()));
        break;
      case 'match_turn':
      case 'match_started':
        final matchId = data['match_id'];
        if (matchId != null && matchId.isNotEmpty) {
          nav.push(MaterialPageRoute(
              builder: (_) => MatchScreen(matchId: matchId)));
        }
        break;
    }
  }

  Future<void> _saveToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        if (kDebugMode) debugPrint('FCM getToken() returned null');
        return;
      }
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client.from('device_tokens').upsert(
        {'user_id': uid, 'fcm_token': token, 'updated_at': DateTime.now().toIso8601String()},
        onConflict: 'user_id',
      );
      if (kDebugMode) debugPrint('[FCM] token registered (len=${token.length}) for $uid');
    } catch (e) {
      debugPrint('_saveToken error: $e');
    }
  }

  Future<void> _updateToken(String token) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client.from('device_tokens').upsert(
        {'user_id': uid, 'fcm_token': token, 'updated_at': DateTime.now().toIso8601String()},
        onConflict: 'user_id',
      );
    } catch (e) {
      debugPrint('_updateToken error: $e');
    }
  }

  void _handleForeground(RemoteMessage message) {
    if (kDebugMode) debugPrint('FCM foreground: ${message.notification?.title}');
    final notif = message.notification;
    if (notif == null) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1C1C1E),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notif.title != null)
              Text(
                notif.title!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            if (notif.body != null)
              Text(notif.body!, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
