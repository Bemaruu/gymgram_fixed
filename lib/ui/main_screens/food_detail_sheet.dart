import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/food_item.dart';
import '../../services/food_service.dart';

class FoodDetailSheet extends StatefulWidget {
  final FoodItem food;
  final String initialMealType;

  const FoodDetailSheet({
    super.key,
    required this.food,
    this.initialMealType = 'breakfast',
  });

  @override
  State<FoodDetailSheet> createState() => _FoodDetailSheetState();
}

class _FoodDetailSheetState extends State<FoodDetailSheet> {
  static const _kBlue = Color(0xFF5B8DEF);
  static const _kOrange = Color(0xFFF5A623);
  static const _kGreen = Color(0xFF7ED321);
  static const _kPrimary = Color(0xFF00BFFF);

  static const _quickGrams = [100.0, 150.0, 200.0, 250.0];

  static const _mealTypes = [
    ('breakfast', 'Desayuno', Icons.wb_sunny_outlined),
    ('lunch', 'Almuerzo', Icons.lunch_dining_outlined),
    ('dinner', 'Cena', Icons.nightlight_outlined),
    ('snack', 'Snack', Icons.cookie_outlined),
    ('pre_workout', 'Pre-entreno', Icons.bolt_outlined),
    ('post_workout', 'Post-entreno', Icons.fitness_center),
  ];

  late final TextEditingController _gramsCtrl;
  late final DraggableScrollableController _sheetController;
  late String _mealType;
  double _grams = 100.0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mealType = widget.initialMealType;
    _gramsCtrl = TextEditingController(text: '100');
    _sheetController = DraggableScrollableController();
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _onGramsChanged(String val) {
    final parsed = double.tryParse(val);
    if (parsed != null && parsed > 0) {
      setState(() => _grams = parsed);
    }
  }

  void _selectQuick(double g) {
    setState(() => _grams = g);
    _gramsCtrl.text = g.toStringAsFixed(0);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await FoodService.instance.logFood(
        widget.food,
        _grams,
        _mealType,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final kcal = food.kcalFor(_grams);
    final protein = food.proteinFor(_grams);
    final carbs = food.carbsFor(_grams);
    final fat = food.fatFor(_grams);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      snap: true,
      snapSizes: const [0.75, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Nombre y marca
              Text(
                food.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              if (food.brand != null && food.brand!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  food.brand!,
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                ),
              ],
              const SizedBox(height: 24),

              // Selector de gramos
              const Text(
                'Cantidad',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _gramsCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: _onGramsChanged,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'g',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickGrams.map((g) {
                          final selected = _grams == g;
                          return GestureDetector(
                            onTap: () => _selectQuick(g),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected ? _kPrimary : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${g.toStringAsFixed(0)}g',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : Colors.black54,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Preview de macros en tiempo real
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      kcal != null ? '${kcal.toStringAsFixed(0)} kcal' : '-- kcal',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MacroColumn(
                            label: 'Proteína',
                            value: protein,
                            color: _kBlue,
                          ),
                          const VerticalDivider(color: Color(0xFFDDDDDD), width: 1),
                          _MacroColumn(
                            label: 'Carbos',
                            value: carbs,
                            color: _kOrange,
                          ),
                          const VerticalDivider(color: Color(0xFFDDDDDD), width: 1),
                          _MacroColumn(
                            label: 'Grasas',
                            value: fat,
                            color: _kGreen,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Selector de tipo de comida
              const Text(
                'Tipo de comida',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _mealTypes.map((entry) {
                    final (type, label, icon) = entry;
                    final selected = _mealType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _mealType = type),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? _kPrimary : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: selected ? Colors.white : Colors.black54,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              // Botón agregar
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kPrimary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Agregar al registro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MacroColumn extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;

  const _MacroColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value != null ? '${value!.toStringAsFixed(1)}g' : '--',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
