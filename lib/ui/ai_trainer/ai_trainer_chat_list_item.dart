import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/ai_trainer_service.dart';
import 'ai_trainer_avatars.dart';

/// Item pinneado del entrenador IA en la lista de chats.
/// Solo se muestra para usuarios Premium.
class AITrainerChatListItem extends StatelessWidget {
  final AITrainerConfig config;
  final VoidCallback onTap;
  final String? lastMessagePreview;

  const AITrainerChatListItem({
    super.key,
    required this.config,
    required this.onTap,
    this.lastMessagePreview,
  });

  @override
  Widget build(BuildContext context) {
    final preview = (lastMessagePreview ?? '').trim().isEmpty
        ? 'Tu coach esta listo para conversar'
        : lastMessagePreview!.trim();
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accentOrange.withValues(alpha: 0.08),
              Colors.transparent,
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Icon(PhosphorIconsFill.pushPin,
                size: 14, color: AppColors.accentOrange),
            const SizedBox(width: 8),
            AITrainerAvatars.circle(id: config.avatarId, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        config.trainerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'IA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                    ),
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
