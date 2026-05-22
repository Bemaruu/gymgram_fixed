import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/water_service.dart';

/// Tracker de vasos de agua. 8 vasos de 250ml. Tocable para sumar.
class WaterTrackingWidget extends StatefulWidget {
  final int target;
  const WaterTrackingWidget({super.key, this.target = 8});

  @override
  State<WaterTrackingWidget> createState() => _WaterTrackingWidgetState();
}

class _WaterTrackingWidgetState extends State<WaterTrackingWidget> {
  int _count = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await WaterService.instance.getGlassesToday();
    if (!mounted) return;
    setState(() {
      _count = c;
      _loading = false;
    });
  }

  Future<void> _toggle(int index) async {
    HapticFeedback.lightImpact();
    final newCount = index + 1 <= _count ? index : index + 1;
    setState(() => _count = newCount);
    await WaterService.instance.setGlassesToday(newCount);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sky200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Agua hoy',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                '$_count / ${widget.target} vasos',
                style: const TextStyle(
                  color: AppColors.sky700,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.target, (i) {
              final filled = i < _count;
              return GestureDetector(
                onTap: () => _toggle(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: filled ? AppColors.sky400 : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: filled ? AppColors.sky500 : AppColors.sky200,
                    ),
                  ),
                  child: Icon(
                    PhosphorIconsFill.drop,
                    size: 16,
                    color: filled ? Colors.white : AppColors.sky300,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
