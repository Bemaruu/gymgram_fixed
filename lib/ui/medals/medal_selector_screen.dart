import 'package:flutter/material.dart';
import '../../models/badge_model.dart';
import '../../services/badge_service.dart';
import '../../widgets/medal_widget.dart';

/// Pantalla para elegir hasta 4 medallas destacadas en el perfil.
/// Solo muestra las medallas que el usuario ya ha ganado.
class MedalSelectorScreen extends StatefulWidget {
  final List<UserBadgeModel> earnedBadges;

  const MedalSelectorScreen({super.key, required this.earnedBadges});

  @override
  State<MedalSelectorScreen> createState() => _MedalSelectorScreenState();
}

class _MedalSelectorScreenState extends State<MedalSelectorScreen> {
  List<String> _selected = [];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    setState(() => _isLoading = true);
    final featured = await BadgeService.instance.getMyFeaturedBadgeIds();
    if (!mounted) return;
    setState(() {
      _selected = featured;
      _isLoading = false;
    });
  }

  void _toggle(String badgeId) {
    setState(() {
      if (_selected.contains(badgeId)) {
        _selected.remove(badgeId);
      } else if (_selected.length < 4) {
        _selected.add(badgeId);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await BadgeService.instance.setFeaturedBadges(_selected);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('MedalSelector save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar. Inténtalo de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Construir lista de modelos completos de las medallas ganadas
    final earnedModels = widget.earnedBadges
        .map((ub) => BadgeService.getBadgeById(ub.badgeId))
        .whereType<BadgeModel>()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF080D17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1221),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medallas destacadas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              '${_selected.length}/4 seleccionadas',
              style: TextStyle(
                color: _selected.length >= 4
                    ? const Color(0xFFFFD700)
                    : Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Color(0xFF63C8FC),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : Column(
              children: [
                // Indicador visual de slots
                _SlotsPreview(
                  selectedIds: _selected,
                  earnedModels: earnedModels,
                ),
                const Divider(height: 1, color: Colors.white10),
                // Instrucción
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Text(
                    earnedModels.isEmpty
                        ? 'Aún no has ganado ninguna medalla. ¡Sigue entrenando!'
                        : 'Toca una medalla para agregarla o quitarla de tus destacadas.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
                // Grid de medallas ganadas
                Expanded(
                  child: earnedModels.isEmpty
                      ? const SizedBox.shrink()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: earnedModels.length,
                          itemBuilder: (_, i) {
                            final badge = earnedModels[i];
                            final isSelected = _selected.contains(badge.id);
                            final isFull =
                                _selected.length >= 4 && !isSelected;
                            return GestureDetector(
                              onTap: isFull ? null : () => _toggle(badge.id),
                              child: Opacity(
                                opacity: isFull ? 0.35 : 1.0,
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    MedalWidget(
                                      badge: badge,
                                      isEarned: true,
                                      size: 72,
                                      showLabel: true,
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFD700),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

/// Muestra 4 slots con las medallas actualmente seleccionadas.
class _SlotsPreview extends StatelessWidget {
  final List<String> selectedIds;
  final List<BadgeModel> earnedModels;

  const _SlotsPreview({required this.selectedIds, required this.earnedModels});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E1221),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (i) {
          if (i < selectedIds.length) {
            final badge = earnedModels
                .where((b) => b.id == selectedIds[i])
                .firstOrNull;
            if (badge != null) {
              return MedalWidget(badge: badge, isEarned: true, size: 58);
            }
          }
          return Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white12,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: const Icon(Icons.add, color: Colors.white12, size: 24),
          );
        }),
      ),
    );
  }
}
