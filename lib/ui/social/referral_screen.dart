import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_colors.dart';
import '../../services/referral_service.dart';

/// Pantalla de referidos: muestra el código del usuario, permite compartirlo y
/// canjear el de un amigo. Lever de viralidad: invita → tu código suma.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _svc = ReferralService.instance;
  final _redeemCtrl = TextEditingController();

  String? _code;
  int _count = 0;
  bool _hasRedeemed = false;
  bool _loading = true;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _redeemCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _svc.getMyCode(),
      _svc.getReferralCount(),
      _svc.hasRedeemed(),
    ]);
    if (!mounted) return;
    setState(() {
      _code = results[0] as String?;
      _count = results[1] as int;
      _hasRedeemed = results[2] as bool;
      _loading = false;
    });
  }

  String get _shareText {
    final c = _code ?? '';
    return '¡Únete a mí en GymGram! 💪 Rutinas, nutrición y comunidad fitness '
        'en una sola app. Usa mi código $c al registrarte.';
  }

  void _copy() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    _toast('Código copiado');
  }

  void _share() {
    if (_code == null) return;
    Share.share(_shareText, subject: 'Únete a GymGram');
  }

  Future<void> _redeem() async {
    setState(() => _redeeming = true);
    final err = await _svc.redeem(_redeemCtrl.text);
    if (!mounted) return;
    setState(() => _redeeming = false);
    if (err == null) {
      setState(() => _hasRedeemed = true);
      _toast('¡Código canjeado! 🎉');
    } else {
      _toast(err);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.settingsElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsSurface,
      appBar: AppBar(
        backgroundColor: AppColors.settingsSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Invita amigos'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroCard(),
                    const SizedBox(height: 24),
                    _statRow(),
                    const SizedBox(height: 24),
                    if (!_hasRedeemed) _redeemSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: AppColors.auroraGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Tu código de invitación',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _copy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _code ?? '------',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _share,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ember500,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.share_rounded),
              label: const Text(
                'Compartir invitación',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.settingsElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '$_count',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _count == 1 ? 'amigo invitado' : 'amigos invitados',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _redeemSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.settingsElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Te invitó alguien?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ingresa su código (solo cuentas nuevas).',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _redeemCtrl,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'CÓDIGO',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: AppColors.settingsSurface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _redeeming ? null : _redeem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _redeeming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Canjear',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
