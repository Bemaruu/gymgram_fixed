import 'package:flutter/material.dart';
import '../../core/input_sanitizers.dart';
import '../../core/onboarding_constants.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

/// Combina split preference + lesiones (chips + texto libre opcional sanitizado).
class SignupRoutinePreferences extends StatefulWidget {
  const SignupRoutinePreferences({super.key});

  @override
  State<SignupRoutinePreferences> createState() => _SignupRoutinePreferencesState();
}

class _SignupRoutinePreferencesState extends State<SignupRoutinePreferences> {
  String? _split;
  final Set<String> _injuries = {};
  final _notesCtrl = TextEditingController();
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _toggleInjury(String v) {
    setState(() {
      if (_injuries.contains(v)) {
        _injuries.remove(v);
      } else {
        // "none" excluye al resto y viceversa
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
    if (_split == null) return;
    userData['routineSplitPreference'] = _split;
    userData['injuries'] = _injuries.toList();
    final notes = InputSanitizers.cleanOptional(_notesCtrl.text, maxLen: 200);
    if (notes != null) userData['injuryNotes'] = notes;

    // Si el usuario importó su rutina, sus días ya están definidos por las
    // entradas de `importedRoutine`. Saltar step_7 para no pedir lo mismo
    // dos veces (y evitar que se sobreescriban los días con un click distraído).
    final imported = userData['importedRoutine'];
    final hasImported = imported is List && imported.isNotEmpty;
    final nextRoute = hasImported ? '/signup_session_duration' : '/signup_step_7';
    Navigator.pushNamed(context, nextRoute, arguments: userData);
  }

  @override
  Widget build(BuildContext context) {
    final showInjuriesNotes = _injuries.isNotEmpty && !_injuries.contains('none');
    return OnboardingScaffold(
      backgroundAsset: 'assets/images/objetivo.png',
      eyebrow: 'Personaliza tu plan',
      title: 'Preferencias y limitaciones',
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 6, bottom: 6),
              child: Text(
                'Tipo de rutina preferido',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.routineSplit
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _split == o.value,
                      onTap: () => setState(() => _split = o.value),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 6, bottom: 6),
              child: Text(
                '¿Tienes alguna lesión o molestia?',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: OnboardingCatalogs.injuries
                .map((o) => OnboardingChip(
                      label: o.label,
                      selected: _injuries.contains(o.value),
                      onTap: () => _toggleInjury(o.value),
                    ))
                .toList(),
          ),
          if (showInjuriesNotes) ...[
            const SizedBox(height: 10),
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
          const SizedBox(height: 16),
          CustomButton(
            text: 'Siguiente',
            onPressed: _split != null ? _onNext : null,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }
}

