import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'subscription_service.dart';

class AITrainerConfig {
  final String trainerName;
  final String avatarId;
  final String tone;
  final String focus;

  const AITrainerConfig({
    required this.trainerName,
    required this.avatarId,
    required this.tone,
    required this.focus,
  });

  factory AITrainerConfig.defaults() => const AITrainerConfig(
        trainerName: 'Coach',
        avatarId: 'avatar_1',
        tone: 'motivador',
        focus: 'ambos',
      );

  factory AITrainerConfig.fromRow(Map<String, dynamic> r) => AITrainerConfig(
        trainerName: (r['trainer_name'] as String?) ?? 'Coach',
        avatarId: (r['avatar_id'] as String?) ?? 'avatar_1',
        tone: (r['tone'] as String?) ?? 'motivador',
        focus: (r['focus'] as String?) ?? 'ambos',
      );
}

class AITrainerService {
  static final AITrainerService instance = AITrainerService._();
  AITrainerService._();

  static const int dailyMessageLimit = 10;

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  Future<AITrainerConfig?> getConfig() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from('ai_trainer_config')
          .select('trainer_name, avatar_id, tone, focus')
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return AITrainerConfig.fromRow(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig({
    required String name,
    required String avatarId,
    required String tone,
    required String focus,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('ai_trainer_config').upsert({
      'user_id': uid,
      'trainer_name': name,
      'avatar_id': avatarId,
      'tone': tone,
      'focus': focus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }

  Future<List<Map<String, dynamic>>> getMessages({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('ai_trainer_messages')
          .select('id, role, content, message_type, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(rows);
      return list.reversed.toList();
    } catch (e) {
      debugPrint('AITrainerService.getMessages error: $e');
      return [];
    }
  }

  /// Envia un mensaje al coach IA. Llama a la edge function `ai-trainer-chat`
  /// que (a) valida tier/cuota, (b) inserta el msg user, (c) genera la respuesta
  /// con GPT-4o-mini, (d) inserta la respuesta assistant.
  ///
  /// Devuelve null si todo fue bien, o un mensaje de error para mostrar al usuario.
  /// Si la edge function falla, usa el RPC `insert_ai_message` como fallback
  /// (valida tier y cuota server-side) y genera una respuesta mock local.
  Future<String?> sendMessage(String content, {String type = 'chat'}) async {
    final uid = _uid;
    if (uid == null) return null;

    if (type == 'chat') {
      try {
        final res = await _client.functions.invoke(
          'ai-trainer-chat',
          body: {'content': content},
        );
        if (res.status == 200) return null;
        if (kDebugMode) debugPrint('ai-trainer-chat non-200: ${res.status} ${res.data}');
      } catch (e) {
        if (kDebugMode) debugPrint('ai-trainer-chat invoke error: $e');
      }
    }

    // Fallback: usar RPC server-side que valida tier y cuota antes de insertar.
    try {
      await _client.rpc('insert_ai_message', params: {
        'p_content': content,
        'p_message_type': type,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('AITrainerService.sendMessage rpc error: $e');
      final msg = e.toString();
      if (msg.contains('Premium required')) {
        return 'Necesitas Premium para chatear con el coach.';
      }
      if (msg.contains('Daily limit reached')) {
        return 'Llegaste al limite diario de mensajes.';
      }
      return 'El coach no esta disponible ahora, intenta mas tarde.';
    }

    final config = await getConfig() ?? AITrainerConfig.defaults();
    final mock = getMockResponse(content, type, tone: config.tone);
    try {
      await _client.from('ai_trainer_messages').insert({
        'user_id': uid,
        'role': 'assistant',
        'content': mock,
        'message_type': type,
      });
    } catch (e) {
      // RLS bloquea insert role='assistant' desde cliente. Si la edge function
      // esta funcionando, este branch nunca se ejecuta.
      if (kDebugMode) debugPrint('AITrainerService mock assistant insert blocked: $e');
    }
    return null;
  }

  Future<int> dailyMessagesUsed() async {
    final uid = _uid;
    if (uid == null) return 0;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    try {
      final rows = await _client
          .from('ai_trainer_messages')
          .select('id')
          .eq('user_id', uid)
          .eq('role', 'user')
          .gte('created_at', startOfDay.toIso8601String());
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> canSendMessage() async {
    final tier = await SubscriptionService.instance.currentTier();
    if (tier != SubscriptionTier.premium) return false;
    final used = await dailyMessagesUsed();
    return used < dailyMessageLimit;
  }

  /// Respuesta mockeada por ahora. La edge function `ai-trainer-chat`
  /// reemplazara este metodo cuando este desplegada.
  String getMockResponse(String userMessage, String type, {String tone = 'motivador'}) {
    final rng = Random();
    final byTone = _mockBank[tone] ?? _mockBank['motivador']!;
    final pool = byTone[type] ?? byTone['chat']!;
    return pool[rng.nextInt(pool.length)];
  }

  static const Map<String, Map<String, List<String>>> _mockBank = {
    'motivador': {
      'chat': [
        'Excelente! Sigamos asi, vas por buen camino. Que es lo que mas te cuesta esta semana?',
        'Recuerda: la constancia gana siempre. Como va tu energia hoy?',
        'Me encanta tu compromiso. Que quieres priorizar esta semana?',
      ],
      'post_workout': [
        'Brutal sesion! Que sentiste mas fuerte: piernas, espalda o pecho?',
        'Buen trabajo. Como esta tu recuperacion? Recuerda hidratarte bien.',
        'Eso es lo que queremos ver. Manana toca descanso activo o full rest?',
      ],
      'weekly_checkin': [
        'Gracias por contarme. Lo tendre en cuenta para tu reporte mensual.',
        'Anotado. Sigamos ajustando para que rindas al maximo.',
      ],
    },
    'directo': {
      'chat': [
        'Vamos al grano: que necesitas resolver hoy?',
        'Bien. Que vas a entrenar y a que hora?',
        'Mantente firme con el plan. Que dudas tienes?',
      ],
      'post_workout': [
        'Listo. Como sentiste la intensidad? Del 1 al 10.',
        'Buena. Dieta hoy: cumpliste proteina?',
        'Bien. Manana mismo plan o ajustamos algo?',
      ],
      'weekly_checkin': [
        'Anotado. Lo aplico al reporte.',
        'Recibido. Seguimos.',
      ],
    },
    'relajado': {
      'chat': [
        'Tranquilo, vamos a tu ritmo. Que tal el dia?',
        'Suena bien. Recuerda que sin estres tambien se progresa.',
        'Cuentame, sin presion. Como te sientes con el plan?',
      ],
      'post_workout': [
        'Buenisimo. Como te sentiste? Sin apurar nada.',
        'Bien hecho. Recuerda escuchar al cuerpo.',
        'Listo, descansa rico. Eso tambien es entrenar.',
      ],
      'weekly_checkin': [
        'Gracias por compartirlo. Vamos sumando datos.',
        'Anotado, con calma.',
      ],
    },
    'exigente': {
      'chat': [
        'Sin excusas. Que vas a entregar hoy?',
        'El plan se cumple completo, no a medias. Donde estas?',
        'Apunta mas alto: que vas a mejorar esta semana?',
      ],
      'post_workout': [
        'Le dejaste todo? Si no, manana mejor.',
        'Bien. Pero podemos mas. Como manejaste las series finales?',
        'Buena. Ahora dormir 8 horas. No es opcional.',
      ],
      'weekly_checkin': [
        'Anotado. Espero mejores numeros la proxima.',
        'Recibido. Vamos por mas.',
      ],
    },
  };
}
