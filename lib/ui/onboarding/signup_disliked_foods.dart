import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/input_sanitizers.dart';
import '../../core/onboarding_constants.dart';
import '../shared/custom_button.dart';
import 'shared/onboarding_scaffold.dart';

class SignupDislikedFoods extends StatefulWidget {
  const SignupDislikedFoods({super.key});

  @override
  State<SignupDislikedFoods> createState() => _SignupDislikedFoodsState();
}

class _SignupDislikedFoodsState extends State<SignupDislikedFoods> {
  final Set<String> _selected = {};
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
    final list = _selected.toList();
    final other = InputSanitizers.cleanOptional(_otherCtrl.text, maxLen: 200);
    if (other != null) list.add('custom:$other');
    userData['dislikedFoods'] = list;
    Navigator.pushNamed(context, '/signup_step_11', arguments: userData);
  }

  List<ChipOption> get _filteredOptions {
    if (_query.isEmpty) return OnboardingCatalogs.dislikedFoodsCommon;
    final q = _query.toLowerCase().trim();
    return OnboardingCatalogs.dislikedFoodsCommon
        .where((o) =>
            o.label.toLowerCase().contains(q) ||
            o.value.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOptions;
    return OnboardingScaffold(
      backgroundAsset: 'assets/images/dieta.png',
      eyebrow: 'Personaliza tus recomendaciones',
      title: '¿Hay alimentos que prefieres evitar?',
      child: Column(
        children: [
          // Buscador
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.black),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Buscar alimento...',
              hintStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.search, color: Colors.black54),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.black54),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Contador de selección
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_selected.length} seleccionado(s)',
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          // Grid de chips compactos
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(8),
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Sin resultados. Agrégalo abajo como "Otros".',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: filtered
                          .map((o) => _compactChip(
                                label: o.label,
                                selected: _selected.contains(o.value),
                                onTap: () => _toggle(o.value),
                              ))
                          .toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          // Campo "otros" libre
          TextField(
            controller: _otherCtrl,
            maxLength: 200,
            maxLines: 2,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: '¿Algo más? Sepáralos por coma (sin enlaces)',
              hintStyle: const TextStyle(color: Colors.black54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
              counterStyle: const TextStyle(color: Colors.white70),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          CustomButton(text: 'Siguiente', onPressed: _onNext),
          const OnboardingBackLink(),
        ],
      ),
    );
  }

  Widget _compactChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
