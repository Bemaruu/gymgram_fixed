import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../models/match_model.dart';
import '../../../services/match_service.dart';
import '../../../widgets/tier_emblem_badge.dart';
import 'match_result_screen.dart';

/// Pantalla del duelo 1v1 en vivo. Escucha el estado vía Realtime.
class MatchScreen extends StatefulWidget {
  final String matchId;
  const MatchScreen({super.key, required this.matchId});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final _svc = MatchService.instance;
  StreamSubscription<MatchState>? _sub;
  Timer? _ticker;
  MatchState? _state;
  bool _initialized = false;
  bool _navigatedToResult = false;
  bool _submitting = false;
  bool _claimingTimeout = false;

  final _revealedRounds = <int>{};
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();

  String get _uid => _svc.currentUserId ?? '';

  String _mySlotOf(MatchState s) => _uid == s.match.playerA ? 'a' : 'b';

  @override
  void initState() {
    super.initState();
    _sub = _svc.watchMatch(widget.matchId).listen(_onState);
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  Future<void> _onState(MatchState s) async {
    // En la primera carga, marca como ya vistas las rondas ya resueltas
    // para no re-reproducir revelados al reconectar a mitad de partida.
    if (!_initialized) {
      for (final r in s.rounds) {
        if (r.roundWinner != null) _revealedRounds.add(r.roundNumber);
      }
      _initialized = true;
      if (mounted) setState(() => _state = s);
      _maybeGoToResult(s);
      return;
    }

    // Detecta rondas recién resueltas para mostrar el revelado.
    final newlyResolved = s.rounds
        .where((r) =>
            r.roundWinner != null && !_revealedRounds.contains(r.roundNumber))
        .toList()
      ..sort((a, b) => a.roundNumber.compareTo(b.roundNumber));

    if (mounted) setState(() => _state = s);

    for (final r in newlyResolved) {
      _revealedRounds.add(r.roundNumber);
      if (mounted) await _showRoundReveal(s, r);
    }

    _maybeGoToResult(s);
  }

  void _maybeGoToResult(MatchState s) {
    if (_navigatedToResult) return;
    if (s.match.status == MatchStatus.active) return;
    _navigatedToResult = true;
    final mySlot = _mySlotOf(s);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MatchResultScreen(state: s, mySlot: mySlot),
    ));
  }

  Future<void> _submit() async {
    final s = _state;
    if (s == null || _submitting) return;
    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    final reps = int.tryParse(_repsCtrl.text);
    if (weight == null || weight <= 0 || weight > 500) {
      _toast('Ingresa un peso válido (1-500 kg).');
      return;
    }
    if (reps == null || reps < 1 || reps > 50) {
      _toast('Ingresa reps válidas (1-50).');
      return;
    }
    setState(() => _submitting = true);
    HapticFeedback.lightImpact();
    try {
      await _svc.submitRound(widget.matchId, weight, reps);
      _weightCtrl.clear();
      _repsCtrl.clear();
    } on MatchException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmForfeit() async {
    final s = _state;
    if (s == null || s.match.status != MatchStatus.active) return true;
    final res = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Abandonar el duelo?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'Perderás automáticamente y restarás RP.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir compitiendo',
                style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Abandonar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (res == true) {
      await _svc.forfeit(widget.matchId);
      return true;
    }
    return false;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.darkSurfaceElevated,
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmForfeit();
        if (ok && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.darkSurface,
        body: SafeArea(
          child: s == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _buildContent(s),
        ),
      ),
    );
  }

  Widget _buildContent(MatchState s) {
    final mySlot = _mySlotOf(s);
    final me = mySlot == 'a' ? s.playerA : s.playerB;
    final rival = mySlot == 'a' ? s.playerB : s.playerA;
    final myWins = mySlot == 'a' ? s.match.winsA : s.match.winsB;
    final rivalWins = mySlot == 'a' ? s.match.winsB : s.match.winsA;
    final round = s.currentRound;
    final iSubmitted = round == null
        ? false
        : (mySlot == 'a' ? round.submittedA : round.submittedB);
    final isMyTurn = s.match.status == MatchStatus.active &&
        s.match.currentTurn == mySlot &&
        !iSubmitted;

    return Column(
      children: [
        _buildHeaderVs(me, rival),
        const SizedBox(height: 8),
        _buildScoreboard(myWins, rivalWins),
        _buildTimeoutBanner(s, isMyTurn, iSubmitted, rival),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildRoundCard(s, round, isMyTurn, iSubmitted, rival),
          ),
        ),
        if (isMyTurn) _buildInput() else _buildWaiting(rival, iSubmitted),
      ],
    );
  }

  Widget _buildTimeoutBanner(
      MatchState s, bool isMyTurn, bool iSubmitted, MatchPlayer rival) {
    if (s.match.status != MatchStatus.active) return const SizedBox.shrink();
    final startedAt = s.match.turnStartedAt;
    if (startedAt == null) return const SizedBox.shrink();
    final remaining = MatchService.turnTimeoutSeconds -
        DateTime.now().difference(startedAt).inSeconds;

    // Rival está agotando su tiempo y aún no es mi turno: ofrecer reclamar.
    final waitingForRival = !isMyTurn && !iSubmitted;
    if (waitingForRival && remaining <= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: _bannerCard(
          color: AppColors.danger,
          icon: PhosphorIconsFill.flag,
          title: '@${rival.username} no responde',
          subtitle: 'Han pasado 7 minutos. Puedes ganar por inactividad.',
          action: 'Reclamar victoria',
          onTap: _claimingTimeout ? null : _claimTimeout,
          loading: _claimingTimeout,
        ),
      );
    }
    if (waitingForRival && remaining <= 120) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: _bannerCard(
          color: AppColors.accentOrange,
          icon: PhosphorIconsRegular.hourglass,
          title: 'El rival tiene ${_fmt(remaining)} para responder',
          subtitle: null,
        ),
      );
    }

    // Es mi turno y se acerca el límite.
    if (isMyTurn && remaining <= 120 && remaining > 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: _bannerCard(
          color: AppColors.accentOrange,
          icon: PhosphorIconsRegular.clock,
          title: 'Te quedan ${_fmt(remaining)} para registrar',
          subtitle: 'Si no envías tu marca, el rival podrá reclamar la victoria.',
        ),
      );
    }
    if (isMyTurn && remaining <= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: _bannerCard(
          color: AppColors.danger,
          icon: PhosphorIconsFill.warning,
          title: 'Tiempo agotado',
          subtitle: 'Registra tu marca ya antes de que el rival reclame.',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _fmt(int secs) {
    final s = secs.clamp(0, 9999);
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Widget _bannerCard({
    required Color color,
    required IconData icon,
    required String title,
    String? subtitle,
    String? action,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11.5)),
                ],
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(action,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _claimTimeout() async {
    if (_claimingTimeout) return;
    setState(() => _claimingTimeout = true);
    HapticFeedback.lightImpact();
    final ok = await _svc.claimTimeout(widget.matchId);
    if (!mounted) return;
    setState(() => _claimingTimeout = false);
    if (!ok) {
      _toast('Aún no se cumple el tiempo. Inténtalo en unos segundos.');
    }
  }

  Widget _buildHeaderVs(MatchPlayer me, MatchPlayer rival) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.accentOrange.withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              Expanded(child: _playerColumn(me, AppColors.primary, isMe: true)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentOrange],
                    ).createShader(rect),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Text('Mejor de 5',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
              Expanded(
                  child: _playerColumn(rival, AppColors.accentOrange,
                      isMe: false)),
            ],
          ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              tooltip: 'Abandonar duelo',
              icon: const Icon(PhosphorIconsRegular.signOut,
                  color: Colors.white54, size: 22),
              onPressed: () async {
                final ok = await _confirmForfeit();
                if (ok && mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerColumn(MatchPlayer p, Color glow, {required bool isMe}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            TierEmblemBadge(tier: p.tier, size: 54),
            Positioned(
              bottom: 0,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.darkSurfaceElevated,
                backgroundImage:
                    p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                child: p.avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 18)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isMe ? 'Tú' : '@${p.username}',
          style: TextStyle(
            color: glow,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          TierEmblemBadge.labelOf(p.tier),
          style: TextStyle(
            color: TierEmblemBadge.colorOf(p.tier),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreboard(int myWins, int rivalWins) {
    Widget dots(int wins, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final filled = i < wins;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? color : Colors.white.withValues(alpha: 0.10),
                border: Border.all(
                  color: filled ? color : Colors.white24,
                  width: 1,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.4), blurRadius: 8)
                      ]
                    : null,
              ),
            );
          }),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dots(myWins, AppColors.primary),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            '$myWins - $rivalWins',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        dots(rivalWins, AppColors.accentOrange),
      ],
    );
  }

  Widget _buildRoundCard(MatchState s, MatchRound? round, bool isMyTurn,
      bool iSubmitted, MatchPlayer rival) {
    if (round == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Text(
            'RONDA ${round.roundNumber} DE 5',
            style: const TextStyle(
              color: AppColors.accentOrange,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          const Icon(PhosphorIconsFill.barbell,
              size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            s.exerciseNameFor(round),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (isMyTurn)
            _turnPill('Tu turno', PhosphorIconsFill.lightning,
                AppColors.primary,
                pulse: true)
          else if (iSubmitted)
            _turnPill('Esperando a @${rival.username}…',
                PhosphorIconsRegular.hourglass, Colors.white60)
          else
            _turnPill('Turno de @${rival.username}',
                PhosphorIconsRegular.hourglass, AppColors.accentOrange),
        ],
      ),
    )
        .animate(key: ValueKey('round-${round.roundNumber}'))
        .fadeIn(duration: 300.ms)
        .scale(
          begin: const Offset(0.92, 0.92),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        );
  }

  Widget _turnPill(String text, IconData icon, Color color,
      {bool pulse = false}) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (!pulse) return pill;
    return pill
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.03, duration: 900.ms, curve: Curves.easeInOut);
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _numField(_weightCtrl, 'Peso (kg)', true)),
                const SizedBox(width: 12),
                Expanded(child: _numField(_repsCtrl, 'Reps', false)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Registrar mi marca',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, bool decimal) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
      cursorColor: AppColors.accentOrange,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: AppColors.darkSurfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.accentOrange, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildWaiting(MatchPlayer rival, bool iSubmitted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _WaitingDots(),
            const SizedBox(height: 10),
            Text(
              iSubmitted
                  ? 'Marca registrada. Esperando a @${rival.username}…'
                  : 'Es el turno de @${rival.username}…',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoundReveal(MatchState s, MatchRound r) async {
    final mySlot = _mySlotOf(s);
    final myScore = mySlot == 'a' ? r.scoreA : r.scoreB;
    final rivalScore = mySlot == 'a' ? r.scoreB : r.scoreA;
    final iWon = r.roundWinner == mySlot;
    final tie = r.roundWinner == 'tie';

    HapticFeedback.heavyImpact();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, __) {
        Future<void>.delayed(const Duration(milliseconds: 1900), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tie
                    ? 'EMPATE'
                    : (iWon ? '¡GANASTE LA RONDA!' : 'RONDA PARA EL RIVAL'),
                style: TextStyle(
                  color: tie
                      ? Colors.white
                      : (iWon ? AppColors.success : AppColors.accentOrange),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ).animate().fadeIn().scale(
                  begin: const Offset(0.6, 0.6),
                  curve: Curves.elasticOut,
                  duration: 600.ms),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _scoreCard('Tú', myScore, AppColors.primary,
                      winner: iWon && !tie),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('vs',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 14)),
                  ),
                  _scoreCard('Rival', rivalScore, AppColors.accentOrange,
                      winner: !iWon && !tie),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _scoreCard(String label, double? score, Color color,
      {required bool winner}) {
    return AnimatedOpacity(
      opacity: winner ? 1 : 0.6,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: winner ? color : AppColors.darkBorder,
            width: winner ? 2 : 1,
          ),
          boxShadow: winner
              ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16)]
              : null,
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              score?.toStringAsFixed(0) ?? '-',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900),
            ),
            const Text('puntos',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// Tres puntos animados para el estado de espera.
class _WaitingDots extends StatefulWidget {
  const _WaitingDots();
  @override
  State<_WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<_WaitingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_c.value * 3 - i).clamp(0.0, 1.0);
            final scale =
                0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 10 * scale,
              height: 10 * scale,
              decoration: BoxDecoration(
                color: AppColors.accentOrange
                    .withValues(alpha: 0.4 + 0.6 * scale),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
