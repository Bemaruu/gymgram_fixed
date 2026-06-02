import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../models/match_model.dart';

/// Pantalla de resultado del duelo 1v1.
class MatchResultScreen extends StatelessWidget {
  final MatchState state;
  final String mySlot; // 'a' | 'b'
  final VoidCallback? onRematch;

  const MatchResultScreen({
    super.key,
    required this.state,
    required this.mySlot,
    this.onRematch,
  });

  bool get _iWon => state.match.winnerId != null &&
      ((mySlot == 'a' && state.match.winnerId == state.match.playerA) ||
          (mySlot == 'b' && state.match.winnerId == state.match.playerB));

  int get _myWins => mySlot == 'a' ? state.match.winsA : state.match.winsB;
  int get _rivalWins => mySlot == 'a' ? state.match.winsB : state.match.winsA;
  int get _myDelta =>
      (mySlot == 'a' ? state.match.rpDeltaA : state.match.rpDeltaB) ?? 0;

  MatchPlayer get _rival => mySlot == 'a' ? state.playerB : state.playerA;

  @override
  Widget build(BuildContext context) {
    final won = _iWon;
    final abandoned = state.match.status == MatchStatus.abandoned;

    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _buildHero(won, abandoned),
              const SizedBox(height: 20),
              _buildRpCard(won),
              const SizedBox(height: 28),
              _sectionTitle('Resumen del duelo'),
              const SizedBox(height: 12),
              ...state.rounds
                  .where((r) => r.bothSubmitted)
                  .map((r) => _recapRow(r)),
              const SizedBox(height: 28),
              _buildActions(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(bool won, bool abandoned) {
    return Column(
      children: [
        if (won)
          const Icon(PhosphorIconsFill.crown, size: 60, color: AppColors.gold)
              .animate()
              .scale(
                duration: 600.ms,
                curve: Curves.elasticOut,
                begin: const Offset(0.3, 0.3),
                end: const Offset(1, 1),
              )
        else
          Icon(PhosphorIconsFill.shield,
              size: 60, color: Colors.white.withValues(alpha: 0.30)),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: won
                ? [Colors.white, AppColors.gold]
                : [Colors.white, Colors.white.withValues(alpha: 0.5)],
          ).createShader(rect),
          child: Text(
            won ? 'VICTORIA' : 'DERROTA',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.4,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: 6),
        Text(
          abandoned
              ? (won ? '@${_rival.username} abandonó el duelo' : 'Abandonaste el duelo')
              : 'Marcador final',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$_myWins',
              style: TextStyle(
                color: won ? AppColors.primary : Colors.white70,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('-',
                  style: TextStyle(color: Colors.white38, fontSize: 26)),
            ),
            Text(
              '$_rivalWins',
              style: TextStyle(
                color: !won ? AppColors.accentOrange : Colors.white70,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRpCard(bool won) {
    final delta = _myDelta;
    final positive = delta >= 0;
    final color = positive ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: delta.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => Text(
              '${value >= 0 ? '+' : ''}${value.round()} RP',
              style: TextStyle(
                color: color,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            won ? '¡Buen trabajo! Sigue subiendo.' : 'La revancha está ahí. Vuelve más fuerte.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _recapRow(MatchRound r) {
    final myScore = mySlot == 'a' ? r.scoreA : r.scoreB;
    final rivalScore = mySlot == 'a' ? r.scoreB : r.scoreA;
    final myWeight = mySlot == 'a' ? r.weightA : r.weightB;
    final myReps = mySlot == 'a' ? r.repsA : r.repsB;
    final rivalWeight = mySlot == 'a' ? r.weightB : r.weightA;
    final rivalReps = mySlot == 'a' ? r.repsB : r.repsA;
    final iWonRound = r.roundWinner == mySlot;
    final tie = r.roundWinner == 'tie';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'R${r.roundNumber}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.exerciseNameFor(r),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${_fmt(myWeight)}×${myReps ?? '-'} (${myScore?.toStringAsFixed(0) ?? '-'})',
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 11),
                    ),
                    const Text('  vs  ',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text(
                      '${_fmt(rivalWeight)}×${rivalReps ?? '-'} (${rivalScore?.toStringAsFixed(0) ?? '-'})',
                      style: const TextStyle(
                          color: AppColors.accentOrange, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            tie
                ? PhosphorIconsRegular.equals
                : (iWonRound
                    ? PhosphorIconsFill.checkCircle
                    : PhosphorIconsFill.xCircle),
            color: tie
                ? Colors.white38
                : (iWonRound ? AppColors.success : AppColors.danger),
            size: 20,
          ),
        ],
      ),
    );
  }

  String _fmt(double? v) {
    if (v == null) return '-';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        if (onRematch != null)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onRematch!();
              },
              icon: const Icon(PhosphorIconsFill.sword, size: 18),
              label: const Text('Revancha'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: AppColors.darkBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Volver a Ranked'),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.gold, AppColors.accentOrange],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            t,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      );
}
