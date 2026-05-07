import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final instance = NotificationService._();
  NotificationService._();

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
    await Supabase.instance.client
        .from('profiles')
        .update({'fcm_token': token})
        .eq('id', uid);
  }

  Future<void> _updateToken(String token) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client
        .from('profiles')
        .update({'fcm_token': token})
        .eq('id', uid);
  }

  void _handleForeground(RemoteMessage message) {
    debugPrint('FCM foreground: ${message.notification?.title}');
  }
}
