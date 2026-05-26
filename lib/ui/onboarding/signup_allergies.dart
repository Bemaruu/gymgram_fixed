import 'package:flutter/material.dart';

import '../../core/input_sanitizers.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_allergies';

class SignupAllergies extends StatefulWidget {
  const SignupAllergies({super.key});

  @override
  State<SignupAllergies> createState() => _SignupAllergiesState();
}

class _SignupAllergiesState extends State<SignupAllergies> {
  final Set<String> _restrictions = {};
  final _otherCtrl = TextEditingController();
  late Map<String, dynamic> userData;

  static const _options = <Map<String, String>>[
    {'label': 'Lactosa', 'value': 'lactose'},
    {'label': 'Gluten', 'value': 'gluten'},
    {'label': 'Frutos secos', 'value': 'nuts'},
    {'label': 'Mariscos / Pescado', 'value': 'seafood'},
    {'label': 'Huevo', 'value': 'egg'},
    {'label': 'Soja', 'value': 'soy'},
    {'label': 'No tengo', 'value': 'none'},
    {'label': 'Otro', 'value': 'other'},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _toggle(String v) {
    setState(() {
      if (_restrictions.contains(v)) {
        _restrictions.remove(v);
      } else {
        if (v == 'none') {
          _restrictions.clear();
        } else {
          _restrictions.remove('none');
        }
        _restrictions.add(v);
      }
    });
  }

  void _onNext() {
    if (_restrictions.isEmpty) return;
    final list = _restrictions.toList();
    if (list.contains('other')) {
      final extra = InputSanitizers.cleanOptional(_otherCtrl.text, maxLen: 80);
      if (extra != null) list.add('custom:$extra');
    }
    userData['dietaryRestrictions'] = list;
    final next = OnboardingFlow.nextRoute(_route, userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = OnboardingFlow.progressFor(_route, userData);
    final showOther = _restrictions.contains('other');
    return OnboardingScaffold(
      step: progress.step,
      total: progress.total,
      backgroundAsset: 'assets/images/dieta.png',
      eyebrow: 'Tu alimentación',
      title: '¿Tienes alergias o restricciones?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: _options
                .map((o) => OnboardingChip(
                      label: o['label']!,
                      selected: _restrictions.contains(o['value']),
                      onTap: () => _toggle(o['value']!),
                    ))
                .toList(),
          ),
          if (showOther) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otherCtrl,
              maxLength: 80,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Especifica tu restricción (sin enlaces)',
                hintStyle: const TextStyle(color: Colors.black54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.9),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            onPressed: _restrictions.isNotEmpty ? _onNext : null,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
