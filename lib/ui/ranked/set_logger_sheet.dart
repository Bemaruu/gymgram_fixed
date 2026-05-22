import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/movement_pattern_mapper.dart';
import '../../models/ranked_profile_model.dart';
import '../../services/badge_service.dart';
import '../../services/ranked_service.dart';

/// BottomSheet para registrar peso y reps por set, alimentando set_logs.
/// El trigger AFTER INSERT en SQL calcula e1RM y actualiza PRs + recalcula rank.
class SetLoggerSheet extends StatefulWidget {
  final String exerciseName;
  final String? muscleGroup;
  final String? exerciseId;
  final String? movementPattern;
  final int targetSets;
  final String? targetReps;
  final String workoutLogId;
  final bool isRankable;

  const SetLoggerSheet({
    super.key,
    required this.exerciseName,
    this.muscleGroup,
    this.exerciseId,
    this.movementPattern,
    required this.targetSets,
    this.targetReps,
    required this.workoutLogId,
    this.isRankable = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String exerciseName,
    String? muscleGroup,
    String? exerciseId,
    String? movementPattern,
    required int targetSets,
    String? targetReps,
    required String workoutLogId,
    bool? isRankable,
  }) {
    final ranked = isRankable ?? (movementPattern != null);
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SetLoggerSheet(
        exerciseName: exerciseName,
        muscleGroup: muscleGroup,
        exerciseId: exerciseId,
        movementPattern: movementPattern,
        targetSets: targetSets,
        targetReps: targetReps,
        workoutLogId: workoutLogId,
        isRankable: ranked,
      ),
    );
  }

  @override
  State<SetLoggerSheet> createState() => _SetLoggerSheetState();
}

class _SetLoggerSheetState extends State<SetLoggerSheet> {
  final _client = Supabase.instance.client;
  final _weightCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  final _weightFocus = FocusNode();

  List<Map<String, dynamic>> _sets = [];
  bool _loading = true;
  bool _saving = false;
  bool _addedAny = false;
  RankedTier? _userTier;

  @override
  void initState() {
    super.initState();
    _loadSets();
    if (widget.isRankable) {
      _loadUserTier();
    }
  }

  Future<void> _loadUserTier() async {
    try {
      final profile = await RankedService.instance.getMyProfile();
      if (!mounted) return;
      setState(() => _userTier = profile?.tier);
    } catch (_) {}
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _weightFocus.dispose();
    super.dispose();
  }

  String? get _uid => _client.auth.currentUser?.id;

  Future<void> _loadSets() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final rows = await _client
          .from('set_logs')
          .select('id, weight_kg, reps, set_index, logged_at')
          .eq('user_id', uid)
          .eq('workout_log_id', widget.workoutLogId)
          .eq('exercise_name', widget.exerciseName)
          .order('set_index');
      final list = List<Map<String, dynamic>>.from(rows);

      // Prepoblar peso con el ultimo set de ESTE workout. Si no hay, buscar el
      // ultimo set registrado del mismo ejercicio en cualquier workout previo.
      double? lastWeight;
      if (list.isNotEmpty) {
        lastWeight = (list.last['weight_kg'] as num?)?.toDouble();
      } else {
        try {
          final prev = await _client
              .from('set_logs')
              .select('weight_kg')
              .eq('user_id', uid)
              .eq('exercise_name', widget.exerciseName)
              .order('logged_at', ascending: false)
              .limit(1)
              .maybeSingle();
          lastWeight = (prev?['weight_kg'] as num?)?.toDouble();
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _sets = list;
        _loading = false;
        if (lastWeight != null && _weightCtrl.text.isEmpty) {
          _weightCtrl.text = _fmtWeight(lastWeight);
        }
      });
    } catch (e) {
      debugPrint('SetLoggerSheet load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return w.toStringAsFixed(0);
    return w.toStringAsFixed(1);
  }

  double _computeEpley(double weight, int reps) {
    return weight * (1 + reps / 30.0);
  }

  Future<double?> _fetchPreviousBestE1rm(String uid, String pattern) async {
    try {
      final row = await _client
          .from('user_strength_records')
          .select('best_e1rm')
          .eq('user_id', uid)
          .eq('movement_pattern', pattern)
          .maybeSingle();
      final v = (row?['best_e1rm'] as num?)?.toDouble();
      return v;
    } catch (e) {
      debugPrint('SetLoggerSheet fetchPreviousBestE1rm error: $e');
      return null;
    }
  }

  Future<void> _saveSet() async {
    final uid = _uid;
    if (uid == null) return;

    final weightTxt = _weightCtrl.text.trim().replaceAll(',', '.');
    final repsTxt = _repsCtrl.text.trim();
    final weight = double.tryParse(weightTxt);
    final reps = int.tryParse(repsTxt);

    if (weight == null || weight <= 0 || weight > 500) {
      _toast('Peso invalido (0.1 - 500 kg)');
      return;
    }
    if (reps == null || reps < 1 || reps > 50) {
      _toast('Reps invalidas (1 - 50)');
      return;
    }

    setState(() => _saving = true);
    try {
      final nextIndex = _sets.length + 1;
      // Si viene del catalogo rankeable, usamos su movement_pattern canonico;
      // si no, caemos al mapper heuristico por grupo + nombre.
      final pattern = widget.movementPattern ??
          mapMuscleGroupToMovementPattern(
            widget.muscleGroup,
            widget.exerciseName,
          );

      // Pre-fetch best e1rm previo SOLO si es rankable, para detectar PR
      // confiable client-side. Si falla, no mostramos overlay (falso negativo OK).
      double? previousBest;
      if (widget.isRankable) {
        previousBest = await _fetchPreviousBestE1rm(uid, pattern);
      }

      final inserted = await _client.from('set_logs').insert({
        'user_id': uid,
        'workout_log_id': widget.workoutLogId,
        if (widget.exerciseId != null) 'exercise_id': widget.exerciseId,
        'exercise_name': widget.exerciseName,
        'movement_pattern': pattern,
        'weight_kg': weight,
        'reps': reps,
        'set_index': nextIndex,
      }).select('id, weight_kg, reps, set_index, logged_at').single();

      HapticFeedback.lightImpact();
      final e1rm = _computeEpley(weight, reps);

      // PR detection client-side: solo si rankable y mejora 5% sobre previo
      // o no habia registro previo (primer set en ese movement_pattern).
      bool isPr = false;
      if (widget.isRankable) {
        if (previousBest == null || previousBest <= 0) {
          isPr = true;
        } else if (e1rm >= previousBest * 1.05) {
          isPr = true;
        }
      }

      // Revisa medallas de fuerza (Rompe Limites, Mas Fuerte). Fire-and-forget.
      BadgeService.instance.checkAndAwardBadges(uid, 'set_logged');

      if (!mounted) return;
      setState(() {
        _sets = [..._sets, inserted];
        _repsCtrl.clear();
        _addedAny = true;
        _saving = false;
      });
      _weightFocus.requestFocus();

      if (isPr) {
        // Estimacion conservadora de RP segun mejora vs previo.
        int rpEstimate;
        if (previousBest == null || previousBest <= 0) {
          rpEstimate = 25;
        } else {
          final delta = (e1rm - previousBest) / previousBest;
          rpEstimate = (delta * 200).clamp(15, 80).round();
        }
        _showPrOverlay(
          weight: weight,
          reps: reps,
          e1rm: e1rm,
          rpEstimate: rpEstimate,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurfaceElevated,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(milliseconds: 1800),
          content: Row(
            children: [
              const Icon(PhosphorIconsFill.checkCircle,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set guardado · +e1RM ${_fmtWeight(e1rm)}kg',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('SetLoggerSheet save error: $e');
      if (mounted) {
        setState(() => _saving = false);
        _toast('No se pudo guardar: $e');
      }
    }
  }

  Future<void> _deleteSet(Map<String, dynamic> s) async {
    final id = s['id'] as String?;
    if (id == null) return;
    try {
      await _client.from('set_logs').delete().eq('id', id);
      if (!mounted) return;
      setState(() => _sets = _sets.where((x) => x['id'] != id).toList());
    } catch (e) {
      debugPrint('SetLoggerSheet delete error: $e');
      _toast('No se pudo borrar');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.settingsDanger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isRankable)
              Container(height: 2, color: const Color(0xFFFF6B35)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SafeArea(
                top: false,
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
              const SizedBox(height: 14),
              _buildRankedChip(),
              const SizedBox(height: 8),
              Text(
                widget.exerciseName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.targetSets} sets · ${widget.targetReps ?? '-'} reps sugeridos',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _buildSetsList(),
              const SizedBox(height: 14),
              _buildNewSetCard(),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_addedAny),
                child: const Text(
                  'Listo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankedChip() {
    final ranked = widget.isRankable;
    final bg = ranked
        ? const Color(0xFFFF6B35).withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.08);
    final border = ranked
        ? Border.all(color: const Color(0xFFFF6B35), width: 1)
        : Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: border,
        ),
        child: ranked
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'RANKED',
                    style: TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B35),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Suma al rango competitivo',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Text(
                'No suma a Ranked',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.50),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  void _showPrOverlay({
    required double weight,
    required int reps,
    required double e1rm,
    required int rpEstimate,
  }) {
    final tierColor = _tierColorOfPr(_userTier);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.mediumImpact();
    });
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _PROverlay(
          weight: weight,
          reps: reps,
          e1rm: e1rm,
          rpEstimate: rpEstimate,
          tierColor: tierColor,
        ),
      ),
    );
  }

  static Color _tierColorOfPr(RankedTier? t) {
    switch (t) {
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
      case RankedTier.hierro:
      case null:
        return const Color(0xFFFF6B35);
    }
  }

  Widget _buildSetsList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (_sets.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: const Row(
          children: [
            Icon(PhosphorIconsRegular.lightning,
                color: AppColors.primary, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aún no registras sets. Cada set suma al Strength Score.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _sets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final s = _sets[i];
          final w = (s['weight_kg'] as num?)?.toDouble() ?? 0;
          final r = (s['reps'] as num?)?.toInt() ?? 0;
          final idx = (s['set_index'] as num?)?.toInt() ?? (i + 1);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$idx',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set $idx: ${_fmtWeight(w)} kg × $r',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(PhosphorIconsRegular.trash,
                      color: Colors.white54, size: 18),
                  onPressed: () => _deleteSet(s),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewSetCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Registrar nuevo set',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numField(
                  controller: _weightCtrl,
                  focusNode: _weightFocus,
                  label: 'Peso (kg)',
                  allowDecimal: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _numField(
                  controller: _repsCtrl,
                  label: 'Reps',
                  allowDecimal: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _saveSet,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Guardar set',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required bool allowDecimal,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: allowDecimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: AppColors.accentOrange,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        floatingLabelStyle: const TextStyle(
          color: AppColors.accentOrange,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.accentOrange, width: 1.5),
        ),
      ),
    );
  }
}

// ============================================================
// _PROverlay — overlay epico cuando el usuario rompe un PR
// ============================================================

class _PROverlay extends StatefulWidget {
  final double weight;
  final int reps;
  final double e1rm;
  final int rpEstimate;
  final Color tierColor;

  const _PROverlay({
    required this.weight,
    required this.reps,
    required this.e1rm,
    required this.rpEstimate,
    required this.tierColor,
  });

  @override
  State<_PROverlay> createState() => _PROverlayState();
}

class _PROverlayState extends State<_PROverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _confetti;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _exiting = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).pop();
      });
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _confetti.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _exiting ? 0.0 : 1.0,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (_, __) => CustomPaint(
                painter: _ConfettiPainter(
                  progress: _confetti.value,
                  tierColor: widget.tierColor,
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _enter,
              builder: (_, __) {
                final t = _enter.value;
                // Stagger:
                // - "NUEVO PR" fade in 0..0.2
                // - weight x reps slide + fade 0.1..0.5
                // - e1RM fade 0.25..0.6
                // - +RP scale elasticOut 0.4..1.0
                double clip(double from, double to) {
                  final v = ((t - from) / (to - from)).clamp(0.0, 1.0);
                  return v;
                }

                final headerOp = clip(0.0, 0.2);
                final weightOp = clip(0.1, 0.5);
                final weightDy = (1 - weightOp) * 30;
                final e1rmOp = clip(0.25, 0.6);
                final rpRaw = clip(0.4, 1.0);
                final rpScale = Curves.elasticOut.transform(rpRaw);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: headerOp,
                      child: const Text(
                        'NUEVO PR',
                        style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Transform.translate(
                      offset: Offset(0, weightDy),
                      child: Opacity(
                        opacity: weightOp,
                        child: Text(
                          '${_fmt(widget.weight)}kg × ${widget.reps}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: e1rmOp,
                      child: Text(
                        'e1RM: ${_fmt(widget.e1rm)}kg',
                        style: TextStyle(
                          color: widget.tierColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Transform.scale(
                      scale: rpScale.clamp(0.0, 1.4),
                      child: Text(
                        '+${widget.rpEstimate} RP',
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _ConfettiPainter — 40 particulas con gravedad y rotacion (CustomPainter)
// ============================================================

class _ConfettiParticle {
  final Color color;
  final double startX; // 0..1
  final double startY; // 0..1
  final double vx; // px/s
  final double vy; // px/s (negativo = sube)
  final double rotationSpeed; // rad/s
  final double initialRotation;
  final double sizeMultiplier;

  _ConfettiParticle({
    required this.color,
    required this.startX,
    required this.startY,
    required this.vx,
    required this.vy,
    required this.rotationSpeed,
    required this.initialRotation,
    required this.sizeMultiplier,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress; // 0..1 sobre 1500ms
  final Color tierColor;
  static final List<_ConfettiParticle> _particles = _buildParticles();

  _ConfettiPainter({required this.progress, required this.tierColor});

  static List<_ConfettiParticle> _buildParticles() {
    final rnd = math.Random(42);
    final palette = [
      const Color(0xFFFF6B35),
      const Color(0xFFFFD700),
      Colors.white,
    ];
    return List.generate(40, (i) {
      return _ConfettiParticle(
        color: palette[i % palette.length],
        startX: rnd.nextDouble(),
        startY: 0.4 + rnd.nextDouble() * 0.2,
        vx: (rnd.nextDouble() - 0.5) * 400,
        vy: -(200 + rnd.nextDouble() * 400),
        rotationSpeed: (rnd.nextDouble() - 0.5) * 12,
        initialRotation: rnd.nextDouble() * math.pi * 2,
        sizeMultiplier: 0.8 + rnd.nextDouble() * 0.6,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 1.5; // segundos
    const gravity = 600.0; // px/s^2 aprox (con factor 0.4 scaled)
    final fadeOut = (1 - progress).clamp(0.0, 1.0);

    for (final p in _particles) {
      final color = p.color == Colors.white && tierColor != const Color(0xFFFF6B35)
          ? tierColor
          : p.color;
      final x = p.startX * size.width + p.vx * t;
      final y = p.startY * size.height + p.vy * t + 0.5 * gravity * t * t;
      if (y > size.height + 20) continue;

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.85 * fadeOut);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.initialRotation + p.rotationSpeed * t);
      final w = 5.0 * p.sizeMultiplier;
      final h = 8.0 * p.sizeMultiplier;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) =>
      old.progress != progress || old.tierColor != tierColor;
}
