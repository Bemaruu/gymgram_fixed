import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_colors.dart';
import '../../../../services/change_quota_service.dart';
import '../../../../services/supabase_service.dart';

class _GoalOption {
  final String value;
  final String label;
  final IconData icon;
  const _GoalOption(this.value, this.label, this.icon);
}

const _options = <_GoalOption>[
  _GoalOption('LOSE_FAT', 'Perder grasa', Icons.local_fire_department_outlined),
  _GoalOption('GAIN_MUSCLE', 'Ganar musculo', Icons.fitness_center),
  _GoalOption('RECOMP', 'Recomposicion', Icons.shuffle),
  _GoalOption('MAINTAIN', 'Mantenerse', Icons.equalizer),
  _GoalOption('ENDURANCE', 'Mejorar resistencia', Icons.directions_run),
  _GoalOption('TONE', 'Tonificar', Icons.spa_outlined),
];

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
  bool _loading = true;
  bool _saving = false;
  int _used = 0;
  bool _unlimited = false;
  bool _canChange = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue;
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final q = await ChangeQuotaService.instance.quotaFor('fitness_goal');
    final can = await ChangeQuotaService.instance.canChange('fitness_goal');
    if (!mounted) return;
    setState(() {
      _used = q.used;
      _unlimited = q.unlimited;
      _canChange = can;
      _loading = false;
    });
  }

  Future<void> _confirm() async {
    if (_selected == null || _selected == widget.currentValue) {
      Navigator.pop(context);
      return;
    }
    if (!_canChange) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.instance.updateProfile(fitnessGoal: _selected);
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.settingsElevated,
                            content: Text('Proximamente disponible'),
                          ),
                        );
                        // TODO(paywall): navegar a /premium
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_saving || !_canChange) ? null : _confirm,
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
    );
  }

  Widget _quotaBanner() {
    if (_unlimited) {
      return Row(
        children: [
          Icon(Icons.bolt, color: AppColors.accentOrange, size: 16),
          const SizedBox(width: 6),
          const Text(
            'Cambios ilimitados',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      );
    }
    return Text(
      '$_used/${ChangeQuotaService.yearlyLimit} usados este ano',
      style: const TextStyle(color: Colors.white70, fontSize: 13),
    );
  }

  Widget _buildTile(_GoalOption o) {
    final selected = _selected == o.value;
    return InkWell(
      onTap: () => setState(() => _selected = o.value),
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

