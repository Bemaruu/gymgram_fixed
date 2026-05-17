import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_colors.dart';
import '../../../../services/weight_service.dart';

class WeightQuickSheet extends StatefulWidget {
  const WeightQuickSheet({super.key});

  @override
  State<WeightQuickSheet> createState() => _WeightQuickSheetState();

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.settingsSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const WeightQuickSheet(),
    );
  }
}

class _WeightQuickSheetState extends State<WeightQuickSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _recent = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final logs = await WeightService.instance.getLogs(limit: 7);
    if (mounted) setState(() => _recent = logs);
  }

  Future<void> _save() async {
    final raw = _controller.text.trim().replaceAll(',', '.');
    final kg = double.tryParse(raw);
    if (kg == null) {
      setState(() => _error = 'Ingresa un numero valido');
      return;
    }
    if (kg < 30 || kg > 300) {
      setState(() => _error = 'El peso debe estar entre 30 y 300 kg');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await WeightService.instance.logWeight(double.parse(kg.toStringAsFixed(1)));
      HapticFeedback.lightImpact();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar el peso';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
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
                'Registrar peso',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.0',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 48),
                      suffixText: 'kg',
                      suffixStyle:
                          TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: AppColors.settingsDanger,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_recent.isNotEmpty) ...[
                const Text(
                  'Recientes',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _recent.map((r) {
                    final kg = (r['weight_kg'] as num).toDouble();
                    return GestureDetector(
                      onTap: () {
                        _controller.text = kg.toStringAsFixed(1);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.settingsElevated,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${kg.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Guardar peso',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/weight-log');
                  },
                  child: const Text(
                    'Ver historial completo',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
