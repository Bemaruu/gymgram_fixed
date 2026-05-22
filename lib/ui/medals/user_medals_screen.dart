import 'package:flutter/material.dart';
import '../../models/badge_model.dart';
import '../../services/badge_service.dart';
import '../../widgets/medal_widget.dart';
import 'medal_detail_sheet.dart';
import 'medal_selector_screen.dart';

/// Pantalla completa con todas las medallas del usuario.
/// [isOwner] muestra el botón de editar medallas destacadas.
class UserMedalsScreen extends StatefulWidget {
  final String userId;
  final bool isOwner;

  const UserMedalsScreen({
    super.key,
    required this.userId,
    this.isOwner = false,
  });

  @override
  State<UserMedalsScreen> createState() => _UserMedalsScreenState();
}

class _UserMedalsScreenState extends State<UserMedalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  List<UserBadgeModel> _userBadges = [];
  Set<String> _earnedIds = {};

  static const _tabs = [
    (label: 'Todas', rank: null),
    (label: 'Bronce', rank: BadgeRank.bronce),
    (label: 'Plata', rank: BadgeRank.plata),
    (label: 'Oro', rank: BadgeRank.oro),
    (label: 'Diamante', rank: BadgeRank.diamante),
    (label: 'Mineral', rank: BadgeRank.mineral),
    (label: 'Evento', rank: BadgeRank.evento),
    (label: 'Especial', rank: BadgeRank.especial),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final badges = await BadgeService.instance.getUserBadges(widget.userId);
      if (!mounted) return;
      setState(() {
        _userBadges = badges;
        _earnedIds = badges
            .where((b) => b.progress >= 1.0)
            .map((b) => b.badgeId)
            .toSet();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<BadgeModel> _badgesForTab(BadgeRank? rank) {
    final catalog = BadgeService.catalog;
    if (rank == null) return catalog;
    return catalog.where((b) => b.rank == rank).toList();
  }

  UserBadgeModel? _userBadgeFor(String badgeId) {
    try {
      return _userBadges.firstWhere((ub) => ub.badgeId == badgeId);
    } catch (_) {
      return null;
    }
  }

  void _openDetail(BadgeModel badge) {
    showMedalDetail(
      context: context,
      badge: badge,
      userBadge: _userBadgeFor(badge.id),
      isOwner: widget.isOwner,
      onFeaturedChanged: _load,
    );
  }

  Future<void> _openSelector() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedalSelectorScreen(
          earnedBadges: _userBadges.where((b) => b.progress >= 1.0).toList(),
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
              'Medallero',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            Text(
              '${_earnedIds.length} / ${BadgeService.catalog.length} conseguidas',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (widget.isOwner)
            TextButton.icon(
              onPressed: _isLoading ? null : _openSelector,
              icon: const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
              label: const Text(
                'Destacar',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : TabBarView(
              controller: _tabController,
              children: _tabs.map((t) {
                final badges = _badgesForTab(t.rank);
                return _MedalGrid(
                  badges: badges,
                  earnedIds: _earnedIds,
                  onTap: _openDetail,
                );
              }).toList(),
            ),
    );
  }
}

class _MedalGrid extends StatelessWidget {
  final List<BadgeModel> badges;
  final Set<String> earnedIds;
  final void Function(BadgeModel) onTap;

  const _MedalGrid({
    required this.badges,
    required this.earnedIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Ordenar: ganadas primero
    final sorted = [...badges]..sort((a, b) {
        final aEarned = earnedIds.contains(a.id) ? 0 : 1;
        final bEarned = earnedIds.contains(b.id) ? 0 : 1;
        return aEarned.compareTo(bEarned);
      });

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.75,
      ),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final badge = sorted[i];
        final isEarned = earnedIds.contains(badge.id);
        return MedalWidget(
          badge: badge,
          isEarned: isEarned,
          size: 72,
          showLabel: true,
          onTap: () => onTap(badge),
        );
      },
    );
  }
}
