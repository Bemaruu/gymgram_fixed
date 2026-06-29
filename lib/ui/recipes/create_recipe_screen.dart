import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/recipe_service.dart';
import '../plans/plans_screen.dart';
import 'widgets/ingredient_picker_sheet.dart';

class CreateRecipeScreen extends StatefulWidget {
  /// Si viene un recipeId, la pantalla edita esa receta en vez de crear una.
  final String? recipeId;
  const CreateRecipeScreen({super.key, this.recipeId});

  bool get isEditing => recipeId != null;

  static Future<bool?> open(BuildContext context) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateRecipeScreen()),
    );
  }

  static Future<bool?> openEdit(BuildContext context, String recipeId) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateRecipeScreen(recipeId: recipeId)),
    );
  }

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _nameCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _prepCtrl = TextEditingController();
  double _servings = 1;
  bool _isPublic = true;
  bool _saving = false;
  bool _canPublish = true;
  bool _loadingExisting = false;
  File? _imageFile;
  String? _existingImageUrl;
  final _picker = ImagePicker();
  final List<RecipeIngredientInput> _ingredients = [];
  final List<String> _ingredientLabels = [];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadingExisting = true;
      _loadExisting();
    } else {
      _checkPublishLimit();
    }
  }

  Future<void> _loadExisting() async {
    final id = widget.recipeId!;
    final recipe = await RecipeService.instance.getRecipe(id);
    final ingredients = await RecipeService.instance.getIngredients(id);
    final can = await RecipeService.instance.canPublishMore();
    if (!mounted) return;
    if (recipe == null) {
      setState(() => _loadingExisting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la receta.')),
      );
      Navigator.pop(context);
      return;
    }
    setState(() {
      _nameCtrl.text = (recipe['name'] as String?) ?? '';
      _instructionsCtrl.text = (recipe['instructions'] as String?) ?? '';
      final prep = recipe['prep_time_min'];
      _prepCtrl.text = prep == null ? '' : '$prep';
      _servings = (recipe['servings'] as num?)?.toDouble() ?? 1;
      _isPublic = recipe['is_public'] as bool? ?? false;
      _existingImageUrl = recipe['image_url'] as String?;
      // Si ya estaba pública, editar no cuenta para el límite; si era privada
      // y quiere publicarla, respetamos el límite Free.
      _canPublish = can || _isPublic;
      _ingredients.clear();
      _ingredientLabels.clear();
      for (final i in ingredients) {
        double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
        final name = (i['food_name_manual'] as String?) ?? 'Ingrediente';
        final grams = d(i['grams']);
        _ingredients.add(RecipeIngredientInput(
          foodId: i['food_id'] as String?,
          foodNameManual: name,
          grams: grams,
          kcalPer100g: d(i['kcal_per_100g']),
          proteinPer100g: d(i['protein_per_100g']),
          carbsPer100g: d(i['carbs_per_100g']),
          fatPer100g: d(i['fat_per_100g']),
        ));
        _ingredientLabels.add('$name - ${grams.toStringAsFixed(0)} g');
      }
      _loadingExisting = false;
    });
  }

  Future<void> _checkPublishLimit() async {
    final can = await RecipeService.instance.canPublishMore();
    if (!mounted) return;
    setState(() {
      _canPublish = can;
      // Si llegó al límite Free, no podemos publicar por defecto.
      if (!can) _isPublic = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _instructionsCtrl.dispose();
    _prepCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file != null) setState(() => _imageFile = File(file.path));
  }

  void _removeImage() => setState(() {
        _imageFile = null;
        _existingImageUrl = null;
      });

  Future<void> _addIngredient() async {
    final result = await IngredientPickerSheet.show(context);
    if (result == null) return;
    setState(() {
      _ingredients.add(result);
      _ingredientLabels.add(
        '${result.foodNameManual ?? '?'} - ${result.grams.toStringAsFixed(0)} g',
      );
    });
  }

  void _removeIngredient(int i) {
    setState(() {
      _ingredients.removeAt(i);
      _ingredientLabels.removeAt(i);
    });
  }

  Future<void> _onPublishToggle(bool v) async {
    if (v && !_canPublish) {
      HapticFeedback.mediumImpact();
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.darkSurfaceCard,
          title: const Text('Limite de publicaciones',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Los planes Free pueden publicar hasta 5 recetas. Hazte Plus o Premium para recetas ilimitadas.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentOrange),
              child: const Text('Ver planes'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await PlansScreen.open(context);
      }
      return;
    }
    setState(() => _isPublic = v);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _ingredients.isEmpty || _saving) return;
    setState(() => _saving = true);
    // Si eligió una foto nueva la subimos; si no, conservamos la existente.
    String? imageUrl = _existingImageUrl;
    if (_imageFile != null) {
      imageUrl = await RecipeService.instance.uploadRecipeImage(_imageFile!);
    }
    final instructions = _instructionsCtrl.text.trim().isEmpty
        ? null
        : _instructionsCtrl.text.trim();
    final prep = int.tryParse(_prepCtrl.text.trim());

    bool ok;
    if (widget.isEditing) {
      ok = await RecipeService.instance.updateRecipe(
        recipeId: widget.recipeId!,
        name: name,
        servings: _servings,
        prepTimeMin: prep,
        imageUrl: imageUrl,
        instructions: instructions,
        isPublic: _isPublic,
        ingredients: _ingredients,
      );
    } else {
      ok = await RecipeService.instance.createRecipe(
            name: name,
            servings: _servings,
            prepTimeMin: prep,
            imageUrl: imageUrl,
            instructions: instructions,
            isPublic: _isPublic,
            ingredients: _ingredients,
          ) !=
          null;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final macros = RecipeService.instance.calculateMacros(_ingredients);
    final perServing = _servings > 0 ? _servings : 1;
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.isEditing ? 'Editar receta' : 'Nueva receta',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: (_saving ||
                    _loadingExisting ||
                    _nameCtrl.text.trim().isEmpty ||
                    _ingredients.isEmpty)
                ? null
                : _save,
            child: Text(
              _saving ? '...' : 'Guardar',
              style: const TextStyle(
                color: AppColors.accentOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: _loadingExisting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildImagePicker(),
          const SizedBox(height: 12),
          _textField(_nameCtrl, 'Nombre de la receta'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberPicker(
                  label: 'Porciones',
                  value: _servings,
                  onChanged: (v) => setState(() => _servings = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(_prepCtrl, 'Prep (min)',
                    keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionHeader('Ingredientes'),
          ..._ingredientLabels.asMap().entries.map((e) => Card(
                color: AppColors.darkSurfaceCard,
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  title: Text(e.value,
                      style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => _removeIngredient(e.key),
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _addIngredient,
            icon: const Icon(Icons.add, color: AppColors.accentOrange),
            label: const Text('Agregar ingrediente',
                style: TextStyle(color: AppColors.accentOrange)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.accentOrange.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 18),
          if (_ingredients.isNotEmpty) ...[
            _sectionHeader('Macros por porcion'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  _macroChip(
                      'kcal', (macros.kcal / perServing).toStringAsFixed(0)),
                  _macroChip('P',
                      '${(macros.protein / perServing).toStringAsFixed(0)}g'),
                  _macroChip('C',
                      '${(macros.carbs / perServing).toStringAsFixed(0)}g'),
                  _macroChip(
                      'G', '${(macros.fat / perServing).toStringAsFixed(0)}g'),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          _sectionHeader('Instrucciones (opcional)'),
          _textField(_instructionsCtrl, 'Cuenta como prepararla...',
              maxLines: 5),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.accentOrange,
              title: const Text('Publicar en mi perfil',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(
                _canPublish
                    ? 'Otros usuarios podran ver y guardar tu receta.'
                    : 'Llegaste al limite Free de 5 recetas publicas.',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: _isPublic,
              onChanged: _onPublishToggle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _imageFile != null ||
        (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);
    if (hasImage) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _imageFile != null
                ? Image.file(
                    _imageFile!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: _existingImageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: _removeImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.camera,
                color: AppColors.accentOrange, size: 32),
            const SizedBox(height: 8),
            const Text(
              'Agregar foto (opcional)',
              style: TextStyle(
                color: AppColors.accentOrange,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          s,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );

  Widget _textField(
    TextEditingController c,
    String hint, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: AppColors.darkSurfaceCard,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _numberPicker({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Text(value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIconsBold.minus,
                size: 16, color: Colors.white70),
            onPressed: value > 0.5 ? () => onChanged(value - 0.5) : null,
          ),
          IconButton(
            icon: Icon(PhosphorIconsBold.plus,
                size: 16, color: AppColors.accentOrange),
            onPressed: () => onChanged(value + 0.5),
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value) {
    return Expanded(
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
}
