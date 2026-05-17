import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/input_sanitizers.dart';
import '../shared/custom_button.dart';

class SignupStep10 extends StatefulWidget {
  const SignupStep10({super.key});

  @override
  State<SignupStep10> createState() => _SignupStep10State();
}

class _SignupStep10State extends State<SignupStep10> with TickerProviderStateMixin {
  final Set<String> selectedRestrictions = {};
  final TextEditingController _otherController = TextEditingController();
  bool showOtherField = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Map<String, dynamic> userData;

  final List<Map<String, String>> restrictionOptions = const [
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
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _toggleRestriction(String value) {
    setState(() {
      if (selectedRestrictions.contains(value)) {
        selectedRestrictions.remove(value);
        if (value == 'other') showOtherField = false;
      } else {
        selectedRestrictions.add(value);
        if (value == 'other') showOtherField = true;
      }
    });
  }

  void _onNext() {
    if (selectedRestrictions.isNotEmpty) {
      final restrictions = selectedRestrictions.toList();

      if (restrictions.contains('other')) {
        final extra = InputSanitizers.cleanOptional(_otherController.text, maxLen: 80);
        if (extra != null) restrictions.add('custom:$extra');
      }

      // Lista tipada (no string concatenado) para datos limpios.
      userData['dietaryRestrictions'] = restrictions;

      Navigator.pushNamed(
        context,
        '/signup_cooking_time',
        arguments: userData,
      );
    }
  }


  Widget restrictionChip(String label, String value) {
    final isSelected = selectedRestrictions.contains(value);
    return GestureDetector(
      onTap: () => _toggleRestriction(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherInput() {
    return AnimatedOpacity(
      opacity: showOtherField ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Visibility(
        visible: showOtherField,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: _otherController,
            maxLength: 80,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Especifica tu restricción (sin enlaces)',
              hintStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.85),
              counterText: '',
              prefixIcon: const Icon(Icons.edit, color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/restricciones.png',
            fit: BoxFit.cover,
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: const Color(0xFF0E4568).withValues(alpha: 0.4),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '¡Queremos cuidarte aún más! ✨',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '¿Tienes alguna restricción alimentaria o alergia?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 6,
                              color: Colors.black87,
                              offset: Offset(0, 3),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: restrictionOptions
                            .map((opt) => restrictionChip(opt['label']!, opt['value']!))
                            .toList(),
                      ),
                      _buildOtherInput(),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: CustomButton(
                          key: ValueKey(selectedRestrictions.length),
                          text: 'Siguiente',
                          onPressed: selectedRestrictions.isNotEmpty ? _onNext : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Volver',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
