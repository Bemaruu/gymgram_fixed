import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/routine_service.dart';

/// Banner que muestra la opinión IA sobre la rutina importada del usuario
/// (source='user_imported'). Si no hay análisis aún, ofrece un botón para
/// pedirlo. Si ya hay, muestra summary + warnings + suggestions en un panel
/// expandible.
///
/// La edge function `analyze-routine` ya persiste el resultado en
/// `routines.routine_analysis`. Tras pedir un análisis nuevo, se invoca
/// `onAnalysisUpdated` para que la pantalla recargue su estado.
class RoutineAnalysisBanner extends StatefulWidget {
  const RoutineAnalysisBanner({
    super.key,
    required this.analysis,
    required this.onAnalysisUpdated,
    this.onDismiss,
  });

  /// Contenido del campo `routine_analysis`. Puede ser null o un map con
  /// `status` ('pending' | 'completed') y los campos summary/strengths/...
  final Map<String, dynamic>? analysis;

  /// Llamado tras un análisis exitoso con el nuevo payload.
  final ValueChanged<Map<String, dynamic>> onAnalysisUpdated;

  /// Llamado cuando el usuario toca la X para cerrar el banner. Si es null,
  /// la X no se muestra.
  final VoidCallback? onDismiss;

  @override
  State<RoutineAnalysisBanner> createState() => _RoutineAnalysisBannerState();
}

class _RoutineAnalysisBannerState extends State<RoutineAnalysisBanner> {
  bool _loading = false;

  bool get _isCompleted => widget.analysis?['status'] == 'completed';

  Future<void> _request() async {
    setState(() => _loading = true);
    final result = await RoutineService.instance.requestRoutineAnalysis();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos obtener la opinión IA. Intenta más tarde.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final updated = {
      'status': 'completed',
      ...result,
    };
    widget.onAnalysisUpdated(updated);
    if (!mounted) return;
    _showDetailSheet(updated);
  }

  void _showDetailSheet(Map<String, dynamic> a) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AnalysisDetailSheet(analysis: a),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showDismiss = widget.onDismiss != null && _isCompleted;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.accentOrange.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 14, showDismiss ? 36 : 14, 14),
            child: _isCompleted ? _buildCompleted() : _buildPending(),
          ),
          if (showDismiss)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: Colors.black54),
                onPressed: widget.onDismiss,
                visualDensity: VisualDensity.compact,
                splashRadius: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPending() {
    return Row(
      children: [
        Icon(Icons.psychology_alt_outlined,
            color: AppColors.primary, size: 28),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu rutina, opinión IA',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87),
              ),
              SizedBox(height: 2),
              Text(
                'Pide un análisis de cobertura muscular, advertencias y sugerencias.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _request,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Pedir análisis',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildCompleted() {
    final a = widget.analysis!;
    final summary = a['summary']?.toString() ?? '';
    final warnings = (a['warnings'] as List?)?.cast<dynamic>() ?? const [];
    final hasHigh = warnings.any(
        (w) => w is Map && w['severity']?.toString() == 'high');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasHigh ? Icons.warning_amber_rounded : Icons.verified_outlined,
              color: hasHigh ? Colors.orange.shade800 : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Opinión IA sobre tu rutina',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87),
              ),
            ),
            IconButton(
              tooltip: 'Volver a analizar',
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _loading ? null : _request,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          summary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 12.5, color: Colors.black87, height: 1.35),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showDetailSheet(a),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
            ),
            child: Text(
              'Ver detalle',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sheet con el detalle completo del análisis IA. Scrollable y limitado a
/// 80% de la altura de la pantalla.
class _AnalysisDetailSheet extends StatelessWidget {
  const _AnalysisDetailSheet({required this.analysis});
  final Map<String, dynamic> analysis;

  String _severityIcon(String sev) {
    switch (sev) {
      case 'high':
        return '🚨';
      case 'medium':
        return '⚠️';
      default:
        return 'ℹ️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = analysis['summary']?.toString() ?? '';
    final strengths =
        (analysis['strengths'] as List?)?.cast<dynamic>() ?? const [];
    final warnings =
        (analysis['warnings'] as List?)?.cast<dynamic>() ?? const [];
    final suggestions =
        (analysis['suggestions'] as List?)?.cast<dynamic>() ?? const [];
    final hasHigh = warnings.any(
        (w) => w is Map && w['severity']?.toString() == 'high');
    final maxH = MediaQuery.of(context).size.height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    hasHigh
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: hasHigh ? Colors.orange.shade800 : AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Opinión IA sobre tu rutina',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (summary.isNotEmpty)
                        Text(
                          summary,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                              height: 1.4),
                        ),
                      if (warnings.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section(
                          'Advertencias',
                          warnings.map((w) {
                            if (w is Map) {
                              final sev =
                                  w['severity']?.toString() ?? 'low';
                              final text = w['text']?.toString() ?? '';
                              return '${_severityIcon(sev)} $text';
                            }
                            return w.toString();
                          }).toList(),
                          color: Colors.orange.shade900,
                        ),
                      ],
                      if (strengths.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section(
                          'Fortalezas',
                          strengths
                              .map((s) => '• ${s.toString()}')
                              .toList(),
                          color: Colors.green.shade800,
                        ),
                      ],
                      if (suggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _section(
                          'Sugerencias',
                          suggestions
                              .map((s) => '• ${s.toString()}')
                              .toList(),
                          color: AppColors.primary,
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<String> items, {required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              t,
              style: const TextStyle(
                  fontSize: 12.5, color: Colors.black87, height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}
