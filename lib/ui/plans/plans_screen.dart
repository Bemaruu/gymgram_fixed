import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/purchase_service.dart';
import '../../services/subscription_service.dart';
import 'manage_subscription_screen.dart';

enum PlanId { free, plus, premium }

enum BillingCycle { monthly, yearly }

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlansScreen()),
    );
  }

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  BillingCycle _cycle = BillingCycle.monthly;
  SubscriptionTier _currentTier = SubscriptionTier.free;
  bool _loadingTier = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadTier();
  }

  Future<void> _loadTier() async {
    final t = await SubscriptionService.instance.currentTier();
    if (!mounted) return;
    setState(() {
      _currentTier = t;
      _loadingTier = false;
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurfaceElevated,
      ),
    );
  }

  Future<void> _onPlanSelected(PlanId id) async {
    HapticFeedback.lightImpact();
    if (id == PlanId.free) {
      Navigator.of(context).maybePop();
      return;
    }

    final tier = id == PlanId.premium ? 'premium' : 'plus';
    final period = _cycle == BillingCycle.yearly ? 'annual' : 'monthly';

    setState(() => _busy = true);
    final outcome = await PurchaseService.instance.purchase(
      tier: tier,
      period: period,
    );
    if (!mounted) return;

    switch (outcome.status) {
      case PurchaseStatus.success:
        // El webhook ya esta actualizando el tier en Supabase; refrescamos.
        await SubscriptionService.instance.currentStatus(forceRefresh: true);
        if (!mounted) return;
        await _loadTier();
        if (!mounted) return;
        setState(() => _busy = false);
        _snack('¡Listo! Tu plan ${tier == 'premium' ? 'Premium' : 'Plus'} esta activo.');
        break;
      case PurchaseStatus.cancelled:
        setState(() => _busy = false);
        break;
      case PurchaseStatus.error:
        setState(() => _busy = false);
        _snack(outcome.message ?? 'No se pudo completar la compra.');
        break;
    }
  }

  Future<void> _onRestore() async {
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final outcome = await PurchaseService.instance.restore();
    if (!mounted) return;
    if (outcome.status == PurchaseStatus.success) {
      await SubscriptionService.instance.currentStatus(forceRefresh: true);
      if (!mounted) return;
      await _loadTier();
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Compras restauradas.');
    } else {
      setState(() => _busy = false);
      _snack(outcome.message ?? 'No se pudieron restaurar las compras.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        title: const Text('Elige tu plan', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          _loadingTier
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BillingToggle(
                    value: _cycle,
                    onChanged: (c) => setState(() => _cycle = c),
                  ),
                  const SizedBox(height: 20),
                  _PlanCard(
                    id: PlanId.free,
                    cycle: _cycle,
                    isCurrent: _currentTier == SubscriptionTier.free,
                    onTap: () => _onPlanSelected(PlanId.free),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    id: PlanId.plus,
                    cycle: _cycle,
                    isCurrent: _currentTier == SubscriptionTier.plus,
                    onTap: () => _onPlanSelected(PlanId.plus),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    id: PlanId.premium,
                    cycle: _cycle,
                    isCurrent: _currentTier == SubscriptionTier.premium,
                    onTap: () => _onPlanSelected(PlanId.premium),
                  ),
                  const SizedBox(height: 18),
                  if (_currentTier != SubscriptionTier.free) ...[
                    _ManageSubscriptionButton(
                      onTap: () async {
                        await ManageSubscriptionScreen.open(context);
                        if (!mounted) return;
                        _loadTier();
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  const Text(
                    'Precios de lanzamiento - Cancela cuando quieras',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _onRestore,
                      child: const Text(
                        'Restaurar compras',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BillingToggle extends StatelessWidget {
  final BillingCycle value;
  final ValueChanged<BillingCycle> onChanged;
  const _BillingToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _opt(BillingCycle.monthly, 'Mensual')),
          Expanded(child: _opt(BillingCycle.yearly, 'Anual  -20%')),
        ],
      ),
    );
  }

  Widget _opt(BillingCycle c, String label) {
    final selected = c == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanId id;
  final BillingCycle cycle;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.id,
    required this.cycle,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final spec = _PlanSpec.of(id);
    final price = spec.priceFor(cycle);
    final priceNote = spec.priceNoteFor(cycle);
    final border = spec.borderColor;
    final badge = spec.badge;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.darkSurfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: border ?? AppColors.darkBorder,
              width: border != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    spec.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Tu plan',
                        style: TextStyle(
                          color: AppColors.deepBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                spec.tagline,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      cycle == BillingCycle.monthly ? '/mes' : '/año',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (priceNote != null) ...[
                const SizedBox(height: 4),
                Text(
                  priceNote,
                  style: const TextStyle(
                    color: AppColors.accentOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...spec.features.map((f) => _FeatureRow(text: f)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isCurrent ? null : onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: spec.ctaColor,
                    foregroundColor: spec.ctaTextColor,
                    disabledBackgroundColor: AppColors.darkSurfaceElevated,
                    disabledForegroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isCurrent ? 'Tu plan actual' : spec.ctaLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Positioned(
            top: -10,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badge.color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(PhosphorIconsBold.check, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageSubscriptionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ManageSubscriptionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Gestionar suscripcion',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _PlanBadge {
  final String text;
  final Color color;
  const _PlanBadge(this.text, this.color);
}

class _PlanSpec {
  final String name;
  final String tagline;
  final int? monthlyClp;
  final int? launchClp;
  final int? yearlyClp;
  final String ctaLabel;
  final Color ctaColor;
  final Color ctaTextColor;
  final Color? borderColor;
  final _PlanBadge? badge;
  final List<String> features;

  const _PlanSpec({
    required this.name,
    required this.tagline,
    required this.monthlyClp,
    required this.launchClp,
    required this.yearlyClp,
    required this.ctaLabel,
    required this.ctaColor,
    required this.ctaTextColor,
    required this.features,
    this.borderColor,
    this.badge,
  });

  factory _PlanSpec.of(PlanId id) {
    switch (id) {
      case PlanId.free:
        return const _PlanSpec(
          name: 'Free',
          tagline: 'Empieza sin pagar nada.',
          monthlyClp: 0,
          launchClp: null,
          yearlyClp: 0,
          ctaLabel: 'Continuar gratis',
          ctaColor: AppColors.darkSurfaceElevated,
          ctaTextColor: Colors.white,
          features: [
            'Rutinas IA basicas (no conversacion)',
            'Plan nutricional simple',
            '4 cambios/año de objetivo o lugar',
            '5 rutinas y 5 recetas publicas',
            'Desafios y medallas estandar',
          ],
        );
      case PlanId.plus:
        return const _PlanSpec(
          name: 'Plus',
          tagline: 'Para quienes ya entrenan en serio.',
          monthlyClp: 4990,
          launchClp: 2490,
          yearlyClp: 47900,
          ctaLabel: 'Elegir Plus',
          ctaColor: AppColors.accentOrange,
          ctaTextColor: Colors.white,
          borderColor: AppColors.accentOrange,
          badge: _PlanBadge('Popular', AppColors.accentOrange),
          features: [
            'Todo lo de Free',
            'Check-in semanal del entrenador IA',
            'Reporte mensual basico',
            'Rutinas y recetas publicas ilimitadas',
            '8 cambios/año de objetivo o lugar',
            'Modo competitivo y desafios Plus',
          ],
        );
      case PlanId.premium:
        return const _PlanSpec(
          name: 'Premium',
          tagline: 'Tu entrenador personal IA, 24/7.',
          monthlyClp: 8990,
          launchClp: 4990,
          yearlyClp: 86900,
          ctaLabel: 'Elegir Premium',
          ctaColor: Color(0xFFFFE08A),
          ctaTextColor: AppColors.deepBlue,
          borderColor: Color(0xFFFFE08A),
          badge: _PlanBadge('Mejor valor', Color(0xFFC44510)),
          features: [
            'Todo lo de Plus',
            'Entrenador IA con nombre y tono personalizado',
            'Chat libre con tu coach (10 msg/dia)',
            'Feedback post-entreno por IA',
            'Reporte mensual completo (GPT-4o)',
            '12 cambios/año de objetivo o lugar',
            'Desafios y medallas Premium',
          ],
        );
    }
  }

  String _fmtClp(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '\$$buf';
  }

  String priceFor(BillingCycle c) {
    if (monthlyClp == 0) return '\$0';
    if (c == BillingCycle.yearly && yearlyClp != null) return _fmtClp(yearlyClp!);
    if (launchClp != null) return _fmtClp(launchClp!);
    return _fmtClp(monthlyClp!);
  }

  String? priceNoteFor(BillingCycle c) {
    if (monthlyClp == 0) return null;
    if (c == BillingCycle.yearly) {
      if (monthlyClp != null) return 'Equivale a ${_fmtClp((yearlyClp! / 12).round())}/mes';
      return null;
    }
    if (launchClp != null && launchClp! < monthlyClp!) {
      return 'Lanzamiento - antes ${_fmtClp(monthlyClp!)}';
    }
    return null;
  }
}
