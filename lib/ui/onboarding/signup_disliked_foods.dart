import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/input_sanitizers.dart';
import '../../core/onboarding_constants.dart';
import '../../core/onboarding_flow.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

const _route = '/signup_disliked_foods';

class SignupDislikedFoods extends StatefulWidget {
  const SignupDislikedFoods({super.key});

  @override
  State<SignupDislikedFoods> createState() => _SignupDislikedFoodsState();
}

class _SignupDislikedFoodsState extends State<SignupDislikedFoods> {
  final Set<String> _disliked = {};
  final _otherCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String _query = '';
  late Map<String, dynamic> userData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    userData = Map<String, dynamic>.from(
        ModalRoute.of(context)!.settings.arguments as Map);
  }

  @override
  void dispose() {
    _otherCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ChipOption> get _filtered {
    if (_query.isEmpty) return OnboardingCatalogs.dislikedFoodsCommon;
    final q = _query.toLowerCase().trim();
    return OnboardingCatalogs.dislikedFoodsCommon
        .where((o) =>
            o.label.toLowerCase().contains(q) ||
            o.value.toLowerCase().contains(q))
        .toList();
  }

  void _onNext() {
    final list = _disliked.toList();
    final other = InputSanitizers.cleanOptional(_otherCtrl.text, maxLen: 200);
    if (other != null) list.add('custom:$other');
    userData['dislikedFoods'] = list;
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
      eyebrow: 'Tu alimentación',
      title: 'Alimentos que prefieres evitar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: 'Buscar alimento...',
              hintStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.30,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(8),
            child: _filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Sin resultados. Agrégalo abajo.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _filtered
                          .map((o) => _compactChip(
                                o.label,
                                _disliked.contains(o.value),
                                () => setState(() {
                                  if (_disliked.contains(o.value)) {
                                    _disliked.remove(o.value);
                                  } else {
                                    _disliked.add(o.value);
                                  }
                                }),
                              ))
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _otherCtrl,
            maxLength: 200,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: '¿Algo más? Sepáralos por coma',
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
          const SizedBox(height: 24),
          CustomButton(text: 'Siguiente', onPressed: _onNext),
          OnboardingSkipLink(
            userData: userData,
            defaults: const {'dislikedFoods': <String>[]},
            nextRoute: OnboardingFlow.nextRoute(_route, userData) ?? '/',
          ),
          const OnboardingBackLink(),
        ],
      ),
    );
  }

  Widget _compactChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
