import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/purchase_service.dart';
import '../../services/subscription_service.dart';

/// Pantalla para que un usuario Plus o Premium gestione su suscripcion:
/// subir de plan, bajar de plan, o cancelar. Las reglas:
///
/// - Upgrade Plus -> Premium: inmediato, cobra diferencia prorrateada.
///   (Mockeado: pagos reales no integrados aun.)
/// - Downgrade Premium -> Plus: se aplica al final del periodo. Cobro Plus
///   cuando vence el actual.
/// - Cancelar a Free: se aplica al final del periodo. No vuelve a cobrar.
///
/// Si ya hay un cambio agendado, se muestra un banner con opcion de revertir.
class ManageSubscriptionScreen extends StatefulWidget {
  const ManageSubscriptionScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageSubscriptionScreen()),
    );
  }

  @override
  State<ManageSubscriptionScreen> createState() =>
      _ManageSubscriptionScreenState();
}

class _ManageSubscriptionScreenState extends State<ManageSubscriptionScreen> {
  SubscriptionStatus? _status;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SubscriptionService.instance.currentStatus(
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() {
      _status = s;
      _loading = false;
    });
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

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  int _monthlyPriceFor(SubscriptionTier t, SubscriptionVariant v) {
    if (t == SubscriptionTier.plus) {
      switch (v) {
        case SubscriptionVariant.founder:
          return 1990;
        case SubscriptionVariant.launch:
          return 2490;
        case SubscriptionVariant.normal:
          return 4990;
      }
    }
    if (t == SubscriptionTier.premium) {
      switch (v) {
        case SubscriptionVariant.founder:
          return 3990;
        case SubscriptionVariant.launch:
          return 4990;
        case SubscriptionVariant.normal:
          return 8990;
      }
    }
    return 0;
  }

  String _tierLabel(SubscriptionTier t) {
    switch (t) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.plus:
        return 'Plus';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  Future<void> _confirmUpgradeToPremium() async {
    final status = _status!;
    final plusMonthly = _monthlyPriceFor(SubscriptionTier.plus, status.variant);
    final premiumMonthly =
        _monthlyPriceFor(SubscriptionTier.premium, status.variant);
    final diff = premiumMonthly - plusMonthly;

    final periodEnd = status.periodEnd;
    int prorated = diff;
    if (periodEnd != null) {
      final now = DateTime.now();
      final daysLeft = periodEnd.difference(now).inDays.clamp(0, 31);
      prorated = ((diff * daysLeft) / 30).round();
    }

    // Seleccionar periodo (mensual / anual) antes de confirmar.
    final period = await _showPeriodPicker();
    if (period == null || !mounted) return;

    final ok = await _showConfirm(
      title: 'Subir a Premium',
      icon: PhosphorIconsBold.arrowUp,
      iconColor: AppColors.accentOrange,
      bodyLines: [
        'El cambio es inmediato.',
        if (period == 'monthly') ...[
          if (periodEnd != null)
            'Te cobramos solo la diferencia prorrateada por los dias que te quedan de Plus: aprox ${_fmtClp(prorated)}.'
          else
            'Te cobramos la diferencia hasta ${_fmtClp(diff)}.',
          'Tu proxima renovacion sera al precio Premium (${_fmtClp(premiumMonthly)}/mes).',
        ] else ...[
          'Plan anual: mejor precio, un solo cobro.',
        ],
      ],
      ctaLabel: 'Pasar a Premium',
      ctaColor: AppColors.accentOrange,
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final outcome = await PurchaseService.instance.purchase(
        tier: 'premium',
        period: period,
      );
      if (!mounted) return;
      switch (outcome.status) {
        case PurchaseStatus.success:
          await SubscriptionService.instance.currentStatus(forceRefresh: true);
          await _load();
          if (mounted) _showSnack('Premium activado. Bienvenido!');
          break;
        case PurchaseStatus.cancelled:
          break;
        case PurchaseStatus.error:
          _showSnack(outcome.message ?? 'No se pudo completar la compra.');
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showPeriodPicker() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkSurfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Elegir periodo',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PeriodOption(
              label: 'Mensual',
              onTap: () => Navigator.of(ctx).pop('monthly'),
            ),
            const SizedBox(height: 8),
            _PeriodOption(
              label: 'Anual  (-20%)',
              onTap: () => Navigator.of(ctx).pop('annual'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDowngradeToPlus() async {
    final status = _status!;
    final plusMonthly = _monthlyPriceFor(SubscriptionTier.plus, status.variant);
    final periodEnd = status.periodEnd;

    final ok = await _showConfirm(
      title: 'Bajar a Plus',
      icon: PhosphorIconsBold.arrowDown,
      iconColor: AppColors.settingsWarning,
      bodyLines: [
        'Mantendras Premium hasta el ${_fmtDate(periodEnd)}.',
        'Despues bajaras a Plus automaticamente y se te cobrara ${_fmtClp(plusMonthly)}/mes.',
        'Puedes revertir este cambio antes de esa fecha.',
      ],
      ctaLabel: 'Agendar bajada a Plus',
      ctaColor: AppColors.settingsWarning,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await SubscriptionService.instance.scheduleDowngradeToPlus();
      await _load();
      if (mounted) {
        _showSnack(
          'Bajada a Plus agendada para el ${_fmtDate(periodEnd)}.',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('No se pudo agendar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancellation() async {
    final status = _status!;
    final periodEnd = status.periodEnd;

    final ok = await _showConfirm(
      title: 'Cancelar suscripcion',
      icon: PhosphorIconsBold.x,
      iconColor: AppColors.settingsDanger,
      bodyLines: [
        'Mantendras ${_tierLabel(status.tier)} hasta el ${_fmtDate(periodEnd)}.',
        'Despues pasaras a Free y no se te volvera a cobrar.',
        'Puedes revertir este cambio antes de esa fecha.',
      ],
      ctaLabel: 'Cancelar suscripcion',
      ctaColor: AppColors.settingsDanger,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await SubscriptionService.instance.scheduleCancellation();
      await _load();
      if (mounted) {
        _showSnack(
          'Cancelacion agendada para el ${_fmtDate(periodEnd)}.',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('No se pudo cancelar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRevert() async {
    final ok = await _showConfirm(
      title: 'Revertir cambio',
      icon: PhosphorIconsBold.arrowCounterClockwise,
      iconColor: AppColors.primary,
      bodyLines: [
        'Mantendras tu plan actual sin cambios.',
        'No se realizan cobros adicionales.',
      ],
      ctaLabel: 'Revertir',
      ctaColor: AppColors.primary,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await SubscriptionService.instance.revertPendingChange();
      await _load();
      if (mounted) _showSnack('Cambio revertido. Sigues con tu plan actual.');
    } catch (e) {
      if (mounted) _showSnack('No se pudo revertir: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showConfirm({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> bodyLines,
    required String ctaLabel,
    required Color ctaColor,
  }) {
    HapticFeedback.selectionClick();
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.darkSurfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in bodyLines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: ctaColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(ctaLabel),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        title: const Text(
          'Gestionar suscripcion',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final status = _status!;
    if (status.tier == SubscriptionTier.free) {
      return const _EmptyStateFree();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CurrentPlanCard(
            tier: status.tier,
            variant: status.variant,
            periodEnd: status.periodEnd,
            monthlyPrice: _monthlyPriceFor(status.tier, status.variant),
            fmtClp: _fmtClp,
            fmtDate: _fmtDate,
          ),
          if (status.hasPendingChange) ...[
            const SizedBox(height: 12),
            _PendingChangeBanner(
              currentTier: status.tier,
              pendingTier: status.pendingTier!,
              periodEnd: status.periodEnd,
              fmtDate: _fmtDate,
              onRevert: _busy ? null : _confirmRevert,
            ),
          ],
          const SizedBox(height: 20),
          const _SectionTitle('Cambiar de plan'),
          const SizedBox(height: 8),
          ..._buildActions(status),
          const SizedBox(height: 24),
          const Text(
            'Los precios siguen tu tarifa actual (lanzamiento o founder si aplica). '
            'Cancela cuando quieras: mantienes el plan hasta el fin del periodo pagado.',
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(SubscriptionStatus status) {
    final actions = <Widget>[];
    final pending = status.pendingTier;

    if (status.tier == SubscriptionTier.plus) {
      actions.add(_ActionRow(
        icon: PhosphorIconsBold.arrowUp,
        iconColor: AppColors.accentOrange,
        title: 'Subir a Premium',
        subtitle:
            'Cambio inmediato. Te cobramos solo la diferencia prorrateada.',
        onTap: _busy ? null : _confirmUpgradeToPremium,
      ));
    }

    if (status.tier == SubscriptionTier.premium) {
      final alreadyDowngrade = pending == SubscriptionTier.plus;
      actions.add(_ActionRow(
        icon: PhosphorIconsBold.arrowDown,
        iconColor: AppColors.settingsWarning,
        title: 'Bajar a Plus',
        subtitle: alreadyDowngrade
            ? 'Ya tienes esta bajada agendada.'
            : 'Mantienes Premium hasta el fin del periodo. Luego pasas a Plus.',
        onTap: (_busy || alreadyDowngrade) ? null : _confirmDowngradeToPlus,
      ));
    }

    final alreadyCancel = pending == SubscriptionTier.free;
    actions.add(_ActionRow(
      icon: PhosphorIconsBold.x,
      iconColor: AppColors.settingsDanger,
      title: 'Cancelar suscripcion',
      subtitle: alreadyCancel
          ? 'Ya tienes la cancelacion agendada.'
          : 'Mantienes tu plan hasta el fin del periodo. Luego pasas a Free.',
      onTap: (_busy || alreadyCancel) ? null : _confirmCancellation,
    ));

    final out = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      out.add(actions[i]);
      if (i < actions.length - 1) out.add(const SizedBox(height: 10));
    }
    return out;
  }
}

class _EmptyStateFree extends StatelessWidget {
  const _EmptyStateFree();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsBold.sparkle,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Estas en Free',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Aun no tienes una suscripcion activa. Elige un plan para desbloquear funciones adicionales.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.deepBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ver planes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final SubscriptionVariant variant;
  final DateTime? periodEnd;
  final int monthlyPrice;
  final String Function(int) fmtClp;
  final String Function(DateTime?) fmtDate;

  const _CurrentPlanCard({
    required this.tier,
    required this.variant,
    required this.periodEnd,
    required this.monthlyPrice,
    required this.fmtClp,
    required this.fmtDate,
  });

  String get _tierName {
    switch (tier) {
      case SubscriptionTier.plus:
        return 'Plus';
      case SubscriptionTier.premium:
        return 'Premium';
      default:
        return 'Free';
    }
  }

  String? get _variantTag {
    switch (variant) {
      case SubscriptionVariant.founder:
        return 'Founder';
      case SubscriptionVariant.launch:
        return 'Lanzamiento';
      case SubscriptionVariant.normal:
        return null;
    }
  }

  Color get _accent {
    return tier == SubscriptionTier.premium
        ? const Color(0xFFFFE08A)
        : AppColors.accentOrange;
  }

  @override
  Widget build(BuildContext context) {
    final tag = _variantTag;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _tierName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${fmtClp(monthlyPrice)}/mes',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.calendar,
                color: Colors.white54,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                periodEnd != null
                    ? 'Renueva el ${fmtDate(periodEnd)}'
                    : 'Sin fecha de renovacion registrada',
                style: const TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingChangeBanner extends StatelessWidget {
  final SubscriptionTier currentTier;
  final SubscriptionTier pendingTier;
  final DateTime? periodEnd;
  final String Function(DateTime?) fmtDate;
  final VoidCallback? onRevert;

  const _PendingChangeBanner({
    required this.currentTier,
    required this.pendingTier,
    required this.periodEnd,
    required this.fmtDate,
    required this.onRevert,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    if (pendingTier == SubscriptionTier.free) {
      label =
          'Cancelacion agendada. Pasaras a Free el ${fmtDate(periodEnd)}.';
    } else if (pendingTier == SubscriptionTier.plus &&
        currentTier == SubscriptionTier.premium) {
      label = 'Bajada a Plus agendada para el ${fmtDate(periodEnd)}.';
    } else {
      label = 'Cambio agendado para el ${fmtDate(periodEnd)}.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.settingsWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.settingsWarning.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsBold.clock,
            color: AppColors.settingsWarning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: onRevert,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.settingsWarning,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text(
              'Revertir',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: AppColors.darkSurfaceCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  PhosphorIconsBold.caretRight,
                  size: 14,
                  color: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodOption extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PeriodOption({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: AppColors.darkBorder),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
