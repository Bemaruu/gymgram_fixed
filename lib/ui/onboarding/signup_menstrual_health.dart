import 'package:flutter/material.dart';

import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_menstrual_health';

/// Pregunta de salud menstrual, obligatoria para usuarias mujeres
/// (recomendación nutricionista 2026-06-08): amenorrea o menstruación
/// intermitente es por sí sola una señal de riesgo nutricional.
class SignupMenstrualHealth extends StatefulWidget {
  const SignupMenstrualHealth({super.key});

  @override
  State<SignupMenstrualHealth> createState() => _SignupMenstrualHealthState();
}

class _SignupMenstrualHealthState extends State<SignupMenstrualHealth> {
  String? _status;
  late Map<String, dynamic> userData;

  // value → (label, ¿cuenta como riesgo?)
  // 'pregnant' separa embarazo del resto (ACOG 804/2020): bloquea
  // auto-incremento de volumen y filtra ejercicios con contraindicacion
  // 'embarazo' en el catalogo.
  static const _options = <Map<String, Object>>[
    {'value': 'regular', 'label': 'Regular (cada mes, más o menos)', 'risk': false},
    {'value': 'irregular', 'label': 'Irregular o intermitente', 'risk': true},
    {'value': 'absent', 'label': 'Ausente (no menstrúo)', 'risk': true},
    {'value': 'pregnant', 'label': 'Estoy embarazada', 'risk': false},
    {
      'value': 'not_applicable',
      'label': 'No aplica (menopausia, anticonceptivo, otra)',
      'risk': false,
    },
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _onNext() {
    if (_status == null) return;
    final opt = _options.firstWhere((o) => o['value'] == _status);
    userData['menstrualStatus'] = _status;
    if (opt['risk'] == true) {
      userData['menstrualRisk'] = true;
      // Señal de riesgo nutricional independiente del SCOFF.
      userData['eatingDisorderRisk'] = true;
    } else {
      userData['menstrualRisk'] = false;
    }
    // Embarazo activa pregnancy_status en profile (ACOG 804/2020).
    userData['pregnancyStatus'] = _status == 'pregnant';
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
      backgroundAsset: 'assets/images/dieta.png',
      eyebrow: 'Tu bienestar',
      title: '¿Cómo es tu ciclo menstrual?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'Es confidencial. Nos ayuda a cuidar tu salud al planificar tu '
              'alimentación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
                shadows: [
                  Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
          ..._options.map(
            (o) => OnboardingChip(
              label: o['label'] as String,
              selected: _status == o['value'],
              onTap: () => setState(() => _status = o['value'] as String),
              wide: true,
            ),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            onPressed: _status != null ? _onNext : null,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}
