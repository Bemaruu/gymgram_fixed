import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ExerciseCard extends StatelessWidget {
  final String name;
  final int? reps;
  final int? durationSeconds;
  final String gifUrl;
  final int? sets;
  final int? restSeconds;

  const ExerciseCard({
    Key? key,
    required this.name,
    this.reps,
    this.durationSeconds,
    required this.gifUrl,
    this.sets,
    this.restSeconds,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: gifUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, _) => SizedBox(
                  height: 180,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, error, stackTrace) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.broken_image, size: 40)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (sets != null) Text('Series: $sets'),
            if (reps != null) Text('Repeticiones: $reps'),
            if (durationSeconds != null) Text('Duración: ${durationSeconds}s'),
            if (restSeconds != null) Text('Descanso: ${restSeconds}s'),
          ],
        ),
      ),
    );
  }
}
