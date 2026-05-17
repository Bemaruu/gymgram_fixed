import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  final _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _saveToken();
    }
    FirebaseMessaging.instance.onTokenRefresh.listen(_updateToken);
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  Future<void> _saveToken() async {
    final token = await _fcm.getToken();
    if (token == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('device_tokens').upsert({
      'user_id': uid,
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _updateToken(String token) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('device_tokens').upsert({
      'user_id': uid,
      'fcm_token': token,
      'updated_at': DateTime.now().toIso8601String(),
    });
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
