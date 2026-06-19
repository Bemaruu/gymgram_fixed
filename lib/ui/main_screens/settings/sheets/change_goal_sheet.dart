import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_colors.dart';
import '../../../../services/change_quota_service.dart';
import '../../../../services/supabase_service.dart';
import '../../../plans/plans_screen.dart';

class _GoalOption {
  final String value;
  final String label;
  final IconData icon;
  const _GoalOption(this.value, this.label, this.icon);
}

// Valores canónicos alineados con onboarding (OnboardingCatalogs.fitnessGoal)
// y con NutritionCalculator. Antes usaba 'LOSE_FAT'/'RECOMP'/... que el motor
// no reconocía → el cálculo caía a mantenimiento al cambiar objetivo.
const _options = <_GoalOption>[
  _GoalOption('LOSE_WEIGHT', 'Perder grasa', Icons.local_fire_department_outlined),
  _GoalOption('GAIN_MUSCLE', 'Ganar musculo', Icons.fitness_center),
  _GoalOption('RECOMPOSITION', 'Recomposicion', Icons.shuffle),
  _GoalOption('MAINTAIN', 'Mantenerse', Icons.equalizer),
  _GoalOption('IMPROVE_ENDURANCE', 'Mejorar resistencia', Icons.directions_run),
  _GoalOption('TONE_BODY', 'Tonificar', Icons.spa_outlined),
];

// Objetivos de cambio físico que requieren plazo (igual que en onboarding).
bool _goalNeedsTimeframe(String? g) =>
    g == 'LOSE_WEIGHT' ||
    g == 'GAIN_MUSCLE' ||
    g == 'RECOMPOSITION' ||
    g == 'TONE_BODY';

class ChangeGoalSheet extends StatefulWidget {
  final String? currentValue;

  const ChangeGoalSheet({super.key, required this.currentValue});

  static Future<String?> show(BuildContext context, String? current) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.settingsSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeGoalSheet(currentValue: current),
    );
  }

  @override
  State<ChangeGoalSheet> createState() => _ChangeGoalSheetState();
}

class _ChangeGoalSheetState extends State<ChangeGoalSheet> {
  String? _selected;
  int? _months; // plazo 3/6/12 para objetivos de cambio físico
  bool _loading = true;
  bool _saving = false;
  int _used = 0;
  int _limit = ChangeQuotaService.yearlyLimit;
  bool _canChange = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue;
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final q = await ChangeQuotaService.instance.quotaFor();
    final can = await ChangeQuotaService.instance.canChange();
    if (!mounted) return;
    setState(() {
      _used = q.used;
      _limit = q.limit;
      _canChange = can;
      _loading = false;
    });
  }

  // Habilitado si hay objetivo y, cuando es de cambio físico, también plazo.
  bool get _canConfirm =>
      _selected != null &&
      (!_goalNeedsTimeframe(_selected) || _months != null);

  Future<void> _confirm() async {
    if (_selected == null) {
      Navigator.pop(context);
      return;
    }
    final needsTf = _goalNeedsTimeframe(_selected);
    // Nada que cambiar: mismo objetivo y sin plazo aplicable.
    if (_selected == widget.currentValue && !needsTf) {
      Navigator.pop(context);
      return;
    }
    if (needsTf && _months == null) {
      HapticFeedback.mediumImpact();
      return;
    }
    if (!_canChange) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _saving = true);

    // Plazo: para objetivos físicos fijamos inicio (hoy) y vencimiento
    // (hoy + N meses), reiniciando el reloj. Para los demás, limpiamos plazo.
    String? startedAt;
    String? targetDate;
    if (needsTf && _months != null) {
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      final now = DateTime.now();
      startedAt = fmt(DateTime(now.year, now.month, now.day));
      targetDate = fmt(DateTime(now.year, now.month + _months!, now.day));
    }

    try {
      await SupabaseService.instance.updateProfile(
        fitnessGoal: _selected,
        setGoalTimeframe: true,
        goalTimeframeMonths: needsTf ? _months : null,
        goalStartedAt: startedAt,
        goalTargetDate: targetDate,
      );
      await ChangeQuotaService.instance.recordChange(
        field: 'fitness_goal',
        oldValue: widget.currentValue,
        newValue: _selected,
      );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      Navigator.pop(context, _selected);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cambiar objetivo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (!_loading) _quotaBanner(),
            const SizedBox(height: 16),
            Stack(
              children: [
                Opacity(
                  opacity: _canChange ? 1.0 : 0.4,
                  child: IgnorePointer(
                    ignoring: !_canChange,
                    child: Column(
                      children: _options.map(_buildTile).toList(),
                    ),
                  ),
                ),
                if (!_canChange && !_loading)
                  Positioned.fill(
                    child: Center(
                      child: _LockedCta(onTap: () {
                        Navigator.pop(context);
                        PlansScreen.open(context);
                      }),
                    ),
                  ),
              ],
            ),
            // Plazo: solo para objetivos de cambio físico.
            if (_goalNeedsTimeframe(_selected) && _canChange) ...[
              const SizedBox(height: 20),
              const Text(
                '¿En cuánto tiempo?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ajustamos tus calorías y proteína a un ritmo seguro.',
                style: TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              _monthTile(3, 'Más exigente', 'Ritmo rápido y seguro'),
              _monthTile(6, 'Equilibrado', 'Constante y sostenible'),
              _monthTile(12, 'Gradual', 'Suave, máxima adherencia'),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_saving || !_canChange || !_canConfirm)
                    ? null
                    : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.deepBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.deepBlue,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirmar cambio',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _monthTile(int months, String title, String subtitle) {
    final selected = _months == months;
    return InkWell(
      onTap: () => setState(() => _months = months),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.settingsElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              '$months',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 3),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('m',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quotaBanner() {
    return Text(
      '$_used/$_limit cambios usados este ano',
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }

  Widget _buildTile(_GoalOption o) {
    final selected = _selected == o.value;
    return InkWell(
      onTap: () => setState(() {
        _selected = o.value;
        if (!_goalNeedsTimeframe(o.value)) _months = null;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.settingsElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(o.icon, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                o.label,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : Colors.white38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedCta extends StatelessWidget {
  final VoidCallback onTap;
  const _LockedCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.settingsSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: AppColors.accentOrange, size: 28),
          const SizedBox(height: 8),
          const Text(
            'Limite anual alcanzado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hazte Premium para cambios ilimitados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver Premium'),
          ),
        ],
      ),
    );
  }
}

String labelForGoal(String? value) {
  for (final o in _options) {
    if (o.value == value) return o.label;
  }
  return value ?? 'No definido';
}

