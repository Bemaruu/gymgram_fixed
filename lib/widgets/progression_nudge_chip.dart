import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Chip pequeno (no intrusivo) que indica un nudge de progresion.
/// Al tocarlo, muestra un bottom sheet con el mensaje completo.
/// Estilo solido (no translucido) siguiendo la guia visual de Ranked.
class ProgressionNudgeChip extends StatelessWidget {
  final String nudgeType;
  final String nudgeMessage;

  const ProgressionNudgeChip({
    super.key,
    required this.nudgeType,
    required this.nudgeMessage,
  });

  ({Color bg, Color fg, IconData icon, String label}) _styleFor(String type) {
    switch (type) {
      case 'increase_weight':
        return (
          bg: const Color(0xFF1B5E20),
          fg: Colors.white,
          icon: PhosphorIconsFill.arrowUp,
          label: 'Subir peso',
        );
      case 'add_set':
        return (
          bg: const Color(0xFF00BFFF),
          fg: Colors.white,
          icon: PhosphorIconsFill.plusCircle,
          label: '+1 serie',
        );
      case 'deload':
        return (
          bg: const Color(0xFFB78103),
          fg: Colors.white,
          icon: PhosphorIconsFill.batteryLow,
          label: 'Deload',
        );
      case 'return_after_break':
        return (
          bg: const Color(0xFF5D4037),
          fg: Colors.white,
          icon: PhosphorIconsFill.clockCounterClockwise,
          label: 'Vuelta',
        );
      case 'failed_reps':
        return (
          bg: const Color(0xFFC62828),
          fg: Colors.white,
          icon: PhosphorIconsFill.warning,
          label: 'Baja peso',
        );
      default:
        return (
          bg: const Color(0xFF455A64),
          fg: Colors.white,
          icon: PhosphorIconsRegular.info,
          label: 'Aviso',
        );
    }
  }

  void _showSheet(BuildContext context, String label, IconData icon, Color bg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                nudgeMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      color: Color(0xFF00BFFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _styleFor(nudgeType);
    return GestureDetector(
      onTap: () => _showSheet(context, s.label, s.icon, s.bg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 12, color: s.fg),
            const SizedBox(width: 4),
            Text(
              s.label,
              style: TextStyle(
                color: s.fg,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
