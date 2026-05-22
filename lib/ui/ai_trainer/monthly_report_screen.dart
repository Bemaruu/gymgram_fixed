import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/subscription_service.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MonthlyReportScreen()),
    );
  }

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  bool _loading = true;
  Map<String, dynamic>? _report;
  SubscriptionTier _tier = SubscriptionTier.free;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tier = await SubscriptionService.instance.currentTier();
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    Map<String, dynamic>? report;
    if (uid != null) {
      report = await _fetchLatest(uid);

      // Si no hay reporte pero el mes anterior ya pudo generarse (dia >= 1)
      // y el usuario es Plus/Premium, intentamos invocar la edge function
      // on-demand una vez. Si tiene exito, refrescamos.
      if (report == null && tier != SubscriptionTier.free) {
        try {
          await client.functions.invoke(
            'generate-monthly-report',
            body: {},
          );
          report = await _fetchLatest(uid);
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _tier = tier;
      _report = report;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _fetchLatest(String uid) async {
    try {
      final row = await Supabase.instance.client
          .from('ai_monthly_summaries')
          .select('month, summary_type, content, generated_at')
          .eq('user_id', uid)
          .order('month', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (_) {
      return null;
    }
  }

  String _nextMonthLabel() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1, 1);
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return months[next.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Mi reporte del mes',
            style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _body(),
    );
  }

  Widget _body() {
    if (_tier == SubscriptionTier.free) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 36, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              const Text(
                'Disponible en Plus y Premium',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Recibe un reporte mensual del entrenador IA al hacerte Plus.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_report == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month,
                  size: 36, color: AppColors.primary.withValues(alpha: 0.8)),
              const SizedBox(height: 12),
              Text(
                'Tu reporte estara disponible el 1 de ${_nextMonthLabel()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sigue registrando entrenamientos y respondiendo el check-in semanal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    final content = _report!['content'] as String? ?? '';
    final isFull = _report!['summary_type'] == 'premium_full';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFull ? AppColors.accentOrange : AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isFull ? 'Reporte Premium' : 'Reporte Plus',
              style: TextStyle(
                color: isFull ? Colors.white : AppColors.deepBlue,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
