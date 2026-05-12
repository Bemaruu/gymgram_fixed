class Chat {
  final String id;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;

  Chat({
    required this.id,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
    required this.unreadCount,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherAvatarUrl,
  });

  factory Chat.fromRow({
    required Map<String, dynamic> chatRow,
    required Map<String, dynamic> participantRow,
    required Map<String, dynamic> otherProfile,
  }) {
    return Chat(
      id: chatRow['id'] as String,
      lastMessage: chatRow['last_message'] as String?,
      lastMessageAt: _parseTs(chatRow['last_message_at']),
      createdAt: _parseTs(chatRow['created_at']) ?? DateTime.now(),
      updatedAt: _parseTs(chatRow['updated_at']) ?? DateTime.now(),
      unreadCount: (participantRow['unread_count'] as int?) ?? 0,
      otherUserId: otherProfile['id'] as String? ?? '',
      otherUsername: otherProfile['username'] as String? ?? '',
      otherAvatarUrl: otherProfile['avatar_url'] as String?,
    );
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
