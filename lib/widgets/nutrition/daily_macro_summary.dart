import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/food_service.dart';
import '../../services/nutrition_goals_service.dart';

/// Resumen de macros del dia (kcal + proteina/carbos/grasa) versus objetivo.
/// Lee food_logs del usuario y compara contra nutrition_goals.
class DailyMacroSummary extends StatefulWidget {
  const DailyMacroSummary({super.key});

  @override
  State<DailyMacroSummary> createState() => _DailyMacroSummaryState();
}

class _DailyMacroSummaryState extends State<DailyMacroSummary> {
  bool _loading = true;
  Map<String, dynamic>? _goals;
  double _kcal = 0;
  double _protein = 0;
  double _carbs = 0;
  double _fat = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await NutritionGoalsService.instance.get();
    final logs = await FoodService.instance.getDailyLog(DateTime.now());
    double k = 0, p = 0, c = 0, f = 0;
    for (final l in logs) {
      k += l.kcalTotal ?? 0;
      p += l.proteinTotal ?? 0;
      c += l.carbsTotal ?? 0;
      f += l.fatTotal ?? 0;
    }
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _kcal = k;
      _protein = p;
      _carbs = c;
      _fat = f;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final targetKcal = (_goals?['daily_kcal'] as int?) ?? 2000;
    final targetP = (_goals?['protein_g'] as int?) ?? 120;
    final targetC = (_goals?['carbs_g'] as int?) ?? 220;
    final targetF = (_goals?['fat_g'] as int?) ?? 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hoy',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  )),
              Text(
                '${_kcal.toStringAsFixed(0)} / $targetKcal kcal',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _bar('Proteina', _protein, targetP.toDouble(),
              const Color(0xFF63C8FC)),
          const SizedBox(height: 6),
          _bar('Carbos', _carbs, targetC.toDouble(),
              const Color(0xFFFFB341)),
          const SizedBox(height: 6),
          _bar('Grasa', _fat, targetF.toDouble(), const Color(0xFFFD6D2F)),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, double target, Color color) {
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.2);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.neutral200,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            '${value.toStringAsFixed(0)}/${target.toStringAsFixed(0)}g',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
