import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/recipe_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  static Future<void> open(BuildContext context, String recipeId) {
    return Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipeId: recipeId)),
    );
  }

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? _recipe;
  List<Map<String, dynamic>> _ingredients = [];
  bool _loading = true;
  bool _isSaved = false;
  bool _saving = false;

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recipe = await RecipeService.instance.getRecipe(widget.recipeId);
    final ingredients =
        await RecipeService.instance.getIngredients(widget.recipeId);
    final saved = await RecipeService.instance.isSaved(widget.recipeId);
    if (!mounted) return;
    setState(() {
      _recipe = recipe;
      _ingredients = ingredients;
      _isSaved = saved;
      _loading = false;
    });
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    if (_isSaved) {
      await RecipeService.instance.unsaveRecipe(widget.recipeId);
    } else {
      await RecipeService.instance.saveRecipe(widget.recipeId);
    }
    if (!mounted) return;
    setState(() {
      _isSaved = !_isSaved;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.darkSurface,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    final r = _recipe;
    if (r == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkSurface,
        body: Center(
            child: Text('Receta no disponible',
                style: TextStyle(color: Colors.white70))),
      );
    }

    final isMine = (r['user_id'] as String?) == _myId;
    final servings = (r['servings'] as num?)?.toDouble() ?? 1;
    final macros = _calcMacros();
    final per = servings > 0 ? servings : 1;

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(r['name'] as String? ?? 'Receta',
            style: const TextStyle(color: Colors.white)),
        actions: [
          if (!isMine && (r['is_public'] as bool? ?? false))
            IconButton(
              onPressed: _toggleSave,
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? AppColors.accentOrange : Colors.white,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if ((r['image_url'] as String?)?.isNotEmpty == true)
            _buildHeroImage(r['image_url'] as String),
          if ((r['image_url'] as String?)?.isNotEmpty == true)
            const SizedBox(height: 16),
          Row(
            children: [
              _info('Porciones', servings.toStringAsFixed(servings % 1 == 0 ? 0 : 1)),
              if (r['prep_time_min'] != null)
                _info('Prep', '${r['prep_time_min']} min'),
              _info('Guardadas', '${r['saves_count'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Macros por porcion',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _macro('kcal', (macros.kcal / per).toStringAsFixed(0)),
                    _macro('P', '${(macros.protein / per).toStringAsFixed(0)}g'),
                    _macro('C', '${(macros.carbs / per).toStringAsFixed(0)}g'),
                    _macro('G', '${(macros.fat / per).toStringAsFixed(0)}g'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Ingredientes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          ..._ingredients.map((i) {
            final name = (i['food_name_manual'] as String?) ?? 'Ingrediente';
            final grams = (i['grams'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      color: AppColors.primary, size: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(color: Colors.white)),
                  ),
                  Text('${grams.toStringAsFixed(0)} g',
                      style: const TextStyle(color: Colors.white60)),
                ],
              ),
            );
          }),
          if ((r['instructions'] as String?)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 18),
            const Text('Instrucciones',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 8),
            Text(r['instructions'] as String,
                style: const TextStyle(
                    color: Colors.white70, height: 1.4, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  RecipeMacros _calcMacros() {
    // ingredientes guardados solo tienen grams+food_name; sin macros por 100g
    // exactos al traer (food_id es nullable). Para Beta mostramos 0 cuando
    // no hay food_id; la calculadora real corre en CreateRecipeScreen.
    return RecipeMacros.zero;
  }

  Widget _buildHeroImage(String url) {
    return GestureDetector(
      onTap: () => _openFullscreen(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 220,
            color: AppColors.darkSurfaceCard,
          ),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  void _openFullscreen(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.broken_image, color: Colors.white54, size: 48),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceCard,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ],
          ),
        ),
      );

  Widget _macro(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
      );
}
