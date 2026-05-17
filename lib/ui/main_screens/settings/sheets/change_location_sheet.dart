import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_colors.dart';
import '../../../../services/change_quota_service.dart';
import '../../../../services/supabase_service.dart';

class _LocOption {
  final String value;
  final String label;
  final IconData icon;
  const _LocOption(this.value, this.label, this.icon);
}

const _options = <_LocOption>[
  _LocOption('HOME', 'Casa', Icons.home_outlined),
  _LocOption('GYM', 'Gym', Icons.fitness_center),
  _LocOption('OUTDOOR', 'Aire libre', Icons.park_outlined),
  _LocOption('HYBRID', 'Hibrido', Icons.swap_horiz),
];

class ChangeLocationSheet extends StatefulWidget {
  final String? currentValue;
  const ChangeLocationSheet({super.key, required this.currentValue});

  static Future<String?> show(BuildContext context, String? current) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.settingsSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeLocationSheet(currentValue: current),
    );
  }

  @override
  State<ChangeLocationSheet> createState() => _ChangeLocationSheetState();
}

class _ChangeLocationSheetState extends State<ChangeLocationSheet> {
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
    final q = await ChangeQuotaService.instance.quotaFor('training_location');
    final can = await ChangeQuotaService.instance.canChange('training_location');
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
      await SupabaseService.instance.updateProfile(trainingLocation: _selected);
      await ChangeQuotaService.instance.recordChange(
        field: 'training_location',
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
              'Cambiar lugar de entrenamiento',
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
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.4,
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

  Widget _buildTile(_LocOption o) {
    final selected = _selected == o.value;
    return InkWell(
      onTap: () => setState(() => _selected = o.value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.settingsElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(o.icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              o.label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
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

String labelForLocation(String? value) {
  for (final o in _options) {
    if (o.value == value) return o.label;
  }
  return value ?? 'No definido';
}
