import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/chat.dart';
import 'unread_badge.dart';

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  const ChatListItem({super.key, required this.chat, required this.onTap});

  String _formatTime(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final local = d.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} d';
    return '${local.day}/${local.month}';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.unreadCount > 0;
    final initial = chat.otherUsername.isNotEmpty
        ? chat.otherUsername[0].toUpperCase()
        : '?';
    final preview = (chat.lastMessage ?? '').trim();
    final timeLabel = _formatTime(chat.lastMessageAt);

    final avatar = chat.otherAvatarUrl;
    final hasValidAvatar = avatar != null && avatar.startsWith('https://');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                color: hasUnread ? const Color(0xFF00BFFF) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF00BFFF).withValues(alpha: 0.18),
              backgroundImage: hasValidAvatar ? CachedNetworkImageProvider(avatar) : null,
              child: !hasValidAvatar
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: Color(0xFF00BFFF),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.otherUsername.isNotEmpty
                              ? '@${chat.otherUsername}'
                              : 'Usuario',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: hasUnread ? const Color(0xFF00BFFF) : Colors.white54,
                            fontSize: 11.5,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview.isEmpty ? 'Inicia la conversación' : preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? Colors.white : Colors.white60,
                            fontSize: 13.5,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        UnreadBadge(count: chat.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
