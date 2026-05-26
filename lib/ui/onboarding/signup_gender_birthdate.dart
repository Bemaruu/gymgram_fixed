import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/app_colors.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_gender_birthdate';

class SignupGenderBirthdate extends StatefulWidget {
  const SignupGenderBirthdate({super.key});

  @override
  State<SignupGenderBirthdate> createState() => _SignupGenderBirthdateState();
}

class _SignupGenderBirthdateState extends State<SignupGenderBirthdate> {
  String? _gender;
  DateTime? _birthDate;
  late Map<String, dynamic> userData;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  void _showError(String msg) {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final minDate = DateTime(now.year - 90, now.month, now.day);
    final maxDate = DateTime(now.year - 16, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: maxDate,
      firstDate: minDate,
      lastDate: maxDate,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentOrange,
            surface: AppColors.darkBlue,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      if (picked.isBefore(minDate) || picked.isAfter(maxDate)) {
        _showError('Debes tener entre 16 y 90 años para registrarte');
        return;
      }
      setState(() => _birthDate = picked);
    }
  }

  void _onNext() {
    if (_gender == null) {
      _showError('Selecciona tu género');
      return;
    }
    if (_birthDate == null) {
      _showError('Selecciona tu fecha de nacimiento');
      return;
    }
    userData['gender'] = _gender;
    userData['birthDate'] = _birthDate!.toIso8601String();
    final next = OnboardingFlow.nextRoute(_route, userData);
    if (next != null) {
      Navigator.pushNamed(context, next, arguments: userData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = OnboardingFlow.progressFor(_route, userData);
    final hasDate = _birthDate != null;
    return OnboardingScaffold(
      step: progress.step,
      total: progress.total,
      backgroundAsset: 'assets/images/balanza.png',
      eyebrow: 'Sobre ti',
      title: 'Cuéntanos quién eres',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('¿Con qué género te identificas?'),
          const SizedBox(height: 8),
          _genderButton('Hombre', Icons.male, 'MALE', AppColors.primary),
          _genderButton('Mujer', Icons.female, 'FEMALE', AppColors.accentOrange),
          _genderButton('Otro', Icons.transgender, 'OTHER', AppColors.darkBlue),
          const SizedBox(height: 20),
          _sectionLabel('¿Cuál es tu fecha de nacimiento?'),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _selectDate,
            child: Text(
              hasDate
                  ? DateFormat('dd MMMM yyyy', 'es_ES').format(_birthDate!)
                  : 'Seleccionar fecha',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Siguiente',
            color: AppColors.accentOrange,
            textColor: Colors.white,
            onPressed: _onNext,
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        shadows: [Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 2))],
      ),
    );
  }

  Widget _genderButton(String label, IconData icon, String value, Color color) {
    final selected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: selected ? Colors.white : color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
