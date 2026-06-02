import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../models/match_model.dart';
import '../../../models/ranked_profile_model.dart';
import '../../../services/match_service.dart';
import '../../../services/notification_service.dart';
import '../../../widgets/tier_emblem_badge.dart';
import 'match_screen.dart';

/// Muestra el diálogo de un desafío entrante. Si se acepta, navega a la
/// MatchScreen. Devuelve true si el estado del desafío cambió (para refrescar).
Future<bool> showIncomingChallengeDialog(
  BuildContext context,
  MatchChallenge challenge,
) async {
  final changed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _IncomingChallengeDialog(challenge: challenge),
  );
  return changed ?? false;
}

class _IncomingChallengeDialog extends StatefulWidget {
  final MatchChallenge challenge;
  const _IncomingChallengeDialog({required this.challenge});

  @override
  State<_IncomingChallengeDialog> createState() =>
      _IncomingChallengeDialogState();
}

class _IncomingChallengeDialogState extends State<_IncomingChallengeDialog> {
  bool _busy = false;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final matchId = await MatchService.instance
          .respondToChallenge(widget.challenge.id, accept);
      if (!mounted) return;
      if (accept && matchId != null) {
        HapticFeedback.mediumImpact();
        // Notifica al retador que su desafio fue aceptado (best-effort).
        unawaited(NotificationService.instance.sendPushToUser(
          userId: widget.challenge.challengerId,
          title: 'Tu desafío fue aceptado ⚔️',
          body: 'Tu rival aceptó el duelo. ¡Que comience!',
          data: {'type': 'match_started', 'match_id': matchId},
        ));
        Navigator.of(context).pop(true);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MatchScreen(matchId: matchId),
        ));
      } else {
        Navigator.of(context).pop(true);
      }
    } on MatchException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
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
    final challenger = widget.challenge.challenger;
    final tier = challenger?.tier ?? RankedTier.hierro;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentOrange.withValues(alpha: 0.18),
              blurRadius: 22,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DESAFÍO 1v1',
              style: TextStyle(
                color: AppColors.accentOrange,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 18),
            Stack(
              alignment: Alignment.center,
              children: [
                TierEmblemBadge(tier: tier, size: 76),
                Positioned(
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.darkSurfaceElevated,
                    backgroundImage: challenger?.avatarUrl != null
                        ? NetworkImage(challenger!.avatarUrl!)
                        : null,
                    child: challenger?.avatarUrl == null
                        ? const Icon(Icons.person,
                            color: Colors.white54, size: 22)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '@${challenger?.username ?? 'alguien'}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'te reta a un duelo · ${TierEmblemBadge.labelOf(tier)}',
              style: TextStyle(
                  color: TierEmblemBadge.colorOf(tier),
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Al mejor de 5. Pones RP en juego.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : () => _respond(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Rechazar',
                        style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _respond(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Aceptar duelo',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
