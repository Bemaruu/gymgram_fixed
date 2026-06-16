import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../widgets/medal_share_card.dart';

/// Interruptor global de la bienvenida de beta.
/// MIENTRAS la app esté en beta cerrada: true.
/// Al abrir la app al público general: cambiar a false (o pasar
/// --dart-define=BETA_WELCOME=false) y la bienvenida dejará de mostrarse.
const bool kBetaWelcomeEnabled =
    bool.fromEnvironment('BETA_WELCOME', defaultValue: true);

/// Pantalla de bienvenida para los usuarios de la beta cerrada.
/// 3 páginas: bienvenida → resumen de funcionalidades → medalla Pionero
/// (con número real y opción de compartir como imagen en redes).
///
/// Se muestra una sola vez. Al terminar simplemente hace pop y deja al
/// usuario en la pantalla principal que ya está montada debajo.
class BetaWelcomeScreen extends StatefulWidget {
  const BetaWelcomeScreen({super.key});

  @override
  State<BetaWelcomeScreen> createState() => _BetaWelcomeScreenState();
}

class _BetaWelcomeScreenState extends State<BetaWelcomeScreen> {
  final _pageController = PageController();
  final _cardKey = GlobalKey();
  int _page = 0;
  int? _pionero;
  bool _sharing = false;

  static const _gold = Color(0xFFFFC53D);

  @override
  void initState() {
    super.initState();
    _loadPionero();
  }

  Future<void> _loadPionero() async {
    final n = await SupabaseService.instance.getPioneroNumber();
    if (mounted && n != null) setState(() => _pionero = n);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    HapticFeedback.lightImpact();
    Navigator.of(context).maybePop();
  }

  Future<void> _shareMedal() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.selectionClick();

    final num = _pionero != null ? ' (Pionero #$_pionero)' : '';
    final err = await shareMedalImage(
      boundaryKey: _cardKey,
      text: 'Soy Pionero de GymGram 💪$num · gymgram.fit',
      fileName: 'pionero_gymgram.png',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      body: Stack(
        children: [
          // Fondo con halo superior dorado/celeste
          const _BackdropGlow(),

          SafeArea(
            child: Column(
              children: [
                // Skip
                Align(
                  alignment: Alignment.topRight,
                  child: AnimatedOpacity(
                    opacity: _page < 2 ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      onPressed: _page < 2 ? _finish : null,
                      child: const Text(
                        'Saltar',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      const _WelcomePage(),
                      const _FeaturesPage(),
                      _MedalPage(
                        cardKey: _cardKey,
                        pionero: _pionero,
                        gold: _gold,
                      ),
                    ],
                  ),
                ),

                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? _gold : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // CTAs
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: Column(
                    children: [
                      if (_page == 2) ...[
                        _ShareButton(
                          loading: _sharing,
                          onPressed: _shareMedal,
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _next,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            _page == 2 ? 'Empezar a entrenar' : 'Continuar',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
        ],
      ),
    );
  }
}

// ── Página 1: Bienvenida ──────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/logo.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: -0.15, curve: Curves.easeOutCubic),
          const SizedBox(height: 32),
          const Text(
            '¡Bienvenido a\nGymGram!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ).animate(delay: 150.ms).fadeIn(duration: 500.ms),
          const SizedBox(height: 18),
          const Text(
            'Eres de los primeros en construir esto con nosotros. '
            'Tu feedback define el futuro de la app. 💪',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.55,
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 500.ms),
        ],
      ),
    );
  }
}

// ── Página 2: Resumen de funcionalidades ──────────────────────────────────────

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  static const _features = [
    (
      icon: Icons.fitness_center,
      color: AppColors.sky400,
      title: 'Rutinas con IA',
      sub: 'Planes que se adaptan a ti y progresan cada semana.',
    ),
    (
      icon: Icons.restaurant_menu,
      color: AppColors.success,
      title: 'Nutrición inteligente',
      sub: 'Tu plan de comidas + escáner de alimentos con foto.',
    ),
    (
      icon: Icons.groups_2,
      color: AppColors.ember400,
      title: 'Comunidad fitness',
      sub: 'Comparte tu progreso, sigue a otros y motívate.',
    ),
    (
      icon: Icons.emoji_events,
      color: AppColors.gold,
      title: 'Ranked y medallas',
      sub: 'Compite, sube de rango y colecciona logros.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Todo lo que puedes\nhacer aquí',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ).animate().fadeIn(duration: 450.ms),
          const SizedBox(height: 28),
          ...List.generate(_features.length, (i) {
            final f = _features[i];
            return _FeatureRow(
              icon: f.icon,
              color: f.color,
              title: f.title,
              sub: f.sub,
            )
                .animate(delay: (120 * i).ms)
                .fadeIn(duration: 450.ms)
                .slideX(begin: 0.12, curve: Curves.easeOutCubic);
          }),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
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

// ── Página 3: Medalla Pionero ─────────────────────────────────────────────────

class _MedalPage extends StatelessWidget {
  final GlobalKey cardKey;
  final int? pionero;
  final Color gold;

  const _MedalPage({
    required this.cardKey,
    required this.pionero,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Tienes una medalla\nexclusiva',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ).animate().fadeIn(duration: 450.ms),
          const SizedBox(height: 22),

          // Tarjeta compartible (lo que se ve = lo que se comparte)
          RepaintBoundary(
            key: cardKey,
            child: _PioneroCard(pionero: pionero, gold: gold),
          )
              .animate()
              .fadeIn(delay: 150.ms, duration: 500.ms)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),

          const SizedBox(height: 18),
          const Text(
            'Esta medalla no se podrá obtener nunca más.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de la medalla Pionero, diseñada para verse bien al compartirse.
class _PioneroCard extends StatelessWidget {
  final int? pionero;
  final Color gold;

  const _PioneroCard({required this.pionero, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12203A), Color(0xFF0A1424)],
        ),
        border: Border.all(color: gold.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.18),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Marca
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'GymGram',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Medalla con halo
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.35),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Image.asset(
              'assets/medals/beta_exclusiva.png',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.workspace_premium,
                size: 120,
                color: gold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Chip exclusiva
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gold.withValues(alpha: 0.5)),
            ),
            child: Text(
              '👑 EXCLUSIVA DE LA BETA',
              style: TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Nombre
          const Text(
            'Pionero',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Número de pionero
          if (pionero != null)
            Text(
              'Pionero #${pionero.toString().padLeft(3, '0')}',
              style: TextStyle(
                color: gold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            )
          else
            const SizedBox(height: 19),
          const SizedBox(height: 8),

          const Text(
            'Otorgada a quienes se unieron durante\nla beta cerrada de GymGram.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 12),
          const Text(
            'gymgram.fit',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auxiliares ────────────────────────────────────────────────────────────────

class _ShareButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _ShareButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            : const Icon(Icons.ios_share, size: 18, color: Colors.white),
        label: Text(
          loading ? 'Generando…' : 'Compartir mi medalla',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.7),
            radius: 1.1,
            colors: [
              const Color(0xFFFFC53D).withValues(alpha: 0.10),
              const Color(0xFF060B14).withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
