import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/badge_model.dart';
import '../../services/badge_service.dart';
import '../../services/medal_proof_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/medal_widget.dart';
import '../../widgets/medal_share_card.dart';

/// Bottom sheet con el detalle completo de una medalla.
/// [userBadge] es null si el usuario aún no la ha ganado.
/// [isOwner] habilita el botón de destacar/quitar.
/// [onFeaturedChanged] se llama cuando cambia el estado destacado.
void showMedalDetail({
  required BuildContext context,
  required BadgeModel badge,
  UserBadgeModel? userBadge,
  bool isOwner = false,
  VoidCallback? onFeaturedChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MedalDetailSheet(
      badge: badge,
      userBadge: userBadge,
      isOwner: isOwner,
      onFeaturedChanged: onFeaturedChanged,
    ),
  );
}

class _MedalDetailSheet extends StatefulWidget {
  final BadgeModel badge;
  final UserBadgeModel? userBadge;
  final bool isOwner;
  final VoidCallback? onFeaturedChanged;

  const _MedalDetailSheet({
    required this.badge,
    this.userBadge,
    this.isOwner = false,
    this.onFeaturedChanged,
  });

  @override
  State<_MedalDetailSheet> createState() => _MedalDetailSheetState();
}

class _MedalDetailSheetState extends State<_MedalDetailSheet> {
  bool _featuredLoading = false;
  bool _proofLoading = false;
  bool _sharing = false;
  late bool _isFeatured;
  bool _earnedViaProof = false;
  int? _pionero;
  final _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _isFeatured = widget.userBadge?.isFeatured ?? false;
    if (widget.badge.id == 'beta_exclusiva' && _isEarned) _loadPionero();
  }

  Future<void> _loadPionero() async {
    final n = await SupabaseService.instance.getPioneroNumber();
    if (mounted && n != null) setState(() => _pionero = n);
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final isBeta = widget.badge.id == 'beta_exclusiva';
    final num = isBeta && _pionero != null ? ' (Pionero #$_pionero)' : '';
    final err = await shareMedalImage(
      boundaryKey: _shareCardKey,
      text: isBeta
          ? 'Soy Pionero de GymGram 💪$num · gymgram.fit'
          : 'Desbloqueé "${widget.badge.medalName}" en GymGram 💪 · gymgram.fit',
    );
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo compartir: $err'),
          backgroundColor: const Color(0xFF3A1A1A),
        ),
      );
    }
    if (mounted) setState(() => _sharing = false);
  }

  bool get _isEarned =>
      _earnedViaProof ||
      (widget.userBadge != null && widget.userBadge!.progress >= 1.0);

  String _formatDate(DateTime dt) {
    const months = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${dt.day} de ${months[dt.month - 1]}, ${dt.year}';
  }

  Future<void> _toggleFeatured() async {
    if (_featuredLoading) return;
    setState(() => _featuredLoading = true);

    try {
      final service = BadgeService.instance;
      final currentFeatured = await service.getMyFeaturedBadgeIds();

      if (_isFeatured) {
        // Quitar de destacadas
        final updated = currentFeatured.where((id) => id != widget.badge.id).toList();
        await service.setFeaturedBadges(updated);
        if (mounted) setState(() => _isFeatured = false);
      } else {
        if (currentFeatured.length >= 4) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ya tienes 4 medallas destacadas. Quita una primero.'),
                backgroundColor: Color(0xFF1A1A2E),
              ),
            );
          }
          return;
        }
        final updated = [...currentFeatured, widget.badge.id];
        await service.setFeaturedBadges(updated);
        if (mounted) setState(() => _isFeatured = true);
      }
      widget.onFeaturedChanged?.call();
    } catch (e) {
      debugPrint('toggleFeatured error: $e');
    } finally {
      if (mounted) setState(() => _featuredLoading = false);
    }
  }

  Future<void> _submitProof() async {
    if (_proofLoading) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
              title: const Text('Tomar foto', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
              title: const Text('Elegir de galería', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? picked =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() => _proofLoading = true);
    try {
      final result = await MedalProofService.instance
          .submitProof(widget.badge.id, File(picked.path));
      if (!mounted) return;

      if (result.approved) {
        setState(() => _earnedViaProof = true);
        widget.onFeaturedChanged?.call();
        _showResult(true, result.reason.isEmpty
            ? '¡Medalla desbloqueada!'
            : result.reason);
      } else {
        _showResult(false, result.reason.isEmpty
            ? 'La foto no cumple el reto. Intenta otra.'
            : result.reason);
      }
    } catch (e) {
      if (mounted) {
        _showResult(false, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _proofLoading = false);
    }
  }

  void _showResult(bool ok, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? const Color(0xFF1B5E20) : const Color(0xFF3A1A1A),
        content: Row(
          children: [
            Icon(ok ? Icons.verified : Icons.error_outline,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rankColor = widget.badge.rank.color;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Stack(
        children: [
          // Tarjeta compartible: se pinta detras del panel opaco (queda oculta
          // al usuario pero con un layer valido para capturar con toImage).
          // No usar left:-2000: el Stack la recortaria y no se pintaria.
          Positioned(
            left: 0,
            top: 0,
            child: RepaintBoundary(
              key: _shareCardKey,
              child: MedalShareCard(
                badge: widget.badge,
                pioneroNumber: _pionero,
              ),
            ),
          ),
          Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0E1221),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Imagen de medalla grande
            Center(
              child: MedalWidget(
                badge: widget.badge,
                isEarned: _isEarned,
                size: 110,
              ),
            ),
            const SizedBox(height: 20),

            // Nombre de la medalla
            Center(
              child: Text(
                widget.badge.medalName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Rank chip + título del desafío
            Center(child: RankChip(rank: widget.badge.rank)),
            const SizedBox(height: 6),
            Center(
              child: Text(
                widget.badge.title,
                style: TextStyle(
                  color: rankColor.withValues(alpha: 0.85),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 20),
            _Divider(),

            // Descripción
            const SizedBox(height: 16),
            Text(
              widget.badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.55,
              ),
            ),

            const SizedBox(height: 20),

            // Condición
            _InfoRow(
              icon: Icons.flag_outlined,
              iconColor: rankColor,
              label: 'Cómo obtenerla',
              value: widget.badge.condition,
            ),

            // Dificultad (solo si aplica)
            if (widget.badge.difficulty > 0) ...[
              const SizedBox(height: 14),
              _DifficultyRow(
                difficulty: widget.badge.difficulty,
                rankColor: rankColor,
              ),
            ],

            // Fecha de obtención
            if (_isEarned) ...[
              const SizedBox(height: 14),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                iconColor: rankColor,
                label: 'Obtenida el',
                value: _formatDate(widget.userBadge!.earnedAt.toLocal()),
              ),
            ],

            // Barra de progreso (si tiene progreso pero no está ganada)
            if (!_isEarned && widget.userBadge != null) ...[
              const SizedBox(height: 16),
              _ProgressBar(
                progress: widget.userBadge!.progress,
                rankColor: rankColor,
              ),
            ],

            // Etiqueta de evento o especial
            if (widget.badge.isGlobalEvent || widget.badge.rank == BadgeRank.especial) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.badge.rank == BadgeRank.especial
                        ? const Color(0xFF4A0080).withValues(alpha: 0.4)
                        : const Color(0xFFBF360C).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.badge.rank == BadgeRank.especial
                          ? const Color(0xFFAA00FF).withValues(alpha: 0.5)
                          : const Color(0xFFFF6D00).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    widget.badge.rank == BadgeRank.especial
                        ? '✦ Medalla única e irrepetible'
                        : '⚡ Medalla de evento limitado',
                    style: TextStyle(
                      color: widget.badge.rank == BadgeRank.especial
                          ? const Color(0xFFCE93D8)
                          : const Color(0xFFFFAB40),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // Botón subir foto para validar (medallas con verificación por IA)
            if (widget.isOwner &&
                !_isEarned &&
                widget.badge.requiresPhotoProof) ...[
              const SizedBox(height: 28),
              _ProofButton(
                isLoading: _proofLoading,
                rankColor: rankColor,
                onPressed: _submitProof,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'La IA revisa tu foto al instante.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],

            // Botón destacar (solo dueño y medalla ganada)
            if (widget.isOwner && _isEarned) ...[
              const SizedBox(height: 28),
              _FeaturedButton(
                isFeatured: _isFeatured,
                isLoading: _featuredLoading,
                rankColor: rankColor,
                onPressed: _toggleFeatured,
              ),
            ],

            // Botón compartir (dueño y medalla ganada)
            if (widget.isOwner && _isEarned) ...[
              const SizedBox(height: 12),
              _ShareMedalButton(
                isLoading: _sharing,
                rankColor: rankColor,
                onPressed: _share,
              ),
            ],

            const SizedBox(height: 8),
            Center(
              child: Text(
                'Las medallas son únicas e intransferibles.',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

class _ShareMedalButton extends StatelessWidget {
  final bool isLoading;
  final Color rankColor;
  final VoidCallback onPressed;

  const _ShareMedalButton({
    required this.isLoading,
    required this.rankColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white54),
              )
            : const Icon(Icons.ios_share, size: 18),
        label: Text(
          isLoading ? 'Generando…' : 'Compartir medalla',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white10);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final int difficulty;
  final Color rankColor;

  const _DifficultyRow({required this.difficulty, required this.rankColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bolt, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DIFICULTAD',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(10, (i) {
                final filled = i < difficulty;
                return Container(
                  width: 14,
                  height: 6,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: filled ? rankColor : rankColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color rankColor;

  const _ProgressBar({required this.progress, required this.rankColor});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PROGRESO',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(color: rankColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: rankColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(rankColor),
          ),
        ),
      ],
    );
  }
}

class _ProofButton extends StatelessWidget {
  final bool isLoading;
  final Color rankColor;
  final VoidCallback onPressed;

  const _ProofButton({
    required this.isLoading,
    required this.rankColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: isLoading
          ? Column(
              children: const [
                CircularProgressIndicator(color: Colors.white54),
                SizedBox(height: 10),
                Text(
                  'Verificando con IA…',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text(
                'Subir foto para validar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: rankColor.withValues(alpha: 0.25),
                foregroundColor: rankColor,
                side: BorderSide(color: rankColor.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
    );
  }
}

class _FeaturedButton extends StatelessWidget {
  final bool isFeatured;
  final bool isLoading;
  final Color rankColor;
  final VoidCallback onPressed;

  const _FeaturedButton({
    required this.isFeatured,
    required this.isLoading,
    required this.rankColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white54))
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(
                isFeatured ? Icons.star : Icons.star_border,
                size: 18,
              ),
              label: Text(
                isFeatured ? 'Quitar de destacadas' : 'Destacar en mi perfil',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFeatured
                    ? Colors.white12
                    : rankColor.withValues(alpha: 0.25),
                foregroundColor: isFeatured ? Colors.white54 : rankColor,
                side: BorderSide(
                  color: isFeatured ? Colors.white24 : rankColor.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
    );
  }
}
