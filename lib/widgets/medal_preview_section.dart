import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import '../services/badge_service.dart';
import '../ui/medals/medal_detail_sheet.dart';
import '../ui/medals/medal_selector_screen.dart';
import '../ui/medals/user_medals_screen.dart';
import 'medal_widget.dart';

/// Sección "Medallero" que se inserta en cualquier pantalla de perfil.
/// Carga sus propios datos de forma independiente.
/// [isOwner] habilita edición de medallas destacadas.
class MedalPreviewSection extends StatefulWidget {
  final String userId;
  final bool isOwner;

  const MedalPreviewSection({
    super.key,
    required this.userId,
    this.isOwner = false,
  });

  @override
  State<MedalPreviewSection> createState() => _MedalPreviewSectionState();
}

class _MedalPreviewSectionState extends State<MedalPreviewSection> {
  bool _isLoading = true;
  List<BadgeModel> _featured = [];
  List<UserBadgeModel> _allEarned = [];
  Set<String> _earnedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BadgeService.instance.getUserBadges(widget.userId),
        BadgeService.instance.getFeaturedBadgeIds(widget.userId),
      ]);

      final allBadges = results[0] as List<UserBadgeModel>;
      final featuredIds = results[1] as List<String>;

      final earned = allBadges.where((b) => b.progress >= 1.0).toList();
      final earnedIds = earned.map((b) => b.badgeId).toSet();

      // Resolver medallas destacadas en orden
      List<BadgeModel> featured = featuredIds
          .map(BadgeService.getBadgeById)
          .whereType<BadgeModel>()
          .toList();

      // Si no hay destacadas, mostrar las primeras ganadas automáticamente
      if (featured.isEmpty && earned.isNotEmpty) {
        featured = earned
            .take(4)
            .map((ub) => BadgeService.getBadgeById(ub.badgeId))
            .whereType<BadgeModel>()
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _featured = featured;
        _allEarned = earned;
        _earnedIds = earnedIds;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openAllMedals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserMedalsScreen(
          userId: widget.userId,
          isOwner: widget.isOwner,
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _openSelector() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedalSelectorScreen(earnedBadges: _allEarned),
      ),
    );
    _load();
  }

  void _openDetail(BadgeModel badge) {
    UserBadgeModel? userBadge;
    try {
      userBadge = _allEarned.firstWhere((ub) => ub.badgeId == badge.id);
    } catch (_) {}

    showMedalDetail(
      context: context,
      badge: badge,
      userBadge: userBadge,
      isOwner: widget.isOwner,
      onFeaturedChanged: _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white38,
            ),
          ),
        ),
      );
    }

    final totalEarned = _earnedIds.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1221),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              const Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Medallero',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$totalEarned/${BadgeService.catalog.length}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              if (widget.isOwner)
                GestureDetector(
                  onTap: _openSelector,
                  child: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white38,
                    size: 18,
                  ),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _openAllMedals,
                child: const Text(
                  'Ver todos',
                  style: TextStyle(
                    color: Color(0xFF63C8FC),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Fila de medallas
          if (_featured.isEmpty)
            _EmptyMedalsHint(isOwner: widget.isOwner, onTap: _openAllMedals)
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._featured.take(4).map((badge) => MedalWidget(
                      badge: badge,
                      isEarned: _earnedIds.contains(badge.id),
                      size: 60,
                      showLabel: true,
                      onTap: () => _openDetail(badge),
                    )),
                // Slots vacíos si hay menos de 4
                ...List.generate(
                  (4 - _featured.length).clamp(0, 4),
                  (_) => _EmptySlot(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12, width: 2),
      ),
      child: const Icon(Icons.lock_outline, color: Colors.white12, size: 22),
    );
  }
}

class _EmptyMedalsHint extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onTap;

  const _EmptyMedalsHint({required this.isOwner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 32),
            const SizedBox(height: 8),
            Text(
              isOwner
                  ? 'Completa desafíos para ganar medallas'
                  : 'Este usuario aún no tiene medallas',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
