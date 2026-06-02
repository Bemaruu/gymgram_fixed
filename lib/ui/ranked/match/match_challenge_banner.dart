import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../models/match_model.dart';
import '../../../services/match_service.dart';
import 'incoming_challenge_dialog.dart';

/// Banner que aparece en RankedScreen cuando hay desafíos 1v1 pendientes.
class MatchChallengeBanner extends StatefulWidget {
  const MatchChallengeBanner({super.key});

  @override
  State<MatchChallengeBanner> createState() => MatchChallengeBannerState();
}

class MatchChallengeBannerState extends State<MatchChallengeBanner> {
  List<MatchChallenge> _challenges = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final list = await MatchService.instance.getIncomingChallenges();
    if (!mounted) return;
    setState(() {
      _challenges = list;
      _loaded = true;
    });
  }

  Future<void> _open() async {
    if (_challenges.isEmpty) return;
    final changed = await showIncomingChallengeDialog(context, _challenges.first);
    if (changed) reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _challenges.isEmpty) return const SizedBox.shrink();
    final n = _challenges.length;
    final first = _challenges.first;
    final subtitle = n == 1
        ? '@${first.challenger?.username ?? 'alguien'} te retó a un duelo 1v1'
        : 'Toca para responder';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accentOrange.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.accentOrange.withValues(alpha: 0.55), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentOrange.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(PhosphorIconsFill.sword,
                  size: 22, color: AppColors.accentOrange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n == 1
                          ? 'Tienes 1 desafío pendiente'
                          : 'Tienes $n desafíos pendientes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(PhosphorIconsRegular.caretRight,
                  color: Colors.white70, size: 16),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.2, end: 0, curve: Curves.easeOutCubic),
    );
  }
}
