enum MessageStatus { sent, delivered, read }

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final MessageStatus status;
  final DateTime? readAt;
  final bool isDeleted;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.status,
    required this.readAt,
    required this.isDeleted,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> m) {
    return Message(
      id: m['id'] as String,
      chatId: m['chat_id'] as String,
      senderId: m['sender_id'] as String,
      receiverId: m['receiver_id'] as String,
      text: (m['text'] as String?) ?? '',
      status: _parseStatus(m['status'] as String?),
      readAt: _parseTs(m['read_at']),
      isDeleted: (m['is_deleted'] as bool?) ?? false,
      createdAt: _parseTs(m['created_at']) ?? DateTime.now(),
    );
  }

  static MessageStatus _parseStatus(String? s) {
    switch (s) {
      case 'read':      return MessageStatus.read;
      case 'delivered': return MessageStatus.delivered;
      default:          return MessageStatus.sent;
    }
  }

  static DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
