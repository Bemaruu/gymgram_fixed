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
  List<Map<String, dynamic>> _reports = [];
  int _selected = 0;
  SubscriptionTier _tier = SubscriptionTier.free;

  static const _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tier = await SubscriptionService.instance.currentTier();
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    var reports = <Map<String, dynamic>>[];
    if (uid != null) {
      reports = await _fetchAll(uid);
      // Si no hay ninguno y el usuario paga, intentamos generar el del mes
      // pasado on-demand una vez (el cron normalmente ya lo hizo el dia 1).
      if (reports.isEmpty && tier != SubscriptionTier.free) {
        try {
          await client.functions.invoke('generate-monthly-report', body: {});
          reports = await _fetchAll(uid);
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _tier = tier;
      _reports = reports;
      _selected = 0;
      _loading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAll(String uid) async {
    try {
      final rows = await Supabase.instance.client
          .from('ai_monthly_summaries')
          .select('month, summary_type, content, stats, generated_at')
          .eq('user_id', uid)
          .order('month', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  String _monthLabel(String? monthIso, {bool withYear = true}) {
    final d = DateTime.tryParse(monthIso ?? '');
    if (d == null) return 'Mes';
    final name = _months[d.month - 1];
    final cap = '${name[0].toUpperCase()}${name.substring(1)}';
    return withYear ? '$cap ${d.year}' : cap;
  }

  String _nextMonthLabel() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1, 1);
    return _months[next.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Mis reportes', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _body(),
    );
  }

  Widget _body() {
    if (_tier == SubscriptionTier.free) {
      return _emptyState(
        icon: Icons.lock_outline,
        title: 'Disponible en Plus y Premium',
        subtitle: 'Recibe un reporte mensual del entrenador IA al hacerte Plus.',
      );
    }
    if (_reports.isEmpty) {
      return _emptyState(
        icon: Icons.calendar_month,
        title: 'Tu reporte estará disponible el 1 de ${_nextMonthLabel()}',
        subtitle:
            'Sigue registrando entrenamientos y comidas, y responde el check-in semanal. '
            'Generamos el reporte cuando hay suficientes datos para que sea útil.',
        accent: true,
      );
    }

    final report = _reports[_selected];
    return Column(
      children: [
        if (_reports.length > 1) _monthSelector(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tierBadge(report),
                const SizedBox(height: 14),
                _statsCards(report['stats']),
                _narrative((report['content'] as String?) ?? ''),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _monthSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == _selected;
          return GestureDetector(
            onTap: () => setState(() => _selected = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.darkSurfaceCard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.darkBorder,
                ),
              ),
              child: Text(
                _monthLabel(_reports[i]['month'] as String?),
                style: TextStyle(
                  color: selected ? AppColors.deepBlue : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tierBadge(Map<String, dynamic> report) {
    final isFull = report['summary_type'] == 'premium_full';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        const SizedBox(width: 8),
        Text(
          _monthLabel(report['month'] as String?),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // ── Tarjetas de métricas (deterministas, desde stats) ──────────────────────
  Widget _statsCards(dynamic statsRaw) {
    if (statsRaw is! Map) return const SizedBox.shrink();
    final stats = Map<String, dynamic>.from(statsRaw);
    final training = (stats['training'] as Map?)?.cast<String, dynamic>() ?? {};
    final nutrition = (stats['nutrition'] as Map?)?.cast<String, dynamic>() ?? {};

    final cards = <Widget>[];

    final sessions = training['sessions'];
    if (sessions is num && sessions > 0) {
      cards.add(_metricCard('Entrenamientos', '$sessions', Icons.fitness_center));
    }
    final volume = training['total_volume_kg'];
    if (volume is num && volume > 0) {
      cards.add(_metricCard('Volumen total', '${_compact(volume)} kg', Icons.monitor_weight_outlined));
    }
    final days = nutrition['days_logged'];
    if (days is num && days > 0) {
      cards.add(_metricCard('Días con comida', '$days', Icons.restaurant_outlined));
    }
    final kcal = nutrition['avg_kcal'];
    if (kcal is num && kcal > 0) {
      final adh = nutrition['kcal_adherence_pct'];
      cards.add(_metricCard(
        'Kcal promedio',
        '$kcal',
        Icons.local_fire_department_outlined,
        sub: adh is num ? '$adh% de tu meta' : null,
      ));
    }
    final protein = nutrition['avg_protein'];
    if (protein is num && protein > 0) {
      final adh = nutrition['protein_adherence_pct'];
      cards.add(_metricCard(
        'Proteína prom.',
        '${protein}g',
        Icons.egg_outlined,
        sub: adh is num ? '$adh% de tu meta' : null,
      ));
    }
    final checkins = stats['checkins'];
    if (checkins is num && checkins > 0) {
      cards.add(_metricCard('Check-ins', '$checkins', Icons.checklist_rtl));
    }

    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Wrap(spacing: 10, runSpacing: 10, children: cards),
    );
  }

  String _compact(num v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }

  Widget _metricCard(String label, String value, IconData icon, {String? sub}) {
    return Container(
      width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  // ── Render markdown ligero (sin paquetes): ## títulos, - bullets, **bold** ──
  Widget _narrative(String content) {
    final widgets = <Widget>[];
    for (final raw in content.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(line.substring(3).trim(),
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(line.substring(2).trim(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ));
      } else if (line.trimLeft().startsWith('- ') ||
          line.trimLeft().startsWith('* ')) {
        final t = line.trimLeft().substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Icon(Icons.circle, size: 5, color: AppColors.primary),
              ),
              Expanded(child: _inline(t)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _inline(line),
        ));
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets),
    );
  }

  // Resuelve **negrita** dentro de una línea.
  Widget _inline(String text) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.w700 : FontWeight.w400,
          color: Colors.white.withValues(alpha: i.isOdd ? 1 : 0.9),
        ),
      ));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14.5, height: 1.5),
        children: spans,
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool accent = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 36,
                color: accent
                    ? AppColors.primary.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
