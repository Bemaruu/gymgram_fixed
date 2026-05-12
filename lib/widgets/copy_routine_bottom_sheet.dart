import 'package:flutter/material.dart';
import '../services/routine_service.dart';

class CopyRoutineBottomSheet extends StatefulWidget {
  final Map<String, dynamic> routine;

  const CopyRoutineBottomSheet({super.key, required this.routine});

  @override
  State<CopyRoutineBottomSheet> createState() =>
      _CopyRoutineBottomSheetState();
}

class _CopyRoutineBottomSheetState extends State<CopyRoutineBottomSheet> {
  bool _isCopying = false;
  bool _alreadyCopied = false;
  int? _selectedDay;

  static const _dayNames = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves',
    'Viernes', 'Sábado', 'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    _checkAlreadyCopied();
  }

  Future<void> _checkAlreadyCopied() async {
    final id = widget.routine['id'] as String?;
    if (id == null) return;
    try {
      final copied = await RoutineService.instance.hasCopiedRoutine(id);
      if (mounted) setState(() => _alreadyCopied = copied);
    } catch (_) {}
  }

  Future<void> _copy() async {
    final id = widget.routine['id'] as String?;
    if (id == null) return;
    final dayIndex = widget.routine['day_of_week'] as int?;
    final effectiveDay = dayIndex ?? _selectedDay;
    setState(() => _isCopying = true);
    try {
      final newId = await RoutineService.instance.copyRoutine(id, dayOfWeek: effectiveDay);
      if (!mounted) return;
      setState(() {
        _isCopying = false;
        _alreadyCopied = newId != null;
      });
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
                  newId == null
                      ? 'Esta rutina ya estaba en tu lista'
                      : 'Rutina copiada. Disponible en tu pantalla de Rutina',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(milliseconds: 2500),
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
    final title = widget.routine['title'] as String? ?? 'Rutina';
    final dayIndex = widget.routine['day_of_week'] as int?;
    final dayLabel = (dayIndex != null && dayIndex >= 0 && dayIndex < 7)
        ? _dayNames[dayIndex]
        : null;
    final exercises = (widget.routine['routine_exercises'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final copies = (widget.routine['copies_count'] as int?) ?? 0;

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
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (dayLabel != null) dayLabel,
                        '${exercises.length} ejercicios',
                        if (copies >= 1) '$copies copias',
                      ].join(' · '),
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
                child: exercises.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin ejercicios',
                          style: TextStyle(color: Colors.black38),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        itemCount: exercises.length,
                        itemBuilder: (_, i) {
                          final e = exercises[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00BFFF)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.fitness_center,
                                    color: Color(0xFF00BFFF),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e['name'] as String? ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${e['sets'] ?? '-'} series · ${e['reps'] ?? '-'}',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dayIndex == null) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 0, 0, 10),
                          child: Text(
                            'Elige un día para esta rutina',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: List.generate(7, (i) {
                            final selected = _selectedDay == i;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedDay = i),
                              child: Chip(
                                label: Text(
                                  _dayNames[i],
                                  style: TextStyle(
                                    color: selected ? Colors.white : Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: selected
                                    ? const Color(0xFF00BFFF)
                                    : Colors.grey.shade200,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isCopying || _alreadyCopied || (dayIndex == null && _selectedDay == null)) ? null : _copy,
                      icon: _isCopying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _alreadyCopied
                                  ? Icons.check_circle_rounded
                                  : Icons.copy_rounded,
                              size: 20,
                            ),
                      label: Text(
                        _alreadyCopied ? 'Ya la copiaste' : 'Copiar rutina',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                    ],
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
