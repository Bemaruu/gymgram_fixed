import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../recipe_detail_screen.dart';

class RecipesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> recipes;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  /// Se llama cuando una receta se editó o eliminó desde el detalle, para que
  /// el padre recargue la lista.
  final VoidCallback? onChanged;

  const RecipesGrid({
    super.key,
    required this.recipes,
    this.shrinkWrap = true,
    this.physics,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Text(
            'Sin recetas todavia',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: recipes.length,
      itemBuilder: (_, i) {
        final r = recipes[i];
        final nested = r['user_recipes'] as Map<String, dynamic>?;
        final recipe = nested ?? r;
        final id = recipe['id'] as String? ?? r['recipe_id'] as String?;
        final name = (recipe['name'] as String?) ?? 'Receta';
        final image = recipe['image_url'] as String?;
        return GestureDetector(
          onTap: () async {
            if (id == null) return;
            final changed = await RecipeDetailScreen.open(context, id);
            if (changed == true) onChanged?.call();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null && image.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFFEEEEEE)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFFEEEEEE)),
                )
              else
                Container(
                  color: const Color(0xFFEEEEEE),
                  alignment: Alignment.center,
                  child: Icon(
                    PhosphorIconsRegular.forkKnife,
                    color: Colors.black38,
                    size: 28,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
