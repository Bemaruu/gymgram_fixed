import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
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

  final List<Map<String, String>> restrictionOptions = [
    {'label': 'Lactosa', 'value': 'lactosa'},
    {'label': 'Gluten', 'value': 'gluten'},
    {'label': 'Frutos secos', 'value': 'frutos_secos'},
    {'label': 'Mariscos', 'value': 'mariscos'},
    {'label': 'Vegano', 'value': 'vegano'},
    {'label': 'Vegetariano', 'value': 'vegetariano'},
    {'label': 'No tengo', 'value': 'ninguna'},
    {'label': 'Otro', 'value': 'otro'},
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
        if (value == 'otro') showOtherField = false;
      } else {
        selectedRestrictions.add(value);
        if (value == 'otro') showOtherField = true;
      }
    });
  }

  void _onNext() {
    if (selectedRestrictions.isNotEmpty) {
      final restrictions = selectedRestrictions.toList();

      if (restrictions.contains('otro') && _otherController.text.trim().isNotEmpty) {
        restrictions.add(_otherController.text.trim());
      }

      userData['dietaryRestrictions'] = restrictions;

      Navigator.pushNamed(
        context,
        '/signup_step_11',
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
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
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Especifica tu restricción',
              hintStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: Colors.white.withOpacity(0.85),
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
              color: const Color(0xFF0E4568).withOpacity(0.4),
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
