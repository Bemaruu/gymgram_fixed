import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
  bool _forfeiting = false;
  // Serializa el procesamiento del stream para evitar race entre _onState
  // concurrentes (revelar dos rondas, navegar dos veces, etc).
  Future<void> _processing = Future.value();

  final _revealedRounds = <int>{};
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();

  String get _uid => _svc.currentUserId ?? '';

  String _mySlotOf(MatchState s) => _uid == s.match.playerA ? 'a' : 'b';

  @override
  void initState() {
    super.initState();
    _sub = _svc.watchMatch(widget.matchId).listen(_enqueueState);
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

  void _enqueueState(MatchState s) {
    _processing = _processing.then((_) => _onState(s)).catchError((_) {});
  }

  Future<void> _onState(MatchState s) async {
    if (!_initialized) {
      for (final r in s.rounds) {
        if (r.roundWinner != null) _revealedRounds.add(r.roundNumber);
      }
      _initialized = true;
      if (mounted) setState(() => _state = s);
      _maybeGoToResult(s);
      return;
    }

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
    if (_forfeiting) return false;
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
    if (res != true) return false;

    setState(() => _forfeiting = true);
    try {
      await _svc.forfeit(widget.matchId);
      // Forzamos la transición al result screen aunque el realtime tarde.
      // El status ya está 'abandoned' en el server.
      final fresh = await _svc.getMatchState(widget.matchId);
      if (!mounted) return true;
      if (fresh != null && fresh.match.status != MatchStatus.active) {
        _navigatedToResult = true;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => MatchResultScreen(state: fresh, mySlot: _mySlotOf(fresh)),
        ));
        return true;
      }
    } catch (_) {
      // El realtime debería resolver. Si no, dejamos al usuario en pantalla.
    } finally {
      if (mounted) setState(() => _forfeiting = false);
    }
    return true;
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
        await _confirmForfeit();
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

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxHeight < 680;
        return Column(
          children: [
            _buildHeaderVs(me, rival, compact),
            SizedBox(height: compact ? 4 : 8),
            _buildScoreboard(myWins, rivalWins, compact),
            _buildTimeoutBanner(s, isMyTurn, iSubmitted, rival),
            SizedBox(height: compact ? 4 : 8),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
                child: _buildRoundCard(s, round, isMyTurn, iSubmitted, rival, compact),
              ),
            ),
            if (isMyTurn)
              _buildInput(compact)
            else
              _buildWaiting(rival, iSubmitted, compact),
          ],
        );
      },
    );
  }

  // Banner sutil: si toca reclamar timeout muestra una chip pequeña a la derecha
  // del header (no un bloque gigante). Estados de "te queda poco" siguen siendo
  // pills compactas centradas.
  Widget _buildTimeoutBanner(
      MatchState s, bool isMyTurn, bool iSubmitted, MatchPlayer rival) {
    if (s.match.status != MatchStatus.active) return const SizedBox.shrink();
    final startedAt = s.match.turnStartedAt;
    if (startedAt == null) return const SizedBox.shrink();
    final remaining = MatchService.turnTimeoutSeconds -
        DateTime.now().difference(startedAt).inSeconds;

    final waitingForRival = !isMyTurn && !iSubmitted;

    // Caso clave: rival inactivo. Botón sutil (chip), no banner gigante.
    if (waitingForRival && remaining <= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: _claimChip(),
      );
    }
    if (waitingForRival && remaining <= 120) {
      return _miniPill(
        color: AppColors.accentOrange,
        icon: PhosphorIconsRegular.hourglass,
        text: 'El rival tiene ${_fmt(remaining)} para responder',
      );
    }
    if (isMyTurn && remaining <= 120 && remaining > 0) {
      return _miniPill(
        color: AppColors.accentOrange,
        icon: PhosphorIconsRegular.clock,
        text: 'Te quedan ${_fmt(remaining)} para registrar',
      );
    }
    if (isMyTurn && remaining <= 0) {
      return _miniPill(
        color: AppColors.danger,
        icon: PhosphorIconsFill.warning,
        text: 'Tiempo agotado, registra ya',
      );
    }
    return const SizedBox.shrink();
  }

  Widget _miniPill({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                    color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Botón sutil de reclamar victoria. Pequeño, alineado a la derecha.
  Widget _claimChip() {
    const color = AppColors.danger;
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _claimingTimeout ? null : _claimTimeout,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _claimingTimeout
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.danger),
                    )
                  : const Icon(PhosphorIconsFill.flag, color: color, size: 13),
              const SizedBox(width: 6),
              const Text(
                'Reclamar victoria',
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: chip
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 220.ms)
          .scaleXY(end: 1.04, duration: 1100.ms, curve: Curves.easeInOut),
    );
  }

  String _fmt(int secs) {
    final s = secs.clamp(0, 9999);
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
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

  Widget _buildHeaderVs(MatchPlayer me, MatchPlayer rival, bool compact) {
    final width = MediaQuery.of(context).size.width;
    final emblemSize = (width / 8).clamp(44.0, 56.0);
    final avatarR = (emblemSize * 0.30).clamp(14.0, 18.0);
    return Container(
      padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, compact ? 8 : 12),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                  child: _playerColumn(me, AppColors.primary,
                      isMe: true,
                      emblemSize: emblemSize,
                      avatarR: avatarR,
                      compact: compact)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentOrange],
                    ).createShader(rect),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 24 : 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text('Mejor de 5',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: compact ? 9 : 10)),
                ],
              ),
              Expanded(
                  child: _playerColumn(rival, AppColors.accentOrange,
                      isMe: false,
                      emblemSize: emblemSize,
                      avatarR: avatarR,
                      compact: compact)),
            ],
          ),
          Positioned(
            top: -4,
            right: -8,
            child: IconButton(
              tooltip: 'Abandonar duelo',
              icon: const Icon(PhosphorIconsRegular.signOut,
                  color: Colors.white54, size: 20),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              onPressed: _forfeiting ? null : _confirmForfeit,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerColumn(MatchPlayer p, Color glow,
      {required bool isMe,
      required double emblemSize,
      required double avatarR,
      required bool compact}) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            TierEmblemBadge(tier: p.tier, size: emblemSize),
            Positioned(
              bottom: 0,
              child: CircleAvatar(
                radius: avatarR,
                backgroundColor: AppColors.darkSurfaceElevated,
                backgroundImage:
                    p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
                child: p.avatarUrl == null
                    ? Icon(Icons.person,
                        color: Colors.white54, size: avatarR * 1.1)
                    : null,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isMe ? 'Tú' : '@${p.username}',
              style: TextStyle(
                color: glow,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            TierEmblemBadge.labelOf(p.tier),
            style: TextStyle(
              color: TierEmblemBadge.colorOf(p.tier),
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreboard(int myWins, int rivalWins, bool compact) {
    final dotSize = compact ? 11.0 : 13.0;
    Widget dots(int wins, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final filled = i < wins;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: dotSize,
              height: dotSize,
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
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          child: Text(
            '$myWins - $rivalWins',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 17 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        dots(rivalWins, AppColors.accentOrange),
      ],
    );
  }

  Widget _buildRoundCard(MatchState s, MatchRound? round, bool isMyTurn,
      bool iSubmitted, MatchPlayer rival, bool compact) {
    if (round == null) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'RONDA ${round.roundNumber} DE 5',
              style: TextStyle(
                color: AppColors.accentOrange,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          Icon(PhosphorIconsFill.barbell,
              size: compact ? 34 : 40, color: AppColors.primary),
          SizedBox(height: compact ? 8 : 12),
          // Nombre del ejercicio responsivo: hasta 2 líneas, se reduce si no cabe.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Text(
              s.exerciseNameFor(round),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          if (isMyTurn)
            _turnPill('Tu turno', PhosphorIconsFill.lightning,
                AppColors.primary,
                pulse: true, compact: compact)
          else if (iSubmitted)
            _turnPill('Esperando a @${rival.username}…',
                PhosphorIconsRegular.hourglass, Colors.white60,
                compact: compact)
          else
            _turnPill('Turno de @${rival.username}',
                PhosphorIconsRegular.hourglass, AppColors.accentOrange,
                compact: compact),
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
      {bool pulse = false, bool compact = false}) {
    final pill = Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16, vertical: compact ? 7 : 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  color: color,
                  fontSize: compact ? 12.5 : 14,
                  fontWeight: FontWeight.w800),
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

  Widget _buildInput(bool compact) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          compact ? 14 : 20, compact ? 10 : 14, compact ? 14 : 20, compact ? 14 : 20),
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
                Expanded(child: _numField(_weightCtrl, 'Peso (kg)', true, compact)),
                const SizedBox(width: 12),
                Expanded(child: _numField(_repsCtrl, 'Reps', false, compact)),
              ],
            ),
            SizedBox(height: compact ? 10 : 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(vertical: compact ? 13 : 16),
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
                    : Text('Registrar mi marca',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 14 : 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(
      TextEditingController c, String label, bool decimal, bool compact) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: decimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 16 : 18,
          fontWeight: FontWeight.w700),
      cursorColor: AppColors.accentOrange,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: AppColors.darkSurfaceElevated,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16, vertical: compact ? 13 : 16),
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

  Widget _buildWaiting(MatchPlayer rival, bool iSubmitted, bool compact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, compact ? 12 : 16, 20, compact ? 18 : 24),
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
            SizedBox(height: compact ? 8 : 10),
            Text(
              iSubmitted
                  ? 'Marca registrada. Esperando a @${rival.username}…'
                  : 'Es el turno de @${rival.username}…',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white60, fontSize: compact ? 12 : 13),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                score?.toStringAsFixed(0) ?? '-',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900),
              ),
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
