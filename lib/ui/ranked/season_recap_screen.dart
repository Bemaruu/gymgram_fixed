import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../models/ranked_profile_model.dart';
import '../../models/season_recap_model.dart';
import '../../services/ranked_service.dart';

/// Recap fin de temporada. Layout vertical 9:16 estilo wrapped.
class SeasonRecapScreen extends StatefulWidget {
  final String seasonId;
  const SeasonRecapScreen({super.key, required this.seasonId});

  @override
  State<SeasonRecapScreen> createState() => _SeasonRecapScreenState();
}

class _SeasonRecapScreenState extends State<SeasonRecapScreen> {
  bool _loading = true;
  SeasonRecap? _recap;
  String? _username;

  // Para futuro export a imagen.
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final recap = await RankedService.instance.getMySeasonRecap(widget.seasonId);
    String? username;
    final uid = RankedService.instance.currentUserId;
    if (uid != null) {
      try {
        final row = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', uid)
            .maybeSingle();
        username = row?['username'] as String?;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _recap = recap;
      _username = username;
      _loading = false;
    });
  }

  Future<void> _onShare() async {
    final r = _recap;
    if (r == null) return;
    final text = _buildShareText(r);

    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('No se pudo capturar la pantalla');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('No se pudo codificar la imagen');
      }
      final bytes = byteData.buffer.asUint8List();

      final tmpDir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tmpDir.path}/gymgram_recap_$ts.png');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkSurfaceElevated,
          content: Text(
            'No se pudo compartir: $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  String _buildShareText(SeasonRecap r) {
    final tier = _tierLabel(r.tier);
    final div = r.division != null ? ' ${_roman(r.division!)}' : '';
    return 'Mi temporada en GymGram: $tier$div · ${r.finalRp} RP. '
        '¿Cuál es el tuyo? #GymGram';
  }

  @override
  Widget build(BuildContext context) {
    final r = _recap;
    final tier = r?.tier ?? RankedTier.hierro;
    final color = _tierColor(tier);
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : r == null
                ? const Center(
                    child: Text(
                      'No hay datos de temporada todavía',
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                : Stack(
                    children: [
                      // Lienzo de captura: oculto detrás de la historia pero
                      // pintado, para poder exportarlo como PNG al compartir.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RepaintBoundary(
                              key: _captureKey,
                              child: _recapCanvas(r, tier, color),
                            ),
                          ),
                        ),
                      ),
                      // Historia por slides (estilo Wrapped) sobre el lienzo.
                      Positioned.fill(
                        child: _WrappedStory(
                          recap: r,
                          color: color,
                          tierLabel: _tierLabel(tier),
                          tierIcon: _iconForTier(tier),
                          percentile: r.percentile,
                          username: _username,
                          archetype: _identityArchetype(r),
                          archetypeDescription: _archetypeDescription(
                              r, _identityArchetype(r)),
                          onShare: _onShare,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 4,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(PhosphorIconsBold.x,
                              color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  /// Lienzo fijo 1080x1920 (9:16) que se exporta a PNG y se escala con FittedBox.
  Widget _recapCanvas(SeasonRecap r, RankedTier tier, Color color) {
    return Container(
      width: 1080,
      height: 1920,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.darkSurface,
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.18),
            AppColors.darkSurface,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(72, 96, 72, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              r.seasonName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
                fontSize: 28,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'TU TEMPORADA EN GYMGRAM',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: 7,
              ),
            ),
            const SizedBox(height: 56),
            _buildEmblem(tier, 360, color),
            const SizedBox(height: 36),
            Text(
              _tierLabel(tier).toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 84,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Top ${((1 - r.percentile) * 100).toStringAsFixed(0)}% mundial',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 34,
              ),
            ),
            const SizedBox(height: 64),
            _statsGrid(r, color),
            const Spacer(),
            _identityCard(r, color),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhosphorIconsFill.barbell,
                  color: AppColors.primary,
                  size: 34,
                ),
                const SizedBox(width: 12),
                const Text(
                  'GymGram',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
                ),
                if (_username != null) ...[
                  const SizedBox(width: 14),
                  Text(
                    '· @$_username',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 28,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsGrid(SeasonRecap r, Color color) {
    final items = [
      _RecapStat(r.daysTrainedTotal, '', 'días entrenados',
          PhosphorIconsFill.calendarCheck),
      _RecapStat(r.prsAchieved, '', 'PRs rotos', PhosphorIconsFill.trophy),
      _RecapStat(r.totalVolumeKg.round(), ' kg', 'movidos en total',
          PhosphorIconsFill.barbell),
      _RecapStat(r.longestStreak, '', 'racha máxima', PhosphorIconsFill.flame),
    ];
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 28,
          mainAxisSpacing: 28,
          childAspectRatio: 1.7,
          children: [
            for (int i = 0; i < items.length; i++)
              _statCard(items[i], color, delayMs: i * 180),
          ],
        ),
        const SizedBox(height: 28),
        _inspiredCard(r.usersInspired, color),
      ],
    );
  }

  Widget _statCard(_RecapStat it, Color color, {required int delayMs}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(it.icon, color: color, size: 40),
          const SizedBox(height: 8),
          _AnimatedCounter(
            value: it.value,
            suffix: it.suffix,
            delayMs: delayMs,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 72,
            ),
          ),
          Text(
            it.label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inspiredCard(int inspired, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accentOrange.withValues(alpha: 0.30),
            color.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.55), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Icon(PhosphorIconsFill.usersThree,
                  color: AppColors.accentOrange, size: 44),
              const SizedBox(width: 14),
              _AnimatedCounter(
                value: inspired,
                suffix: '',
                delayMs: 720,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 72,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'personas inspiradas con tus rutinas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(SeasonRecap r, Color color) {
    final fromServer = r.identityArchetype;
    final identity =
        (fromServer != null && fromServer.trim().isNotEmpty)
            ? fromServer
            : _archetypeFor(r);
    return _IdentityClimaxCard(
      archetype: identity,
      description: _archetypeDescription(r, identity),
      color: color,
    );
  }

  /// Calcula un arquetipo de identidad cliente cuando el servidor no lo provee.
  /// Función pura: depende solo de los campos de [r].
  static String _archetypeFor(SeasonRecap r) {
    final days = r.daysTrainedTotal;
    final prs = r.prsAchieved;
    final vol = r.totalVolumeKg;
    final streak = r.longestStreak;
    final inspired = r.usersInspired;
    final tier = r.tier;
    final percentile = r.percentile;

    // Inmortal en pocos parametros = forjado
    if (tier == RankedTier.inmortal && days <= 45) {
      return 'El Inmortal Forjado';
    }

    // Cohete: percentil top con racha modesta indica subida rapida
    if (percentile >= 0.95 && streak < 14 && days < 50) {
      return 'El Cohete';
    }

    // Novato imparable: hierro/bronce no aplica si llego aqui, pero conservamos
    // por si recap se invoca sobre season pasada con tier final mas alto.
    if ((tier == RankedTier.oro || tier == RankedTier.platino) &&
        days >= 40 &&
        prs >= 8) {
      return 'El Novato Imparable';
    }

    // Sabio: muchos PRs + alta inspiracion = completo y maestro
    if (prs >= 12 && inspired >= 5) {
      return 'El Sabio';
    }

    // Resurgido: percentile decente y racha alta indican vuelta
    if (percentile >= 0.7 && streak >= 21 && prs <= 4) {
      return 'El Resurgido';
    }

    // Reina del Volumen
    if (vol >= 60000) {
      return 'La Reina del Volumen';
    }

    // Tanque Pesado: volumen por dia muy alto
    if (days > 0 && (vol / days) >= 1800) {
      return 'El Tanque Pesado';
    }

    // Maratonista del Gym: muchos dias pero PRs/volumen medios
    if (days >= 55 && prs < 8 && vol < 50000) {
      return 'El Maratonista del Gym';
    }

    // Calistenico Silencioso: PRs decentes y volumen relativamente bajo
    if (prs >= 6 && vol < 25000) {
      return 'El Calisténico Silencioso';
    }

    // Cazador de PRs
    if (prs >= 10) {
      return 'El Cazador de PRs';
    }

    // Disciplinado de Hierro
    if (streak >= 21 && days >= 40) {
      return 'El Disciplinado de Hierro';
    }

    // Inspirador
    if (inspired >= 6) {
      return 'El Inspirador';
    }

    // Constructora: inspira y entrena consistente
    if (inspired >= 3 && days >= 30) {
      return 'La Constructora';
    }

    // Lobo Solitario: nada de community pero solido en lo demas
    if (inspired == 0 && (days >= 30 || prs >= 5)) {
      return 'El Lobo Solitario';
    }

    // Bestia bajo la barra: muchos PRs concentrados
    if (prs >= 7 && streak < 14) {
      return 'La Bestia bajo la Barra';
    }

    // Equilibrista: metricas balanceadas (heuristica simple)
    if (days >= 20 && prs >= 3 && inspired >= 2 && streak >= 7) {
      return 'El Equilibrista';
    }

    if (days >= 20) return 'El Constante';
    if (prs >= 3) return 'El Forjador';
    return 'El Iniciado';
  }

  /// Frase descriptiva breve para el arquetipo. Si no hay match especifico
  /// devuelve una frase generica basada en el tier.
  static String _archetypeDescription(SeasonRecap r, String archetype) {
    const map = {
      'El Inmortal Forjado': 'Fuerza pura en tiempo récord.',
      'El Cohete': 'Subiste como pocos esta temporada.',
      'El Novato Imparable': 'Llegaste lejos y sin frenos.',
      'El Sabio': 'Dominas el hierro y guías a los demás.',
      'El Resurgido': 'Volviste con más hambre que nunca.',
      'La Reina del Volumen': 'Moviste toneladas sin parpadear.',
      'El Tanque Pesado': 'Cada sesión, una declaración de poder.',
      'El Maratonista del Gym': 'Tu constancia no conoce descanso.',
      'El Calisténico Silencioso': 'Progreso puro, sin ruido.',
      'El Cazador de PRs': 'Rompiste tus límites una y otra vez.',
      'El Disciplinado de Hierro': 'La rutina es tu superpoder.',
      'El Inspirador': 'Tus rutinas mueven a la comunidad.',
      'La Constructora': 'Construyes fuerza y comunidad a la vez.',
      'El Lobo Solitario': 'Forjado en silencio, sin testigos.',
      'La Bestia bajo la Barra': 'La barra tiembla cuando apareces.',
      'El Equilibrista': 'Dominas todos los pilares por igual.',
      'El Constante': 'Apareciste cuando importaba.',
      'El Forjador': 'Cada PR es un paso más en tu forja.',
      'El Iniciado': 'Apenas el comienzo de tu leyenda.',
    };
    return map[archetype] ?? 'Tu temporada, tu legado.';
  }

  /// Arquetipo final: usa el del servidor si existe, si no lo calcula localmente.
  static String _identityArchetype(SeasonRecap r) {
    final fromServer = r.identityArchetype;
    return (fromServer != null && fromServer.trim().isNotEmpty)
        ? fromServer
        : _archetypeFor(r);
  }

  Widget _buildEmblem(RankedTier tier, double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.45),
            color.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Icon(_iconForTier(tier), color: color, size: size * 0.55),
      ),
    );
  }

  static IconData _iconForTier(RankedTier t) {
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

  static String _roman(int d) {
    switch (d) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      default:
        return '';
    }
  }
}

class _RecapStat {
  final int value;
  final String suffix;
  final String label;
  final IconData icon;
  _RecapStat(this.value, this.suffix, this.label, this.icon);
}

/// Tarjeta climax del recap: fondo gradiente cónico animado + arquetipo.
class _IdentityClimaxCard extends StatefulWidget {
  final String archetype;
  final String description;
  final Color color;
  const _IdentityClimaxCard({
    required this.archetype,
    required this.description,
    required this.color,
  });

  @override
  State<_IdentityClimaxCard> createState() => _IdentityClimaxCardState();
}

class _IdentityClimaxCardState extends State<_IdentityClimaxCard>
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
    final color = widget.color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AnimatedBuilder(
        animation: _spin,
        builder: (_, child) {
          return CustomPaint(
            painter: _ConicGradientPainter(
              color: color,
              phase: _spin.value,
            ),
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              const Text(
                'TU ARQUETIPO',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.archetype,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 64,
                  fontStyle: FontStyle.italic,
                  shadows: [
                    Shadow(color: color, blurRadius: 32),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConicGradientPainter extends CustomPainter {
  final Color color;
  final double phase;
  _ConicGradientPainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = Paint()..color = AppColors.darkSurface;
    canvas.drawRect(rect, base);
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 6.283185307179586,
        transform: GradientRotation(phase * 6.283185307179586),
        colors: [
          color.withValues(alpha: 0.55),
          color.withValues(alpha: 0.12),
          color.withValues(alpha: 0.55),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, sweep);
  }

  @override
  bool shouldRepaint(covariant _ConicGradientPainter old) =>
      old.phase != phase || old.color != color;
}

/// Contador que anima de 0 a [value] con un retardo inicial opcional.
class _AnimatedCounter extends StatelessWidget {
  final int value;
  final String suffix;
  final int delayMs;
  final TextStyle style;
  const _AnimatedCounter({
    required this.value,
    required this.suffix,
    required this.delayMs,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: Duration(milliseconds: 1200 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('$v$suffix', style: style),
    );
  }
}

/// Experiencia "Wrapped" por slides: tarjetas a pantalla completa que el usuario
/// avanza tocando (derecha = siguiente, izquierda = atrás). Cada slide revela un
/// dato con animación; la última ofrece compartir (captura el lienzo PNG detrás).
class _WrappedStory extends StatefulWidget {
  final SeasonRecap recap;
  final Color color;
  final String tierLabel;
  final IconData tierIcon;
  final double percentile;
  final String? username;
  final String archetype;
  final String archetypeDescription;
  final VoidCallback onShare;

  const _WrappedStory({
    required this.recap,
    required this.color,
    required this.tierLabel,
    required this.tierIcon,
    required this.percentile,
    required this.username,
    required this.archetype,
    required this.archetypeDescription,
    required this.onShare,
  });

  @override
  State<_WrappedStory> createState() => _WrappedStoryState();
}

class _WrappedStoryState extends State<_WrappedStory> {
  static const int _count = 8;
  int _i = 0;

  void _next() {
    if (_i < _count - 1) setState(() => _i++);
  }

  void _prev() {
    if (_i > 0) setState(() => _i--);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) {
        final w = MediaQuery.of(context).size.width;
        if (d.localPosition.dx > w * 0.30) {
          _next();
        } else {
          _prev();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkSurface,
              color.withValues(alpha: 0.45),
              color.withValues(alpha: 0.12),
              AppColors.darkSurface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barra segmentada estilo stories.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                child: Row(
                  children: [
                    for (int s = 0; s < _count; s++)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: s <= _i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(_i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Center(child: _slide(_i)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: Center(
                  child: _i < _count - 1
                      ? Text(
                          'Toca para continuar  →',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slide(int i) {
    final r = widget.recap;
    switch (i) {
      case 0:
        return _introSlide();
      case 1:
        return _statSlide(PhosphorIconsFill.calendarCheck, r.daysTrainedTotal,
            '', 'días entrenados', 'Apareciste. Una y otra vez.');
      case 2:
        return _statSlide(PhosphorIconsFill.barbell, r.totalVolumeKg.round(),
            ' kg', 'movidos en total', 'Toneladas de esfuerzo acumulado.');
      case 3:
        return _statSlide(PhosphorIconsFill.trophy, r.prsAchieved, '',
            'PRs rotos', 'Cada uno, un límite superado.');
      case 4:
        return _statSlide(PhosphorIconsFill.flame, r.longestStreak, '',
            'días de racha máxima', 'La constancia es tu superpoder.');
      case 5:
        return _communitySlide(r.usersInspired);
      case 6:
        return _tierSlide();
      default:
        return _archetypeSlide();
    }
  }

  Widget _introSlide() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.recap.seasonName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tu temporada\nen GymGram',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 44,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 28),
        Icon(PhosphorIconsFill.barbell, color: widget.color, size: 56),
        const SizedBox(height: 28),
        const Text(
          'Un resumen de tu esfuerzo, slide a slide.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60, fontSize: 16),
        ),
      ],
    );
  }

  Widget _statSlide(
      IconData icon, int value, String suffix, String label, String phrase) {
    final color = widget.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 64),
        const SizedBox(height: 24),
        _AnimatedCounter(
          value: value,
          suffix: suffix,
          delayMs: 0,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 88,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          phrase,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _communitySlide(int inspired) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(PhosphorIconsFill.usersThree,
            color: AppColors.accentOrange, size: 64),
        const SizedBox(height: 24),
        _AnimatedCounter(
          value: inspired,
          suffix: '',
          delayMs: 0,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 88,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'personas inspiradas\ncon tus rutinas',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tu entrenamiento mueve a la comunidad.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.accentOrange,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _tierSlide() {
    final color = widget.color;
    final topPct = ((1 - widget.percentile) * 100).toStringAsFixed(0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'TERMINASTE EN',
          style: TextStyle(
            color: Colors.white60,
            letterSpacing: 5,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.45),
                color.withValues(alpha: 0.12),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: 36,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(child: Icon(widget.tierIcon, color: color, size: 92)),
        ),
        const SizedBox(height: 28),
        Text(
          widget.tierLabel.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 52,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Top $topPct% mundial',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
      ],
    );
  }

  Widget _archetypeSlide() {
    final color = widget.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'TU ARQUETIPO',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.archetype,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 40,
            fontStyle: FontStyle.italic,
            shadows: [Shadow(color: color, blurRadius: 28)],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.archetypeDescription,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 36),
        ElevatedButton.icon(
          onPressed: widget.onShare,
          icon: const Icon(PhosphorIconsFill.shareNetwork, size: 18),
          label: const Text('Compartir mi temporada'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        if (widget.username != null) ...[
          const SizedBox(height: 16),
          Text(
            '@${widget.username}',
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ],
    );
  }
}
