import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/recipe_service.dart';
import 'create_recipe_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final String recipeId;
  const RecipeDetailScreen({super.key, required this.recipeId});

  static Future<bool?> open(BuildContext context, String recipeId) {
    return Navigator.push<bool>(
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
  bool _changed = false;

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
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
          if (isMine)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: AppColors.darkSurfaceCard,
              onSelected: (v) {
                if (v == 'edit') _edit();
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Editar', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Eliminar',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
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
    ),
    );
  }

  Future<void> _edit() async {
    final changed =
        await CreateRecipeScreen.openEdit(context, widget.recipeId);
    if (changed == true && mounted) {
      _changed = true;
      setState(() => _loading = true);
      await _load();
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceCard,
        title: const Text('Eliminar receta',
            style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await RecipeService.instance.deleteRecipe(widget.recipeId);
    if (!mounted) return;
    if (deleted) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar. Intenta de nuevo.')),
      );
    }
  }

  RecipeMacros _calcMacros() {
    final inputs = _ingredients
        .map((i) => RecipeIngredientInput(
              grams: (i['grams'] as num?)?.toDouble() ?? 0,
              kcalPer100g: (i['kcal_per_100g'] as num?)?.toDouble() ?? 0,
              proteinPer100g: (i['protein_per_100g'] as num?)?.toDouble() ?? 0,
              carbsPer100g: (i['carbs_per_100g'] as num?)?.toDouble() ?? 0,
              fatPer100g: (i['fat_per_100g'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
    return RecipeService.instance.calculateMacros(inputs);
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
