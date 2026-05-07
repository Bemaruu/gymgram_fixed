import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../services/food_service.dart';
import 'food_detail_sheet.dart';
import 'barcode_scanner_screen.dart';

class FoodSearchScreen extends StatefulWidget {
  final String initialMealType;
  const FoodSearchScreen({super.key, this.initialMealType = 'breakfast'});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';

  static const _kBlue = Color(0xFF00BFFF);
  static const _kOrange = Color(0xFFF5A623);
  static const _kGreen = Color(0xFF7ED321);

  _SearchState _state = _SearchState.idle;
  List<FoodItem> _results = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _state = _SearchState.idle;
        _results = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String query) async {
    _activeQuery = query;
    setState(() => _state = _SearchState.loading);
    try {
      final items = await FoodService.instance.searchFoods(query);
      if (!mounted || _activeQuery != query) return;
      setState(() {
        _results = items;
        _state = items.isEmpty ? _SearchState.empty : _SearchState.results;
      });
    } catch (_) {
      if (mounted && _activeQuery == query) setState(() => _state = _SearchState.error);
    }
  }

  Future<void> _openDetail(FoodItem food) async {
    final logged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodDetailSheet(
        food: food,
        initialMealType: widget.initialMealType,
      ),
    );
    if (logged == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _openScanner() async {
    final food = await Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (food != null && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text('Producto escaneado: ${food.name}'),
        backgroundColor: const Color(0xFF1A1A2E),
        duration: const Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
      _openDetail(food);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Buscar alimento...',
            hintStyle: TextStyle(color: Colors.black38, fontSize: 16),
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black54),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
          IconButton(
            tooltip: 'Escanear codigo de barras',
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00BFFF), size: 24),
            onPressed: _openScanner,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _SearchState.idle:
        return _IdleState(onChipTap: (term) {
          _controller.text = term;
          _onChanged(term);
        });
      case _SearchState.loading:
        return _SkeletonList();
      case _SearchState.results:
        return _buildResults();
      case _SearchState.empty:
        return _EmptyState(
          icon: Icons.search_off,
          iconSize: 48,
          message:
              'No encontramos "${_controller.text.trim()}"\nPrueba escanear el producto',
          color: Colors.black38,
        );
      case _SearchState.error:
        return _ErrorState(onRetry: () => _search(_controller.text.trim()));
    }
  }

  Widget _buildResults() {
    final custom = _results.where((f) => f.isCustom).toList();
    final off = _results.where((f) => !f.isCustom).toList();
    final showHeaders = custom.isNotEmpty && off.isNotEmpty;

    final items = <Widget>[];

    if (showHeaders && custom.isNotEmpty) {
      items.add(_SectionHeader(label: 'ALIMENTOS GENERALES'));
    }
    for (final food in custom) {
      items.add(_FoodCard(
        food: food,
        kBlue: _kBlue,
        kOrange: _kOrange,
        kGreen: _kGreen,
        onTap: () => _openDetail(food),
      ));
    }

    if (showHeaders && off.isNotEmpty) {
      items.add(_SectionHeader(label: 'PRODUCTOS DE MARCA'));
    }
    for (final food in off) {
      items.add(_FoodCard(
        food: food,
        kBlue: _kBlue,
        kOrange: _kOrange,
        kGreen: _kGreen,
        onTap: () => _openDetail(food),
      ));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items,
    );
  }
}

enum _SearchState { idle, loading, results, empty, error }

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black38,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _IdleState extends StatelessWidget {
  final ValueChanged<String> onChipTap;
  const _IdleState({required this.onChipTap});

  static const _chips = [
    'Pollo', 'Arroz', 'Huevos', 'Avena',
    'Salmon', 'Platano', 'Lentejas', 'Palta',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.black26),
            const SizedBox(height: 12),
            const Text(
              'Busca por nombre o escanea\nel codigo de barras',
              style: TextStyle(color: Colors.black45, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _chips.map((chip) {
                return GestureDetector(
                  onTap: () => onChipTap(chip),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F8FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00BFFF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF00BFFF),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final FoodItem food;
  final Color kBlue;
  final Color kOrange;
  final Color kGreen;
  final VoidCallback onTap;

  const _FoodCard({
    required this.food,
    required this.kBlue,
    required this.kOrange,
    required this.kGreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          food.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!food.isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OFF',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (food.brand != null && food.brand!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      food.brand!,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (food.proteinPer100g != null)
                        _MacroChip(
                          label: 'P ${food.proteinPer100g!.toStringAsFixed(1)}g',
                          color: kBlue,
                        ),
                      if (food.carbsPer100g != null)
                        _MacroChip(
                          label: 'C ${food.carbsPer100g!.toStringAsFixed(1)}g',
                          color: kOrange,
                        ),
                      if (food.fatPer100g != null)
                        _MacroChip(
                          label: 'G ${food.fatPer100g!.toStringAsFixed(1)}g',
                          color: kGreen,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  food.kcalPer100g?.toStringAsFixed(0) ?? '-',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const Text(
                  'kcal/100g',
                  style: TextStyle(fontSize: 10, color: Colors.black45),
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String message;
  final Color color;
  const _EmptyState({
    required this.icon,
    required this.iconSize,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: color, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 48, color: Colors.black38),
          const SizedBox(height: 12),
          const Text(
            'Error al buscar',
            style: TextStyle(color: Colors.black54, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 76,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
