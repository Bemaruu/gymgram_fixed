import 'package:flutter/material.dart';

import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_equipment';

class SignupEquipment extends StatefulWidget {
  const SignupEquipment({super.key});

  @override
  State<SignupEquipment> createState() => _SignupEquipmentState();
}

class _SignupEquipmentState extends State<SignupEquipment> {
  final Set<String> _equipment = {};
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _toggle(String v) {
    setState(() {
      if (_equipment.contains(v)) {
        _equipment.remove(v);
      } else {
        _equipment.add(v);
      }
    });
  }

  void _onNext() {
    if (_equipment.isEmpty) return;
    userData['equipmentAvailable'] = _equipment.toList();
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
      backgroundAsset: 'assets/images/lugar.png',
      eyebrow: 'Tu entrenamiento',
      title: '¿Con qué equipamiento cuentas?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Marca todo lo que tengas disponible.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.equipment
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _equipment.contains(o.value),
                      onTap: () => _toggle(o.value),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            onPressed: _equipment.isNotEmpty ? _onNext : null,
          ),
          OnboardingSkipLink(
            userData: userData,
            defaults: const {
              'equipmentAvailable': ['bodyweight'],
            },
            nextRoute: OnboardingFlow.nextRoute(_route, userData) ?? '/',
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
