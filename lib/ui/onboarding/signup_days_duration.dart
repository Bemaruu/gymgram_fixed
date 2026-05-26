import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_days_duration';

class SignupDaysDuration extends StatefulWidget {
  const SignupDaysDuration({super.key});

  @override
  State<SignupDaysDuration> createState() => _SignupDaysDurationState();
}

class _SignupDaysDurationState extends State<SignupDaysDuration> {
  final Set<String> _days = {};
  String? _duration;
  late Map<String, dynamic> userData;
  bool _hasImported = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
    final imported = userData['importedRoutine'];
    _hasImported = imported is List && imported.isNotEmpty;
    if (_hasImported) {
      final imported = userData['availableDays'];
      if (imported is List) {
        for (final d in imported) {
          _days.add(d.toString());
        }
      }
    }
  }

  void _toggleDay(String v) {
    setState(() {
      if (_days.contains(v)) {
        _days.remove(v);
      } else {
        _days.add(v);
      }
    });
  }

  bool get _canNext =>
      (_hasImported || _days.isNotEmpty) && _duration != null;

  void _persistDays() {
    if (!_hasImported) {
      userData['availableDays'] = _days.toList();
      userData['trainingDays'] = _days.join(', ');
    }
  }

  void _onNext() {
    if (!_canNext) return;
    _persistDays();
    userData['sessionDurationMinutes'] = int.parse(_duration!);
    final next = OnboardingFlow.nextRoute(_route, userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
  }

  void _skipDuration() {
    _persistDays();
    userData['sessionDurationMinutes'] = 60;
    final next = OnboardingFlow.nextRoute(_route, userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = OnboardingFlow.progressFor(_route, userData);
    return OnboardingScaffold(
      step: progress.step,
      total: progress.total,
      backgroundAsset: 'assets/images/dias.png',
      eyebrow: 'Tu disponibilidad',
      title: '¿Qué días entrenas y por cuánto tiempo?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_hasImported) ...[
            _label('Días de entrenamiento'),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              children: OnboardingCatalogs.weekDays
                  .map((d) => OnboardingChip(
                        label: d.label,
                        selected: _days.contains(d.value),
                        onTap: () => _toggleDay(d.value),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
          _label('Tiempo por sesión'),
          const SizedBox(height: 8),
          ...OnboardingCatalogs.sessionDuration.map(
            (o) => OnboardingChip(
              label: o.label,
              selected: _duration == o.value,
              onTap: () => setState(() => _duration = o.value),
              wide: true,
            ),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            color: AppColors.accentOrange,
            textColor: Colors.white,
            onPressed: _canNext ? _onNext : null,
          ),
          if (_hasImported || _days.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: _skipDuration,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
                child: const Text(
                  'Omitir tiempo (1 hora por defecto)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2))],
        ),
      );
}
