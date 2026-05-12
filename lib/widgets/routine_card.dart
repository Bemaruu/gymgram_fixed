import 'package:flutter/material.dart';

class RoutineCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final bool isOwner;
  final VoidCallback? onTap;

  const RoutineCard({
    super.key,
    required this.routine,
    required this.isOwner,
    this.onTap,
  });

  static const _dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];

  String _formatGoal(String? g) {
    switch ((g ?? '').toUpperCase()) {
      case 'LOSE_WEIGHT':
        return 'Perder peso';
      case 'GAIN_MUSCLE':
        return 'Ganar músculo';
      case 'MAINTAIN':
        return 'Mantener';
      default:
        return 'Sin objetivo';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = routine['title'] as String? ?? 'Rutina';
    final goal = _formatGoal(routine['goal'] as String?);
    final dayIndex = routine['day_of_week'] as int?;
    final dayLabel = (dayIndex != null && dayIndex >= 0 && dayIndex < 7)
        ? _dayNames[dayIndex]
        : null;
    final exercises =
        (routine['routine_exercises'] as List?)?.length ?? 0;
    final copies = (routine['copies_count'] as int?) ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Color(0xFF00BFFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (dayLabel != null) dayLabel,
                      goal,
                      '$exercises ejercicios',
                    ].join(' · '),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (copies >= 1) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: Color(0xFF00BFFF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$copies copias',
                          style: const TextStyle(
                            color: Color(0xFF00BFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!isOwner)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.copy_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Copiar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
