import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../models/leaderboard_entry_model.dart';
import '../../models/ranked_profile_model.dart';
import '../../models/routine_impact_model.dart';
import '../../models/season_reward_model.dart';
import '../../models/weekly_mission_model.dart';
import '../../services/ranked_service.dart';
import '../../services/subscription_service.dart';
import 'all_tiers_screen.dart';
import 'tier_up_overlay.dart';
import 'season_recap_screen.dart';

class RankedScreen extends StatefulWidget {
  const RankedScreen({super.key});

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends State<RankedScreen> {
  bool _loading = true;
  RankedProfile? _profile;
  RankedSeason? _season;
  List<WeeklyMission> _missions = const [];
  List<LeaderboardEntry> _globalBoard = const [];
  List<LeaderboardEntry> _friendsBoard = const [];
  List<SeasonReward> _history = const [];
  int _boardTab = 0; // 0 = amigos, 1 = global
  bool _isPremium = false;
  RoutineImpact? _impact;

  static const _prefsLastTierKey = 'ranked_last_seen_tier';

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  Future<void> _maybeShowOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('ranked_onboarded_v1') == true) return;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (_) => const _RankedOnboardingDialog(),
      );
      await prefs.setBool('ranked_onboarded_v1', true);
    } catch (_) {}
  }

  Future<void> _load() async {
    final svc = RankedService.instance;
    final results = await Future.wait<dynamic>([
      svc.getMyProfile(),
      svc.getActiveSeason(),
      svc.getWeeklyMissions(),
      svc.getGlobalLeaderboard(limit: 100),
      svc.getFriendsLeaderboard(),
      svc.getSeasonHistory(),
      SubscriptionService.instance.currentTier(),
    ]);
    if (!mounted) return;
    final profile = results[0] as RankedProfile?;
    final tier = results[6] as SubscriptionTier;
    final isPremium = tier == SubscriptionTier.premium;
    setState(() {
      _profile = profile;
      _season = results[1] as RankedSeason?;
      _missions = results[2] as List<WeeklyMission>;
      _globalBoard = results[3] as List<LeaderboardEntry>;
      _friendsBoard = results[4] as List<LeaderboardEntry>;
      _history = results[5] as List<SeasonReward>;
      _isPremium = isPremium;
      _loading = false;
    });
    if (profile != null) {
      _maybeShowPromotion(profile.tier);
    }
    if (isPremium) {
      final impact = await svc.getMyAggregatedImpact();
      if (mounted) setState(() => _impact = impact);
    }
  }

  Future<void> _maybeShowPromotion(RankedTier currentTier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRaw = prefs.getString(_prefsLastTierKey);
      final tierIdx = RankedTier.values.indexOf(currentTier);
      final lastIdx = lastRaw == null
          ? -1
          : RankedTier.values.indexWhere((t) => t.name == lastRaw);
      final profile = _profile;
      if (lastIdx >= 0 && tierIdx > lastIdx && mounted && profile != null) {
        await TierUpOverlay.show(
          context,
          oldTier: RankedTier.values[lastIdx],
          profile: profile,
          username: _currentUsername(),
        );
      }
      await prefs.setString(_prefsLastTierKey, currentTier.name);
    } catch (_) {}
  }

  /// Username del usuario actual, leído de los boards (best-effort).
  String _currentUsername() {
    final uid = RankedService.instance.currentUserId;
    for (final e in [..._friendsBoard, ..._globalBoard]) {
      if (e.userId == uid && e.username.isNotEmpty) return e.username;
    }
    return 'tú';
  }

  int _daysRemaining() {
    final s = _season;
    if (s == null) return 0;
    final d = s.endDate.difference(DateTime.now()).inDays;
    return d < 0 ? 0 : d;
  }

  void _openRecap() {
    final sid = _season?.id;
    if (sid == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SeasonRecapScreen(seasonId: sid),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            const Text(
              'Ranked',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 10),
            if (_season != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.accentOrange, width: 0.8),
                ),
                child: Text(
                  'S1 · ${_daysRemaining()}d',
                  style: const TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (_season != null)
            TextButton(
              onPressed: _openRecap,
              child: const Text(
                'Recap',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildHero(),
                    const SizedBox(height: 8),
                    _buildAllTiersButton(),
                    const SizedBox(height: 8),
                    _buildDecayBanner(),
                    const SizedBox(height: 12),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildNextTierGoals(),
                    if (_isPremium && _profile != null) ...[
                      const SizedBox(height: 16),
                      _buildImpactCard(),
                    ],
                    const SizedBox(height: 28),
                    _sectionTitle('Misiones de la semana'),
                    const SizedBox(height: 12),
                    _buildMissionsList(),
                    const SizedBox(height: 28),
                    _sectionTitle('Leaderboard'),
                    const SizedBox(height: 12),
                    _buildBoardToggle(),
                    const SizedBox(height: 12),
                    _buildLeaderboard(),
                    const SizedBox(height: 28),
                    _sectionTitle('Historial de temporadas'),
                    const SizedBox(height: 12),
                    _buildHistoryGrid(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // ----- Hero -----

  Widget _buildHero() {
    final p = _profile;

    // Estado "Sin rango" estilo videojuego competitivo cuando aún no hay perfil.
    if (p == null) {
      return Column(
        children: [
          _buildUnrankedEmblem(160),
          const SizedBox(height: 16),
          const Text(
            'SIN RANGO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '— RP',
            style: TextStyle(
              color: AppColors.accentOrange,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Container(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Completa tu primer entrenamiento para clasificarte',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final tier = p.tier;
    final color = _tierColor(tier);
    final isInmortal = tier == RankedTier.inmortal;
    final (lo, hi) = p.tierRange();
    final nextTier = _nextTierLabel(tier);

    return Column(
      children: [
        if (_season != null) _SeasonHeroBanner(season: _season!),
        _isPremium
            ? _RotatingGradientBorder(
                size: 168,
                child: TierEmblem(tier: tier, size: 150, animated: true),
              )
            : TierEmblem(tier: tier, size: 150, animated: true),
        const SizedBox(height: 14),
        Text(
          isInmortal
              ? _tierLabel(tier).toUpperCase()
              : '${_tierLabel(tier).toUpperCase()} ${p.romanDivision()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isInmortal ? '${p.currentRp} RP' : '${p.currentRp} / $hi RP',
          style: const TextStyle(
            color: AppColors.accentOrange,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (!isInmortal)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_tierLabel(tier).toUpperCase()} ${p.romanDivision()}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '${(hi - p.currentRp).clamp(0, hi)} RP → ${_nextTierLabel(tier).toUpperCase()} ${_nextTierFirstDivision(tier)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        _TierProgressBar(
          progress: isInmortal ? 1.0 : p.progressToNextTier().clamp(0.0, 1.0),
          tierColor: color,
        ),
        const SizedBox(height: 8),
        Text(
          isInmortal ? 'Élite mundial' : 'Próximo: $nextTier',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        // Texto de ayuda con el rango lo-hi (oculto en inmortal)
        if (!isInmortal) const SizedBox(height: 2),
        if (!isInmortal)
          Text(
            'Tier $lo - $hi RP',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
      ],
    );
  }

  Widget _buildAllTiersButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AllTiersScreen(currentTier: _profile?.tier),
          ));
        },
        icon: Icon(PhosphorIconsRegular.listDashes,
            color: Colors.white70, size: 16),
        label: const Text(
          'Ver todos los rangos',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static String _nextTierFirstDivision(RankedTier t) {
    // Al subir de tier se entra en la division III (la más baja).
    // Para inmortal no hay división, devolvemos cadena vacía.
    if (t == RankedTier.diamante) return '';
    return 'III';
  }

  Widget _buildDecayBanner() {
    final p = _profile;
    if (p == null) return const SizedBox.shrink();
    final tierIdx = RankedTier.values.indexOf(p.tier);
    if (tierIdx < RankedTier.values.indexOf(RankedTier.plata)) {
      return const SizedBox.shrink();
    }
    final last = p.lastRecalcAt;
    if (last == null) return const SizedBox.shrink();
    final diffH = DateTime.now().difference(last).inHours;
    if (diffH < 36) return const SizedBox.shrink();
    final hoursUntilDecay = 48 - diffH.clamp(0, 48);
    return _DecayWarningBanner(
      hoursUntilDecay: hoursUntilDecay,
      onStartRoutine: () {
        Navigator.of(context).pushNamed('/rutina_screen');
      },
    );
  }

  // Emblema neutral para usuarios sin perfil ranked todavía.
  Widget _buildUnrankedEmblem(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: Center(
        child: Icon(
          PhosphorIconsRegular.question,
          color: Colors.white24,
          size: size * 0.4,
        ),
      ),
    );
  }

  IconData _iconForTier(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return PhosphorIconsFill.hexagon;
      case RankedTier.bronce:
        return PhosphorIconsFill.shield;
      case RankedTier.plata:
        return PhosphorIconsFill.shield;
      case RankedTier.oro:
        return PhosphorIconsFill.shieldStar;
      case RankedTier.platino:
        return PhosphorIconsFill.diamond;
      case RankedTier.diamante:
        return PhosphorIconsFill.diamondsFour;
      case RankedTier.inmortal:
        return PhosphorIconsFill.crown;
    }
  }

  // ----- Stats row -----

  Widget _buildStatsRow() {
    final p = _profile;
    return _PillarBars(
      strength: p?.strengthScore ?? 0,
      consistency: p?.consistencyScore ?? 0,
      community: p?.communityScore ?? 0,
      challenge: p?.challengeScore ?? 0,
    );
  }

  // ----- Objetivos próximo tier (Tarea 11) -----

  Widget _buildNextTierGoals() {
    final p = _profile;
    if (p == null) return const SizedBox.shrink();
    final color = _tierColor(p.tier);

    if (p.tier == RankedTier.inmortal) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: const Text(
          '🔥 Eres top 500 global. Mantén tu posición — el decay es agresivo aquí.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      );
    }

    final (_, hi) = p.tierRange();
    final rpToNext = (hi - p.currentRp).clamp(0, hi);
    final nextTier = _nextTierLabel(p.tier).toUpperCase();
    final nextDivision = _nextTierFirstDivision(p.tier);

    // Aproximaciones razonables.
    // Strength aporta ~40% del RP: delta strength ~ rpToNext * 0.40.
    final strengthDelta = (rpToNext * 0.40).round();
    // Consistencia: objetivo de racha simple.
    final streakGoal = 7;
    final currentStreak = (p.consistencyScore ~/ 40).clamp(0, streakGoal);
    // Misiones activas no completadas esta semana.
    final pendingMissions =
        _missions.where((m) => !m.completed).length;

    final goals = <_TierGoalData>[
      _TierGoalData(
        done: strengthDelta <= 0,
        text: 'Sube tu fuerza (registra PRs en ejercicios RANKED)',
        value: '+$strengthDelta',
      ),
      _TierGoalData(
        done: currentStreak >= streakGoal,
        text: 'Mantén tu racha activa',
        value: '$currentStreak/$streakGoal',
      ),
      _TierGoalData(
        done: pendingMissions == 0,
        text: 'Completa misiones semanales',
        value: '$pendingMissions',
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.target, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rpToNext <= 100
                      ? '¡Estás muy cerca de $nextTier $nextDivision!'
                      : 'Objetivos para $nextTier $nextDivision',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < goals.length; i++) ...[
            _tierGoalRow(goals[i]),
            if (i != goals.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _tierGoalRow(_TierGoalData g) {
    return Row(
      children: [
        Icon(
          g.done
              ? PhosphorIconsFill.checkCircle
              : PhosphorIconsRegular.circle,
          color: g.done ? const Color(0xFF2ECC71) : Colors.white38,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            g.text,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          g.value,
          style: const TextStyle(
            color: AppColors.accentOrange,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ----- Tu impacto (Premium, Tarea 12) -----

  Widget _buildImpactCard() {
    final impact = _impact;
    final copies = impact?.totalCopies ?? 0;
    final viaCopy = impact?.totalWorkoutsViaCopy ?? 0;
    final tierUps = impact?.totalUsersTierUpgraded ?? 0;
    final allZero = copies == 0 && viaCopy == 0 && tierUps == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(PhosphorIconsFill.sparkle,
                  color: Color(0xFFFFD700), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Tu impacto',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allZero)
            const Text(
              'Publica tu próxima rutina pública y mide tu impacto.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            )
          else
            Row(
              children: [
                _impactStat('$copies', 'copiaron tus rutinas'),
                _impactStat('$viaCopy', 'workouts vía tu rutina'),
                _impactStat('$tierUps', 'tier-ups inspirados'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _impactStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.accentOrange,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ----- Misiones -----

  Widget _buildMissionsList() {
    if (_missions.isEmpty) {
      return _emptyBox('Misiones disponibles próximamente');
    }
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) => _missionCard(_missions[i]),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: _missions.length,
      ),
    );
  }

  Widget _missionCard(WeeklyMission m) {
    final color = _missionDifficultyColor(m.difficulty);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_missionCategoryIcon(m.category), color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  m.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (m.completed)
                const Icon(Icons.check_circle,
                    color: Color(0xFF2ECC71), size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m.description,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: m.progressPct,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${m.currentProgress}/${m.targetValue}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                '+${m.rpReward} RP',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----- Leaderboard -----

  Widget _buildBoardToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _toggleButton('Amigos', 0),
          _toggleButton('Global', 1),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, int idx) {
    final active = _boardTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _boardTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? AppColors.darkSurface : Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    final list = _boardTab == 0 ? _friendsBoard : _globalBoard;
    if (list.isEmpty) {
      return _emptyBox(_boardTab == 0
          ? 'Sigue a amigos para ver su rango'
          : 'Sin datos de leaderboard aún');
    }
    final uid = RankedService.instance.currentUserId;
    final hasPodium = list.length >= 3;
    final rest = hasPodium ? list.skip(3).take(17).toList() : list.take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPodium)
          _LeaderboardPodium(top3: list.take(3).toList(), tierColorOf: _tierColor),
        ...rest.map((e) => _boardRow(e, e.userId == uid)),
      ],
    );
  }

  Widget _boardRow(LeaderboardEntry e, bool isMe) {
    final color = _tierColor(e.tier);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: isMe
            ? Border.all(color: AppColors.accentOrange, width: 1.4)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${e.globalRank}',
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.darkSurfaceElevated,
            backgroundImage:
                e.avatarUrl != null ? NetworkImage(e.avatarUrl!) : null,
            child: e.avatarUrl == null
                ? const Icon(Icons.person, color: Colors.white54, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              e.username.isEmpty ? 'Usuario' : e.username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMe && _isPremium) ...[
            _premiumBadge(),
            const SizedBox(width: 6),
          ],
          Icon(_iconForTier(e.tier), color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            '${e.currentRp}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFD700), width: 1),
      ),
      child: const Text(
        'PREMIUM',
        style: TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ----- Historial de temporadas -----

  Widget _buildHistoryGrid() {
    if (_history.isEmpty) {
      return _emptyBox(_profile == null
          ? 'Tu primera temporada está en curso'
          : 'Tus medallas aparecerán al cerrar la primera temporada');
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, i) => _historyMedal(_history[i]),
    );
  }

  Widget _historyMedal(SeasonReward r) {
    final tier = r.finalTier ?? RankedTier.hierro;
    final color = _tierColor(tier);
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.darkSurfaceElevated,
          content: Text(
            'Temporada: ${_tierLabel(tier)} · ${r.finalRp ?? 0} RP',
            style: const TextStyle(color: Colors.white),
          ),
        ));
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.45),
              color.withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
        ),
        child: Center(
          child: Icon(_iconForTier(tier), color: color, size: 36),
        ),
      ),
    );
  }

  // ----- Helpers visuales -----

  Widget _sectionTitle(String t) => Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      );

  Widget _emptyBox(String msg) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );

  static Color _tierColor(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return const Color(0xFF7A7A7A);
      case RankedTier.bronce:
        return const Color(0xFFB87333);
      case RankedTier.plata:
        return const Color(0xFFA0A8B0);
      case RankedTier.oro:
        return const Color(0xFFE2B23B);
      case RankedTier.platino:
        return const Color(0xFF4FC3D8);
      case RankedTier.diamante:
        return const Color(0xFF6A8DFF);
      case RankedTier.inmortal:
        return const Color(0xFFB14CFF);
    }
  }

  static String _tierLabel(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return 'Hierro';
      case RankedTier.bronce:
        return 'Bronce';
      case RankedTier.plata:
        return 'Plata';
      case RankedTier.oro:
        return 'Oro';
      case RankedTier.platino:
        return 'Platino';
      case RankedTier.diamante:
        return 'Diamante';
      case RankedTier.inmortal:
        return 'Inmortal';
    }
  }

  static String _nextTierLabel(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return 'Bronce';
      case RankedTier.bronce:
        return 'Plata';
      case RankedTier.plata:
        return 'Oro';
      case RankedTier.oro:
        return 'Platino';
      case RankedTier.platino:
        return 'Diamante';
      case RankedTier.diamante:
        return 'Inmortal';
      case RankedTier.inmortal:
        return 'Élite';
    }
  }

  static Color _missionDifficultyColor(MissionDifficulty d) {
    switch (d) {
      case MissionDifficulty.easy:
        return const Color(0xFF2ECC71);
      case MissionDifficulty.medium:
        return AppColors.primary;
      case MissionDifficulty.hard:
        return AppColors.accentOrange;
    }
  }

  static IconData _missionCategoryIcon(MissionCategory c) {
    switch (c) {
      case MissionCategory.strength:
        return PhosphorIconsFill.barbell;
      case MissionCategory.consistency:
        return PhosphorIconsFill.flame;
      case MissionCategory.community:
        return PhosphorIconsFill.users;
      case MissionCategory.challenge:
        return PhosphorIconsFill.target;
    }
  }
}

// ============================================================
// _TierProgressBar — barra segmentada con shimmer cerca del próximo tier
// ============================================================

class _TierProgressBar extends StatefulWidget {
  final double progress; // 0..1
  final Color tierColor;
  const _TierProgressBar({required this.progress, required this.tierColor});

  @override
  State<_TierProgressBar> createState() => _TierProgressBarState();
}

class _TierProgressBarState extends State<_TierProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.progress >= 0.85) {
      _shimmer.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _TierProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress >= 0.85 && !_shimmer.isAnimating) {
      _shimmer.repeat();
    } else if (widget.progress < 0.85 && _shimmer.isAnimating) {
      _shimmer.stop();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double height = 14;
    const double radius = 7;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            height: height,
            width: width,
            child: Stack(
              children: [
                Container(color: Colors.white.withValues(alpha: 0.08)),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [widget.tierColor, const Color(0xFFFF6B35)],
                      ),
                    ),
                  ),
                ),
                if (widget.progress >= 0.85)
                  AnimatedBuilder(
                    animation: _shimmer,
                    builder: (_, __) {
                      final dx = (_shimmer.value * 2 - 1) * width;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: Container(
                          width: width * 0.4,
                          height: height,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.35),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Positioned(
                  left: width * 0.333,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                Positioned(
                  left: width * 0.666,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1.5,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// _LeaderboardPodium — top 3 con corona animada en #1
// ============================================================

class _LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final Color Function(RankedTier) tierColorOf;
  const _LeaderboardPodium({required this.top3, required this.tierColorOf});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 10,
            child: _PodiumSlot(
              entry: top3[1],
              rank: 2,
              platoHeight: 70,
              color: const Color(0xFFC0C0C0),
            ),
          ),
          Expanded(
            flex: 12,
            child: _PodiumSlot(
              entry: top3[0],
              rank: 1,
              platoHeight: 100,
              color: const Color(0xFFFFD700),
            ),
          ),
          Expanded(
            flex: 10,
            child: _PodiumSlot(
              entry: top3[2],
              rank: 3,
              platoHeight: 50,
              color: const Color(0xFFCD7F32),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatefulWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double platoHeight;
  final Color color;
  const _PodiumSlot({
    required this.entry,
    required this.rank,
    required this.platoHeight,
    required this.color,
  });

  @override
  State<_PodiumSlot> createState() => _PodiumSlotState();
}

class _PodiumSlotState extends State<_PodiumSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _crown;

  @override
  void initState() {
    super.initState();
    _crown = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.rank == 1) {
      _crown.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _crown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.rank == 1;
    final avatarSize = isFirst ? 84.0 : 60.0;
    final avatarRadius = avatarSize / 2;
    final avatar = CircleAvatar(
      radius: avatarRadius,
      backgroundColor: AppColors.darkSurfaceElevated,
      backgroundImage: widget.entry.avatarUrl != null
          ? NetworkImage(widget.entry.avatarUrl!)
          : null,
      child: widget.entry.avatarUrl == null
          ? Icon(Icons.person,
              color: Colors.white54, size: avatarSize * 0.55)
          : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isFirst)
          SizedBox(
            width: avatarSize + 12,
            height: avatarSize + 22,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFFFD700), width: 2),
                  ),
                  child: ClipOval(child: avatar),
                ),
                Positioned(
                  top: -18,
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _crown,
                      curve: Curves.easeInOut,
                    ).drive(Tween<double>(begin: 1.0, end: 1.08)),
                    child: const Icon(
                      PhosphorIconsFill.crown,
                      size: 28,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          avatar,
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '@${widget.entry.username.isEmpty ? 'usuario' : widget.entry.username}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Text(
          '${widget.entry.currentRp} RP',
          style: TextStyle(
            color: widget.color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: widget.platoHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.color, widget.color.withValues(alpha: 0.3)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${widget.rank}',
              style: TextStyle(
                fontSize: isFirst ? 40 : 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// _DecayWarningBanner — alerta sticky de pérdida de RP
// ============================================================

class _DecayWarningBanner extends StatelessWidget {
  final int hoursUntilDecay;
  final VoidCallback onStartRoutine;
  const _DecayWarningBanner({
    required this.hoursUntilDecay,
    required this.onStartRoutine,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6B35);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: orange.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIconsFill.warning, size: 22, color: orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu rango pierde 15 RP en ${hoursUntilDecay}h',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Entrena hoy para mantener tu posición',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onStartRoutine,
            child: const Text(
              'Iniciar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TierEmblem — emblema custom por tier con CustomPainter
// ============================================================

class _TierGoalData {
  final bool done;
  final String text;
  final String value;
  _TierGoalData({required this.done, required this.text, required this.value});
}

// ============================================================
// _RotatingGradientBorder — anillo animado premium (Tarea 12)
// ============================================================

class _RotatingGradientBorder extends StatefulWidget {
  final double size;
  final Widget child;
  const _RotatingGradientBorder({required this.size, required this.child});

  @override
  State<_RotatingGradientBorder> createState() =>
      _RotatingGradientBorderState();
}

class _RotatingGradientBorderState extends State<_RotatingGradientBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _spin,
            builder: (_, __) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RingPainter(phase: _spin.value),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double phase;
  _RingPainter({required this.phase});

  static const _gold = Color(0xFFFFD700);
  static const _orange = Color(0xFFFF6B35);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..shader = SweepGradient(
        transform: GradientRotation(phase * 2 * math.pi),
        colors: const [_gold, _orange, _gold],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: radius));
    canvas.drawCircle(c, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.phase != phase;
}

// ============================================================
// _RankedOnboardingDialog — primera entrada al modo ranked (Tarea 10)
// ============================================================

class _RankedOnboardingDialog extends StatefulWidget {
  const _RankedOnboardingDialog();

  @override
  State<_RankedOnboardingDialog> createState() =>
      _RankedOnboardingDialogState();
}

class _RankedOnboardingDialogState extends State<_RankedOnboardingDialog> {
  final _controller = PageController();
  int _page = 0;
  static const _pages = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: media.width * 0.9,
        height: media.height * 0.7,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: const [
                _OnboardingPagePillars(),
                _OnboardingPageRiseUp(),
                _OnboardingPageSeason(),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Saltar',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < _pages; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? AppColors.accentOrange
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _page == _pages - 1
                            ? 'Entendido, vamos'
                            : 'Siguiente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPagePillars extends StatelessWidget {
  const _OnboardingPagePillars();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIconsFill.target,
              size: 56, color: AppColors.accentOrange),
          const SizedBox(height: 18),
          const Text(
            '4 pilares forjan tu rango',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cada uno aporta un peso distinto al RP',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 28),
          _miniBar('Strength', 40, AppColors.accentOrange),
          _miniBar('Consistency', 35, const Color(0xFFFF8C42)),
          _miniBar('Community', 15, const Color(0xFF6A8DFF)),
          _miniBar('Challenge', 10, const Color(0xFFE2B23B)),
        ],
      ),
    );
  }

  Widget _miniBar(String label, int pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pct%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageRiseUp extends StatelessWidget {
  const _OnboardingPageRiseUp();

  @override
  Widget build(BuildContext context) {
    const bullets = [
      'Registra peso en ejercicios RANKED',
      'Mantén racha activa',
      'Publica rutinas (te copian = +RP)',
      'Completa misiones semanales',
      'Sé constante 3+ veces/semana',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Icon(PhosphorIconsFill.trendUp,
                size: 56, color: AppColors.accentOrange),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Sube de tier',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...bullets.map((b) => _bullet(b)),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsFill.checkCircle,
              color: Color(0xFF2ECC71), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageSeason extends StatelessWidget {
  const _OnboardingPageSeason();

  @override
  Widget build(BuildContext context) {
    const bullets = [
      'Soft reset 1 tier abajo (tope Oro I)',
      'Strength NO se resetea',
      'Medalla persistente Pico T1',
      'Marco animado (eterno si Diamante+)',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Icon(PhosphorIconsFill.crown,
                size: 56, color: Color(0xFFE2B23B)),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Cada 3 meses, nueva temporada',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...bullets.map((b) => _bullet(b)),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(PhosphorIconsFill.checkCircle,
              color: Color(0xFF2ECC71), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color tierColorOf(RankedTier t) {
  switch (t) {
    case RankedTier.hierro:
      return const Color(0xFF7A7A7A);
    case RankedTier.bronce:
      return const Color(0xFFB87333);
    case RankedTier.plata:
      return const Color(0xFFA0A8B0);
    case RankedTier.oro:
      return const Color(0xFFE2B23B);
    case RankedTier.platino:
      return const Color(0xFF4FC3D8);
    case RankedTier.diamante:
      return const Color(0xFF6A8DFF);
    case RankedTier.inmortal:
      return const Color(0xFFB14CFF);
  }
}

String tierLabelOf(RankedTier t) {
  switch (t) {
    case RankedTier.hierro:
      return 'Hierro';
    case RankedTier.bronce:
      return 'Bronce';
    case RankedTier.plata:
      return 'Plata';
    case RankedTier.oro:
      return 'Oro';
    case RankedTier.platino:
      return 'Platino';
    case RankedTier.diamante:
      return 'Diamante';
    case RankedTier.inmortal:
      return 'Inmortal';
  }
}

class TierEmblem extends StatefulWidget {
  final RankedTier tier;
  final double size;
  final bool animated;
  const TierEmblem({
    super.key,
    required this.tier,
    required this.size,
    this.animated = true,
  });

  @override
  State<TierEmblem> createState() => _TierEmblemState();
}

class _TierEmblemState extends State<TierEmblem>
    with TickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animated) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = tierColorOf(widget.tier);
    final size = widget.size;
    final isDiamondPlus =
        widget.tier == RankedTier.diamante || widget.tier == RankedTier.inmortal;
    final accent = _emblemAccent(widget.tier);

    return AnimatedBuilder(
      animation: _breath,
      builder: (_, __) {
        final scale = 1.0 + (widget.animated ? _breath.value * 0.03 : 0.0);
        final curved = Curves.easeInOut.transform(_breath.value);
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Glow externo + radial gradient base
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.50),
                        color.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(
                            alpha: isDiamondPlus ? 0.85 : 0.55),
                        blurRadius: size * 0.22,
                        spreadRadius: size * 0.025,
                      ),
                    ],
                  ),
                ),
                // Silueta CustomPaint del tier
                SizedBox(
                  width: size * 0.62,
                  height: size * 0.62,
                  child: CustomPaint(
                    painter: TierEmblemPainter(
                      tier: widget.tier,
                      baseColor: color,
                      accentColor: accent,
                    ),
                  ),
                ),
                // Partículas orbitando — solo diamante+inmortal
                if (isDiamondPlus && widget.animated)
                  Positioned.fill(
                    child: OrbitParticles(
                      color: widget.tier == RankedTier.inmortal
                          ? const Color(0xFFEDD7FF)
                          : Colors.white,
                      radius: size * 0.45,
                      count: 8,
                      progress: curved,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _emblemAccent(RankedTier t) {
    switch (t) {
      case RankedTier.hierro:
        return const Color(0xFFB8B8B8);
      case RankedTier.bronce:
        return const Color(0xFFE8A360);
      case RankedTier.plata:
        return const Color(0xFFEDEEF1);
      case RankedTier.oro:
        return const Color(0xFFFFEB99);
      case RankedTier.platino:
        return const Color(0xFFBFF1FA);
      case RankedTier.diamante:
        return const Color(0xFFB3CBFF);
      case RankedTier.inmortal:
        return const Color(0xFFE9CDFF);
    }
  }
}

class TierEmblemPainter extends CustomPainter {
  final RankedTier tier;
  final Color baseColor;
  final Color accentColor;
  TierEmblemPainter({
    required this.tier,
    required this.baseColor,
    required this.accentColor,
  });

  // Stroke escalado con el tamaño del emblema (se setea en paint()).
  double _sw = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    _sw = size.shortestSide * 0.028;
    switch (tier) {
      case RankedTier.hierro:
        _drawGear(canvas, size);
        break;
      case RankedTier.bronce:
        _drawShield(canvas, size, withRivets: true);
        break;
      case RankedTier.plata:
        _drawPentagonFaceted(canvas, size);
        break;
      case RankedTier.oro:
        _drawShieldWithCrown(canvas, size);
        break;
      case RankedTier.platino:
        _drawCrystal(canvas, size);
        break;
      case RankedTier.diamante:
        _drawDiamondPrism(canvas, size);
        break;
      case RankedTier.inmortal:
        _drawWingedCrown(canvas, size);
        break;
    }
  }

  Paint get _strokeAccent => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _sw
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = accentColor.withValues(alpha: 0.92);

  // Contorno oscuro inferior que se dibuja antes del accent: separa la
  // silueta del fondo y da sensación de borde biselado.
  Paint get _strokeUnder => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _sw * 1.6
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = baseColor.withValues(alpha: 0.40);

  Paint _highlightPaint(Size size) => Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      begin: const Alignment(-0.3, -0.8),
      end: Alignment.bottomCenter,
      colors: [
        accentColor.withValues(alpha: 0.95),
        baseColor.withValues(alpha: 0.55),
        baseColor.withValues(alpha: 0.22),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Offset.zero & size);

  // Pinta una silueta con volumen: relleno direccional + bisel (reflejo
  // superior y sombra inferior clippeados al path) + doble contorno.
  void _paintShape(Canvas canvas, Size size, Path path) {
    canvas.drawPath(path, _highlightPaint(size));
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: 0.28), Colors.transparent],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.center,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.26)],
        ).createShader(Offset.zero & size),
    );
    canvas.restore();
    canvas.drawPath(path, _strokeUnder);
    canvas.drawPath(path, _strokeAccent);
  }

  void _pt(Path p, Offset c, double r, double a, bool first) {
    final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    first ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }

  void _drawGear(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rOuter = size.shortestSide * 0.46;
    final rInner = size.shortestSide * 0.38; // diente menos profundo
    const teeth = 6;
    const halfTooth = 6 * math.pi / 180; // meseta plana ±6°
    final step = 2 * math.pi / teeth;
    final path = Path();
    for (int i = 0; i < teeth; i++) {
      final a = -math.pi / 2 + i * step;
      _pt(path, c, rInner, a - step * 0.5, i == 0); // valle
      _pt(path, c, rOuter, a - halfTooth, false); // meseta izq
      _pt(path, c, rOuter, a + halfTooth, false); // meseta der
    }
    path.close();
    _paintShape(canvas, size, path);
    // anillo concéntrico interno (lectura mecánica de engranaje)
    canvas.drawCircle(
      c,
      size.shortestSide * 0.26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _sw * 0.7
        ..color = accentColor.withValues(alpha: 0.4),
    );
    // hueco central
    final hole = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1A1A2E);
    canvas.drawCircle(c, size.shortestSide * 0.18, hole);
    canvas.drawCircle(c, size.shortestSide * 0.18, _strokeAccent);
  }

  void _drawShield(Canvas canvas, Size size, {bool withRivets = false}) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.92, h * 0.18)
      ..lineTo(w * 0.88, h * 0.62)
      ..quadraticBezierTo(w * 0.7, h * 0.92, w * 0.5, h * 0.97)
      ..quadraticBezierTo(w * 0.3, h * 0.92, w * 0.12, h * 0.62)
      ..lineTo(w * 0.08, h * 0.18)
      ..close();
    _paintShape(canvas, size, path);
    if (withRivets) {
      final rivet = Paint()
        ..style = PaintingStyle.fill
        ..color = accentColor;
      final positions = [
        Offset(w * 0.18, h * 0.22),
        Offset(w * 0.82, h * 0.22),
        Offset(w * 0.18, h * 0.5),
        Offset(w * 0.82, h * 0.5),
        Offset(w * 0.35, h * 0.82),
        Offset(w * 0.65, h * 0.82),
      ];
      for (final p in positions) {
        canvas.drawCircle(p, size.shortestSide * 0.025, rivet);
      }
    }
  }

  void _drawPentagonFaceted(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.45;
    final path = Path();
    final vertices = <Offset>[];
    for (int i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + (i / 5) * 2 * math.pi;
      final p = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      vertices.add(p);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    _paintShape(canvas, size, path);
    // facetas radiales
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: 0.6);
    for (final v in vertices) {
      canvas.drawLine(c, v, facet);
    }
  }

  void _drawShieldWithCrown(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shieldRect = Rect.fromLTWH(0, h * 0.22, w, h * 0.78);
    canvas.save();
    canvas.translate(shieldRect.left, shieldRect.top);
    _drawShield(canvas, Size(shieldRect.width, shieldRect.height));
    canvas.restore();
    // corona arriba: 3 picos triangulares con bolitas
    final crown = Path()
      ..moveTo(w * 0.25, h * 0.22)
      ..lineTo(w * 0.32, h * 0.05)
      ..lineTo(w * 0.4, h * 0.18)
      ..lineTo(w * 0.5, h * 0.02)
      ..lineTo(w * 0.6, h * 0.18)
      ..lineTo(w * 0.68, h * 0.05)
      ..lineTo(w * 0.75, h * 0.22)
      ..close();
    _paintShape(canvas, size, crown);
    final ball = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor;
    canvas.drawCircle(Offset(w * 0.32, h * 0.05), size.shortestSide * 0.03, ball);
    canvas.drawCircle(Offset(w * 0.5, h * 0.02), size.shortestSide * 0.035, ball);
    canvas.drawCircle(Offset(w * 0.68, h * 0.05), size.shortestSide * 0.03, ball);
  }

  void _drawCrystal(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.03)
      ..lineTo(w * 0.82, h * 0.35)
      ..lineTo(w * 0.5, h * 0.97)
      ..lineTo(w * 0.18, h * 0.35)
      ..close();
    _paintShape(canvas, size, path);
    // facetas internas
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: 0.6);
    canvas.drawLine(Offset(w * 0.5, h * 0.03), Offset(w * 0.5, h * 0.97), facet);
    canvas.drawLine(Offset(w * 0.18, h * 0.35), Offset(w * 0.82, h * 0.35), facet);
    canvas.drawLine(Offset(w * 0.32, h * 0.19), Offset(w * 0.5, h * 0.35), facet);
    canvas.drawLine(Offset(w * 0.68, h * 0.19), Offset(w * 0.5, h * 0.35), facet);
  }

  void _drawDiamondPrism(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // hexagono superior + faldas
    final path = Path()
      ..moveTo(w * 0.2, h * 0.35)
      ..lineTo(w * 0.35, h * 0.15)
      ..lineTo(w * 0.65, h * 0.15)
      ..lineTo(w * 0.8, h * 0.35)
      ..lineTo(w * 0.5, h * 0.95)
      ..close();
    _paintShape(canvas, size, path);
    final facet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = accentColor.withValues(alpha: 0.75);
    canvas.drawLine(Offset(w * 0.2, h * 0.35), Offset(w * 0.8, h * 0.35), facet);
    canvas.drawLine(Offset(w * 0.35, h * 0.15), Offset(w * 0.5, h * 0.95), facet);
    canvas.drawLine(Offset(w * 0.65, h * 0.15), Offset(w * 0.5, h * 0.95), facet);
    canvas.drawLine(Offset(w * 0.2, h * 0.35), Offset(w * 0.5, h * 0.95), facet);
    canvas.drawLine(Offset(w * 0.8, h * 0.35), Offset(w * 0.5, h * 0.95), facet);
    canvas.drawLine(Offset(w * 0.5, h * 0.15), Offset(w * 0.5, h * 0.95), facet);
  }

  void _drawWingedCrown(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // alas izquierda y derecha (curvas)
    final leftWing = Path()
      ..moveTo(w * 0.5, h * 0.45)
      ..quadraticBezierTo(w * 0.15, h * 0.25, w * 0.02, h * 0.55)
      ..quadraticBezierTo(w * 0.2, h * 0.55, w * 0.5, h * 0.7)
      ..close();
    final rightWing = Path()
      ..moveTo(w * 0.5, h * 0.45)
      ..quadraticBezierTo(w * 0.85, h * 0.25, w * 0.98, h * 0.55)
      ..quadraticBezierTo(w * 0.8, h * 0.55, w * 0.5, h * 0.7)
      ..close();
    _paintShape(canvas, size, leftWing);
    _paintShape(canvas, size, rightWing);
    // corona central 3 picos
    final crown = Path()
      ..moveTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.35, h * 0.15)
      ..lineTo(w * 0.42, h * 0.4)
      ..lineTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.58, h * 0.4)
      ..lineTo(w * 0.65, h * 0.15)
      ..lineTo(w * 0.7, h * 0.55)
      ..close();
    _paintShape(canvas, size, crown);
    final ball = Paint()
      ..style = PaintingStyle.fill
      ..color = accentColor;
    canvas.drawCircle(Offset(w * 0.35, h * 0.15), size.shortestSide * 0.035, ball);
    canvas.drawCircle(Offset(w * 0.5, h * 0.05), size.shortestSide * 0.04, ball);
    canvas.drawCircle(Offset(w * 0.65, h * 0.15), size.shortestSide * 0.035, ball);
  }

  @override
  bool shouldRepaint(covariant TierEmblemPainter old) =>
      old.tier != tier ||
      old.baseColor != baseColor ||
      old.accentColor != accentColor;
}

class OrbitParticles extends StatefulWidget {
  final Color color;
  final double radius;
  final int count;
  final double progress;
  const OrbitParticles({
    super.key,
    required this.color,
    required this.radius,
    required this.count,
    required this.progress,
  });

  @override
  State<OrbitParticles> createState() => _OrbitParticlesState();
}

class _OrbitParticlesState extends State<OrbitParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbit;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _orbit,
      builder: (_, __) {
        return CustomPaint(
          painter: OrbitPainter(
            color: widget.color,
            radius: widget.radius,
            count: widget.count,
            phase: _orbit.value,
          ),
        );
      },
    );
  }
}

class OrbitPainter extends CustomPainter {
  final Color color;
  final double radius;
  final int count;
  final double phase;
  OrbitPainter({
    required this.color,
    required this.radius,
    required this.count,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.7);
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + phase * 2 * math.pi;
      final p = Offset(
        c.dx + radius * math.cos(angle),
        c.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(p, 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbitPainter old) =>
      old.phase != phase || old.color != color || old.count != count;
}

// ============================================================
// _SeasonHeroBanner — banda hero con theme rotativo
// ============================================================

const Map<String, List<Color>> _themeGradients = {
  'ascenso': [Color(0xFFFF6B35), Color(0xFFFF2E63)],
  'forja': [Color(0xFFE2B23B), Color(0xFFB87333)],
  'eclipse': [Color(0xFF6A1B9A), Color(0xFF1A1A2E)],
  'vanguardia': [Color(0xFF00BFFF), Color(0xFF1A237E)],
  'cumbre': [Color(0xFFE0F7FA), Color(0xFF4FC3D8)],
};

class _SeasonHeroBanner extends StatelessWidget {
  final RankedSeason season;
  const _SeasonHeroBanner({required this.season});

  List<Color> _colors() {
    final raw = (season.themeLabel ?? '').trim().toLowerCase();
    return _themeGradients[raw] ??
        const [Color(0xFFFF6B35), Color(0xFFFF2E63)];
  }

  int _daysLeft() {
    final diff = season.endDate.difference(DateTime.now()).inDays;
    return diff.clamp(0, 9999);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    final daysLeft = _daysLeft();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'TEMPORADA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  (season.themeLabel ?? 'ASCENSO').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsFill.hourglassHigh,
                  size: 15, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                '${daysLeft}d',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _PillarBars — barras ponderadas por peso de pilar
// ============================================================

class _PillarBars extends StatelessWidget {
  final int strength;
  final int consistency;
  final int community;
  final int challenge;
  const _PillarBars({
    required this.strength,
    required this.consistency,
    required this.community,
    required this.challenge,
  });

  @override
  Widget build(BuildContext context) {
    final pillars = <_PillarData>[
      _PillarData(
        key: 'strength',
        label: 'Strength',
        weight: 40,
        score: strength,
        color: AppColors.accentOrange,
        icon: PhosphorIconsFill.barbell,
      ),
      _PillarData(
        key: 'consistency',
        label: 'Consistency',
        weight: 35,
        score: consistency,
        color: const Color(0xFFFF8C42),
        icon: PhosphorIconsFill.flame,
      ),
      _PillarData(
        key: 'community',
        label: 'Community',
        weight: 15,
        score: community,
        color: const Color(0xFF6A8DFF),
        icon: PhosphorIconsFill.usersThree,
      ),
      _PillarData(
        key: 'challenge',
        label: 'Challenge',
        weight: 10,
        score: challenge,
        color: const Color(0xFFE2B23B),
        icon: PhosphorIconsFill.target,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < pillars.length; i++) ...[
          _PillarBar(
            data: pillars[i],
            onTap: () => _showTipsSheet(context, pillars[i]),
          ),
          if (i != pillars.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  void _showTipsSheet(BuildContext context, _PillarData p) {
    final tips = _tipsFor(p.key);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(p.icon, color: p.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cómo subo ${p.label}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...tips.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(PhosphorIconsFill.checkCircle,
                              color: p.color, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              t,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  List<String> _tipsFor(String key) {
    switch (key) {
      case 'strength':
        return const [
          'Registra pesos en ejercicios marcados RANKED',
          'Apunta a +2.5kg en sentadilla / peso muerto / press',
          'Mantén consistencia 8+ semanas para que entre tu mejor e1RM por movement_pattern',
        ];
      case 'consistency':
        return const [
          'Completa al menos 3 entrenamientos por semana',
          'Loguea comida y agua diariamente',
          'Mantén racha activa — cap 80 RP/día',
        ];
      case 'community':
        return const [
          'Publica tu rutina pública — +50 RP cuando alguien la copia',
          '+10 RP por cada workout completado vía tu rutina',
          '+200 RP si inspiras un tier-up',
        ];
      case 'challenge':
        return const [
          'Completa misiones semanales',
          'Únete a retos especiales por temporada',
          'Misiones difíciles otorgan más RP que las fáciles',
        ];
      default:
        return const [];
    }
  }
}

class _PillarData {
  final String key;
  final String label;
  final int weight;
  final int score;
  final Color color;
  final IconData icon;
  const _PillarData({
    required this.key,
    required this.label,
    required this.weight,
    required this.score,
    required this.color,
    required this.icon,
  });
}

class _PillarBar extends StatelessWidget {
  final _PillarData data;
  final VoidCallback onTap;
  const _PillarBar({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F36),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(data.icon, color: data.color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${data.label} · ${data.weight}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '${data.score} pts',
                        style: TextStyle(
                          color: data.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 4,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: data.weight / 100,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: data.color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
