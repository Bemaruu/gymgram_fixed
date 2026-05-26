import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/input_sanitizers.dart';
import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_injuries';

class SignupInjuries extends StatefulWidget {
  const SignupInjuries({super.key});

  @override
  State<SignupInjuries> createState() => _SignupInjuriesState();
}

class _SignupInjuriesState extends State<SignupInjuries> {
  final Set<String> _injuries = {};
  final _notesCtrl = TextEditingController();
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _toggle(String v) {
    setState(() {
      if (_injuries.contains(v)) {
        _injuries.remove(v);
      } else {
        if (v == 'none') {
          _injuries.clear();
        } else {
          _injuries.remove('none');
        }
        _injuries.add(v);
      }
    });
  }

  void _onNext() {
    if (_injuries.isEmpty) return;
    userData['injuries'] = _injuries.toList();
    final notes = InputSanitizers.cleanOptional(_notesCtrl.text, maxLen: 200);
    if (notes != null) userData['injuryNotes'] = notes;
    final next = OnboardingFlow.nextRoute(_route, userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = OnboardingFlow.progressFor(_route, userData);
    final showNotes = _injuries.isNotEmpty && !_injuries.contains('none');
    return OnboardingScaffold(
      step: progress.step,
      total: progress.total,
      backgroundAsset: 'assets/images/dias.png',
      eyebrow: 'Tu disponibilidad',
      title: '¿Tienes alguna lesión o molestia?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.injuries
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _injuries.contains(o.value),
                      onTap: () => _toggle(o.value),
                    ))
                .toList(),
          ),
          if (showNotes) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLength: 200,
              maxLines: 2,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Detalles (opcional, sin enlaces)',
                hintStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.9),
                counterStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            color: AppColors.accentOrange,
            textColor: Colors.white,
            onPressed: _injuries.isNotEmpty ? _onNext : null,
          ),
          OnboardingSkipLink(
            userData: userData,
            defaults: const {
              'injuries': ['none'],
            },
            nextRoute: OnboardingFlow.nextRoute(_route, userData) ?? '/',
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
