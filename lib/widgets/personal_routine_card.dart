import 'package:flutter/material.dart';

class PersonalRoutineCard extends StatelessWidget {
  final List<Map<String, dynamic>> routines;
  final bool isOwner;
  final String? ownerUsername;
  final VoidCallback onTap;

  const PersonalRoutineCard({
    super.key,
    required this.routines,
    required this.isOwner,
    required this.onTap,
    this.ownerUsername,
  });

  @override
  Widget build(BuildContext context) {
    final daysWithExercises = routines
        .where((r) => ((r['routine_exercises'] as List?)?.isNotEmpty ?? false))
        .length;
    final totalExercises = routines.fold<int>(
      0,
      (sum, r) => sum + ((r['routine_exercises'] as List?)?.length ?? 0),
    );
    final totalCopies = routines.fold<int>(
      0,
      (sum, r) => sum + ((r['copies_count'] as int?) ?? 0),
    );

    final title = isOwner
        ? 'Mi Rutina Personal'
        : 'Rutina de ${ownerUsername != null ? '@$ownerUsername' : 'usuario'}';

    final subtitle = daysWithExercises == 0
        ? 'Sin ejercicios aún'
        : '$daysWithExercises ${daysWithExercises == 1 ? 'día' : 'días'} · $totalExercises ejercicios';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF00BFFF),
              Color(0xFF0096D6),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFFF).withValues(alpha: 0.20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                  if (totalCopies >= 1) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$totalCopies ${totalCopies == 1 ? "copia" : "copias"}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    isOwner
                        ? 'Toca para ver y editar la semana'
                        : 'Toca para ver y copiar la semana',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
