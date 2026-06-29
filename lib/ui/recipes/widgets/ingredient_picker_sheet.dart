import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/food_item.dart';
import '../../../services/food_service.dart';
import '../../../services/recipe_service.dart';

/// Sheet para buscar un alimento y especificar la cantidad en gramos.
class IngredientPickerSheet extends StatefulWidget {
  const IngredientPickerSheet({super.key});

  static Future<RecipeIngredientInput?> show(BuildContext context) {
    return showModalBottomSheet<RecipeIngredientInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.darkSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const IngredientPickerSheet(),
    );
  }

  @override
  State<IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<IngredientPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController(text: '100');
  Timer? _debounce;
  List<FoodItem> _results = [];
  FoodItem? _selected;
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _gramsCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final q = v.trim();
      if (q.length < 2) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final r = await FoodService.instance.searchFoods(q);
      if (!mounted) return;
      // Para una receta queremos ingredientes sueltos (huevo, harina, aceite),
      // no platos ya preparados. Excluimos la categoría "Preparaciones".
      final filtered = r
          .where((f) => f.hasCalories && f.category != 'Preparaciones')
          .toList();
      setState(() {
        _results = filtered.take(12).toList();
        _searching = false;
      });
    });
  }

  void _confirm() {
    final f = _selected;
    final grams = double.tryParse(_gramsCtrl.text.replaceAll(',', '.'));
    if (f == null || grams == null || grams <= 0) return;
    Navigator.pop(
      context,
      RecipeIngredientInput(
        foodNameManual: f.name,
        grams: grams,
        kcalPer100g: f.kcalPer100g ?? 0,
        proteinPer100g: f.proteinPer100g ?? 0,
        carbsPer100g: f.carbsPer100g ?? 0,
        fatPer100g: f.fatPer100g ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar alimento...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppColors.darkSurfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _searching
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: Text(
                            'Escribe al menos 2 letras',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final f = _results[i];
                            final selected = identical(f, _selected);
                            return InkWell(
                              onTap: () => setState(() => _selected = f),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.accentOrange
                                          .withValues(alpha: 0.18)
                                      : AppColors.darkSurfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.accentOrange
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            f.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${f.kcalPer100g?.toStringAsFixed(0) ?? '-'} kcal / 100g',
                                            style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(Icons.check_circle,
                                          color: AppColors.accentOrange),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Cantidad (g):',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _gramsCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.darkSurfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Agregar ingrediente',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
