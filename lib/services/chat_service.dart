import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import '../models/message.dart';

/// Servicio de mensajería 1:1 sobre Supabase.
/// Toda mutación pasa por RPCs (rate-limit + anti-bloqueo en el servidor).
class ChatService {
  static final ChatService instance = ChatService._();
  ChatService._();

  static const int messagesPageSize = 30;
  static const int maxMessageLength = 1000;

  final _client = Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  // ── Lista de chats ───────────────────────────────────────────────────────

  /// Devuelve los chats del usuario actual con datos del otro participante.
  Future<List<Chat>> listChats() async {
    final uid = _uid;
    if (uid == null) return [];

    // 1) Mis filas en chat_participants con el chat embebido.
    final myRows = await _client
        .from('chat_participants')
        .select('chat_id, unread_count, chats(id, last_message, last_message_at, created_at, updated_at)')
        .eq('user_id', uid);

    final myList = List<Map<String, dynamic>>.from(myRows as List);
    if (myList.isEmpty) return [];

    final chatIds = myList.map((r) => r['chat_id'] as String).toList();

    // 2) Otros participantes (uno por chat en 1:1) con su perfil embebido.
    final otherRows = await _client
        .from('chat_participants')
        .select('chat_id, user_id, profiles(id, username, avatar_url)')
        .inFilter('chat_id', chatIds)
        .neq('user_id', uid);

    final othersByChat = <String, Map<String, dynamic>>{};
    for (final r in (otherRows as List)) {
      final cid = r['chat_id'] as String;
      othersByChat[cid] = Map<String, dynamic>.from(r as Map);
    }

    final chats = <Chat>[];
    for (final my in myList) {
      final cid = my['chat_id'] as String;
      final chatRow = my['chats'] as Map<String, dynamic>?;
      final other = othersByChat[cid];
      if (chatRow == null || other == null) continue;
      final profile = (other['profiles'] as Map?) ?? const {};
      chats.add(
        Chat.fromRow(
          chatRow: chatRow,
          participantRow: my,
          otherProfile: Map<String, dynamic>.from(profile),
        ),
      );
    }

    chats.sort((a, b) {
      final ad = a.lastMessageAt ?? a.updatedAt;
      final bd = b.lastMessageAt ?? b.updatedAt;
      return bd.compareTo(ad);
    });
    return chats;
  }

  /// Total de chats con mensajes no leídos para badge global.
  Future<int> getTotalUnread() async {
    final uid = _uid;
    if (uid == null) return 0;
    final rows = await _client
        .from('chat_participants')
        .select('unread_count')
        .eq('user_id', uid)
        .gt('unread_count', 0);
    return (rows as List).length;
  }

  // ── Crear / abrir chat ───────────────────────────────────────────────────

  Future<String> findOrCreateChat(String otherUserId) async {
    final res = await _client.rpc(
      'find_or_create_chat',
      params: {'p_other_user_id': otherUserId},
    );
    return res as String;
  }

  // ── Mensajes ─────────────────────────────────────────────────────────────

  /// Carga mensajes paginados (más reciente primero).
  /// [before] = fecha del mensaje más antiguo ya cargado.
  Future<List<Message>> loadMessages(
    String chatId, {
    DateTime? before,
    int limit = messagesPageSize,
  }) async {
    var q = _client
        .from('messages')
        .select('id, chat_id, sender_id, receiver_id, text, status, read_at, is_deleted, created_at')
        .eq('chat_id', chatId);
    if (before != null) {
      q = q.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .map((r) => Message.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> sendMessage(String chatId, String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    if (clean.length > maxMessageLength) {
      throw Exception('Mensaje demasiado largo');
    }
    await _client.rpc('send_message', params: {
      'p_chat_id': chatId,
      'p_text': clean,
    });
  }

  Future<void> markChatRead(String chatId) async {
    await _client.rpc('mark_chat_read', params: {'p_chat_id': chatId});
  }

  Future<void> softDeleteMessage(String messageId) async {
    await _client.rpc('soft_delete_message', params: {'p_message_id': messageId});
  }

  // ── Realtime ─────────────────────────────────────────────────────────────

  /// Suscribe a nuevos mensajes de un chat. Devuelve el canal para dispose.
  RealtimeChannel subscribeToChat(
    String chatId, {
    required void Function(Message) onInsert,
  }) {
    final channel = _client.channel('messages:$chatId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'chat_id',
          value: chatId,
        ),
        callback: (payload) {
          try {
            final msg = Message.fromMap(
              Map<String, dynamic>.from(payload.newRecord),
            );
            onInsert(msg);
          } catch (e) {
            if (kDebugMode) debugPrint('Realtime message parse error: $e');
          }
        },
      )
      ..subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    try {
      await _client.removeChannel(channel);
    } catch (e) {
      if (kDebugMode) debugPrint('Unsubscribe error: $e');
    }
  }

  // ── Bloqueo y reporte ────────────────────────────────────────────────────

  Future<void> blockUser(String otherUserId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from('blocked_users').insert({
      'blocker_id': uid,
      'blocked_id': otherUserId,
    });
  }

  Future<void> unblockUser(String otherUserId) async {
    final uid = _uid;
    if (uid == null) return;
    await _client
        .from('blocked_users')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', otherUserId);
  }

  Future<bool> isBlocked(String otherUserId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _client
        .from('blocked_users')
        .select('blocker_id')
        .eq('blocker_id', uid)
        .eq('blocked_id', otherUserId)
        .maybeSingle();
    return row != null;
  }

  Future<void> reportUser({
    required String targetUserId,
    String? targetMessageId,
    required String reason,
  }) async {
    final clean = reason.trim();
    if (clean.isEmpty) return;
    if (clean.length > 1000) throw Exception('Motivo demasiado largo');
    await _client.rpc('create_report', params: {
      'p_target_user_id': targetUserId,
      'p_target_message_id': targetMessageId,
      'p_reason': clean,
    });
  }
}
