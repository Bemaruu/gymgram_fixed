import 'package:flutter/material.dart';
import '../../core/onboarding_constants.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

class SignupEquipment extends StatefulWidget {
  const SignupEquipment({super.key});

  @override
  State<SignupEquipment> createState() => _SignupEquipmentState();
}

class _SignupEquipmentState extends State<SignupEquipment> {
  final Set<String> _selected = {};
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    // Si entrena en gimnasio, marcamos full_gym por defecto como sugerencia.
    final loc = userData['trainingLocation']?.toString();
    if (_selected.isEmpty && loc == 'GYM') _selected.add('full_gym');
  }

  void _toggle(String v) {
    setState(() {
      if (_selected.contains(v)) {
        _selected.remove(v);
      } else {
        _selected.add(v);
      }
    });
  }

  void _onNext() {
    if (_selected.isEmpty) return;
    userData['equipmentAvailable'] = _selected.toList();
    Navigator.pushNamed(context, '/signup_experience_level', arguments: userData);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      backgroundAsset: 'assets/images/lugar.png',
      eyebrow: 'Tu equipamiento importa 🏋️',
      title: '¿Con qué equipamiento cuentas?',
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Text(
              'Marca todo lo que tengas disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.equipment
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _selected.contains(o.value),
                      onTap: () => _toggle(o.value),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Siguiente',
            onPressed: _selected.isNotEmpty ? _onNext : null,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
