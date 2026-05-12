import 'package:flutter/material.dart';
import '../services/routine_service.dart';

class CopyPersonalWeekSheet extends StatefulWidget {
  final List<Map<String, dynamic>> routines;
  final String sourceUserId;
  final String? ownerUsername;

  const CopyPersonalWeekSheet({
    super.key,
    required this.routines,
    required this.sourceUserId,
    this.ownerUsername,
  });

  @override
  State<CopyPersonalWeekSheet> createState() => _CopyPersonalWeekSheetState();
}

class _CopyPersonalWeekSheetState extends State<CopyPersonalWeekSheet> {
  static const _dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];

  bool _isCopying = false;

  Future<void> _copy() async {
    setState(() => _isCopying = true);
    try {
      final n = await RoutineService.instance
          .copyPersonalWeek(widget.sourceUserId);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF00BFFF),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n == 0
                      ? 'No había rutinas para copiar'
                      : 'Semana copiada ($n días). Disponible en tu pantalla de Rutina',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2800),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCopying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo copiar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <int, Map<String, dynamic>>{};
    for (final r in widget.routines) {
      final d = r['day_of_week'] as int?;
      if (d != null && d >= 0 && d < 7) byDay[d] = r;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ownerUsername != null
                          ? 'Rutina semanal de @${widget.ownerUsername}'
                          : 'Rutina semanal',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${byDay.length} ${byDay.length == 1 ? "día" : "días"} de entrenamiento',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  itemCount: 7,
                  itemBuilder: (_, i) {
                    final r = byDay[i];
                    final exercises = (r?['routine_exercises'] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        [];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _dayNames[i],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                exercises.isEmpty
                                    ? 'Descanso'
                                    : '${exercises.length} ejercicios',
                                style: TextStyle(
                                  color: exercises.isEmpty
                                      ? Colors.orange.shade700
                                      : const Color(0xFF00BFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (exercises.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              exercises
                                  .map((e) => e['name'] as String? ?? '')
                                  .where((n) => n.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCopying ? null : _copy,
                      icon: _isCopying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.copy_rounded, size: 20),
                      label: const Text(
                        'Copiar semana completa',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
