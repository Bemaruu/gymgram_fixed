import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../models/match_model.dart';
import '../../../services/match_service.dart';
import '../../../widgets/tier_emblem_badge.dart';
import 'match_waiting_screen.dart';

/// Abre el bottom sheet para enviar un desafío 1v1.
/// [preselected] viene del perfil de un amigo; si es null se muestra la lista
/// de seguidos para elegir rival.
Future<void> showChallengeFriendSheet(
  BuildContext context, {
  MatchPlayer? preselected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChallengeFriendSheet(preselected: preselected),
  );
}

class _ChallengeFriendSheet extends StatefulWidget {
  final MatchPlayer? preselected;
  const _ChallengeFriendSheet({this.preselected});

  @override
  State<_ChallengeFriendSheet> createState() => _ChallengeFriendSheetState();
}

class _ChallengeFriendSheetState extends State<_ChallengeFriendSheet> {
  final _svc = MatchService.instance;
  bool _loading = true;
  bool _sending = false;
  List<MatchPlayer> _friends = const [];
  MatchPlayer? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.preselected;
    if (widget.preselected != null) {
      _loading = false;
    } else {
      _loadFriends();
    }
  }

  Future<void> _loadFriends() async {
    final list = await _svc.getChallengeableFriends();
    if (!mounted) return;
    setState(() {
      _friends = list;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final target = _selected;
    if (target == null || _sending) return;
    setState(() => _sending = true);
    try {
      final challengeId = await _svc.sendChallenge(target.userId);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MatchWaitingScreen(
          challengeId: challengeId,
          rival: target,
        ),
      ));
    } on MatchException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurfaceElevated,
          behavior: SnackBarBehavior.floating,
          content: Text(e.message, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _rankedChip(),
              const SizedBox(height: 12),
              const Text('Desafiar a duelo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text(
                'Al mejor de 5 ejercicios. El que gane 3 rondas, gana RP.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (_selected != null) _vsPreview(_selected!),
              if (widget.preselected == null) ...[
                const SizedBox(height: 16),
                _buildFriendList(),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selected == null || _sending) ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    disabledBackgroundColor:
                        AppColors.accentOrange.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enviar desafío',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ahora no',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rankedChip() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accentOrange.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accentOrange, width: 0.8),
        ),
        child: const Text(
          'RANKED · 1v1',
          style: TextStyle(
            color: AppColors.accentOrange,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _vsPreview(MatchPlayer rival) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _miniPlayer(null, 'Tú', AppColors.primary)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('VS',
                style: TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
          ),
          Expanded(child: _miniPlayer(rival, '@${rival.username}',
              AppColors.accentOrange)),
        ],
      ),
    );
  }

  Widget _miniPlayer(MatchPlayer? p, String label, Color color) {
    return Column(
      children: [
        if (p != null)
          TierEmblemBadge(tier: p.tier, size: 44)
        else
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.darkSurfaceElevated,
            child: Icon(Icons.person, color: Colors.white54, size: 22),
          ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildFriendList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Aún no tienes amigos para desafiar.\nUn amigo es alguien que te sigue y al que también sigues.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final f = _friends[i];
          final selected = _selected?.userId == f.userId;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _selected = f),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.accentOrange : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.darkSurfaceElevated,
                    backgroundImage:
                        f.avatarUrl != null ? NetworkImage(f.avatarUrl!) : null,
                    child: f.avatarUrl == null
                        ? const Icon(Icons.person,
                            color: Colors.white54, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    TierEmblemBadge.labelOf(f.tier),
                    style: TextStyle(
                        color: TierEmblemBadge.colorOf(f.tier),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
