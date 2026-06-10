import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/change_quota_service.dart';
import '../../services/profile_photo_local.dart';
import '../../services/subscription_service.dart';
import '../../services/supabase_service.dart';
import '../plans/manage_subscription_screen.dart';
import '../plans/plans_screen.dart';
import '../social/referral_screen.dart';
import 'settings/legal_document_screen.dart';
import 'settings/sections/danger_zone.dart';
import 'settings/sections/hero_profile_header.dart';
import 'settings/sections/premium_promo_card.dart';
import 'settings/sections/settings_pill.dart';
import 'settings/sections/settings_section.dart';
import 'settings/sections/settings_tile.dart';
import '../ai_trainer/monthly_report_screen.dart';
import '../ai_trainer/weekly_checkin_sheet.dart';
import 'settings/sheets/change_goal_sheet.dart';
import 'settings/sheets/change_location_sheet.dart';
import 'settings/sheets/delete_account_sheet.dart';
import 'settings/sheets/weight_quick_sheet.dart';

class AccountSettingsScreen extends StatefulWidget {
  final String currentUsername;
  final String currentBio;

  const AccountSettingsScreen({
    super.key,
    required this.currentUsername,
    required this.currentBio,
  });

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  // Estado servidor (snapshot original).
  String _origUsername = '';
  String _origBio = '';
  String _fullName = '';
  String? _avatarUrl;
  File? _localAvatar;
  double? _weight;
  double? _targetWeight;
  String? _fitnessGoal;
  String? _trainingLocation;
  SubscriptionTier _tier = SubscriptionTier.free;

  int _changesUsed = 0;
  int _changesLimit = ChangeQuotaService.yearlyLimit;

  bool _loading = true;
  bool _uploadingAvatar = false;
  bool _saving = false;
  bool _usernameError = false;
  String? _usernameErrorMsg;

  @override
  void initState() {
    super.initState();
    _origUsername = widget.currentUsername;
    _origBio = widget.currentBio;
    _usernameController.text = widget.currentUsername;
    _bioController.text = widget.currentBio;
    _usernameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _bootstrap() async {
    try {
      final profile = await SupabaseService.instance.getRawMyProfile();
      final tier = await SubscriptionService.instance.currentTier();
      final quota = await ChangeQuotaService.instance.quotaFor();

      if (!mounted) return;
      setState(() {
        _fullName = (profile?['full_name'] as String?) ?? '';
        _origUsername = (profile?['username'] as String?) ?? widget.currentUsername;
        _origBio = (profile?['bio'] as String?) ?? widget.currentBio;
        _avatarUrl = profile?['avatar_url'] as String?;
        _weight = (profile?['weight'] as num?)?.toDouble();
        _targetWeight = (profile?['target_weight'] as num?)?.toDouble();
        _fitnessGoal = profile?['fitness_goal'] as String?;
        _trainingLocation = profile?['training_location'] as String?;
        _tier = tier;
        _changesUsed = quota.used;
        _changesLimit = quota.limit;
        if (_usernameController.text.isEmpty) _usernameController.text = _origUsername;
        if (_bioController.text.isEmpty) _bioController.text = _origBio;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasUnsavedChanges {
    final u = _usernameController.text.trim();
    final b = _bioController.text.trim();
    if (u != _origUsername.trim()) return true;
    if (b != _origBio.trim()) return true;
    return false;
  }

  bool _validateUsername(String v) {
    final re = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    return re.hasMatch(v);
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.settingsElevated,
        title: const Text('Descartar cambios?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tienes cambios sin guardar. Si sales se perderan.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Descartar',
              style: TextStyle(color: AppColors.settingsDanger),
            ),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _localAvatar = file;
      _uploadingAvatar = true;
    });
    LocalProfilePhoto.setImage(file);
    try {
      final url = await SupabaseService.instance.uploadAvatar(file);
      if (!mounted) return;
      setState(() {
        _avatarUrl = url;
        _uploadingAvatar = false;
      });
      _snack('Foto actualizada', icon: PhosphorIconsFill.checkCircle);
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      _snack('Error al subir la foto', icon: PhosphorIconsRegular.warning);
    }
  }

  Future<void> _saveChanges() async {
    final newUsername = _usernameController.text.trim();
    final newBio = _bioController.text.trim();

    if (newUsername != _origUsername.trim()) {
      if (!_validateUsername(newUsername)) {
        setState(() {
          _usernameError = true;
          _usernameErrorMsg =
              'Usa 3-30 caracteres: letras, numeros, "." o "_".';
        });
        return;
      }
      final uid = SupabaseService.instance.client.auth.currentUser?.id ?? '';
      final taken = await SupabaseService.instance.client
          .from('profiles')
          .select('id')
          .eq('username', newUsername)
          .neq('id', uid)
          .limit(1);
      if ((taken as List).isNotEmpty) {
        setState(() {
          _usernameError = true;
          _usernameErrorMsg = 'Ese nombre de usuario ya está en uso.';
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _usernameError = false;
      _usernameErrorMsg = null;
    });

    try {
      await SupabaseService.instance.updateProfile(
        username: newUsername != _origUsername ? newUsername : null,
        bio: newBio != _origBio ? newBio : null,
      );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() {
        _origUsername = newUsername;
        _origBio = newBio;
        _saving = false;
      });
      _snack('Cambios guardados', icon: PhosphorIconsFill.checkCircle);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('No se pudo guardar', icon: PhosphorIconsRegular.warning);
    }
  }

  void _snack(String msg, {IconData icon = PhosphorIconsRegular.info}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.settingsElevated,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWeightSheet() async {
    final ok = await WeightQuickSheet.show(context);
    if (ok == true) {
      // Refrescar peso (vale la pena leer profiles? El peso queda en weight_logs,
      // no actualizamos profile.weight automaticamente. Solo refrescamos UI logs).
      _snack('Peso registrado', icon: PhosphorIconsFill.checkCircle);
    }
  }

  Future<void> _openGoalSheet() async {
    final selected = await ChangeGoalSheet.show(context, _fitnessGoal);
    if (selected != null && selected != _fitnessGoal) {
      if (!mounted) return;
      setState(() {
        _fitnessGoal = selected;
        _changesUsed += 1;
      });
      _snack('Objetivo actualizado', icon: PhosphorIconsFill.checkCircle);
    }
  }

  Future<void> _openLocationSheet() async {
    final selected = await ChangeLocationSheet.show(context, _trainingLocation);
    if (selected != null && selected != _trainingLocation) {
      if (!mounted) return;
      setState(() {
        _trainingLocation = selected;
        _changesUsed += 1;
      });
      _snack('Lugar actualizado', icon: PhosphorIconsFill.checkCircle);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.settingsElevated,
        title: const Text('Cerrar sesion?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Volveras a la pantalla de inicio.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Cerrar sesion',
              style: TextStyle(color: AppColors.settingsDanger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AuthService().signOut();
    } catch (_) {
      await SupabaseService.instance.client.auth.signOut();
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  Future<void> _confirmDelete() async {
    await DeleteAccountSheet.show(context);
  }

  void _openPremiumPaywall() {
    PlansScreen.open(context);
  }

  SettingsPillState _pillStateFor(int used) {
    final remaining = _changesLimit - used;
    if (remaining <= 0) return SettingsPillState.locked;
    if (remaining <= 1) return SettingsPillState.warning;
    return SettingsPillState.hidden;
  }

  String _pillLabelFor(int used) {
    final remaining = _changesLimit - used;
    if (remaining <= 0) return 'Bloqueado';
    return 'Quedan $remaining';
  }

  @override
  Widget build(BuildContext context) {
    final hasChanges = _hasUnsavedChanges;
    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final ok = await _onWillPop();
        if (ok && mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.settingsSurface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('Configuracion'),
          centerTitle: true,
        ),
        body: _loading ? _loadingState() : _content(),
        bottomNavigationBar: hasChanges ? _stickySaveBar() : null,
      ),
    );
  }

  Widget _loadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _content() {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            HeroProfileHeader(
              fullName: _fullName,
              username: _usernameController.text.isNotEmpty
                  ? _usernameController.text
                  : _origUsername,
              avatarUrl: _avatarUrl,
              localAvatar: _localAvatar,
              uploadingAvatar: _uploadingAvatar,
              tier: _tier,
              onChangeAvatar: _pickAvatar,
            ),
            _publicProfileSection(),
            _physicalSection(),
            _trainingSection(),
            _communitySection(),
            if (_tier != SubscriptionTier.free) _aiSection(),
            if (_tier == SubscriptionTier.free)
              PremiumPromoCard(onTap: _openPremiumPaywall),
            _subscriptionSection(),
            _legalSection(),
            _accountSection(),
            DangerZone(onDeleteAccount: _confirmDelete),
          ],
        ),
      ),
    );
  }

  Widget _communitySection() {
    return SettingsSection(
      title: 'Comunidad',
      children: [
        SettingsTile(
          leadingIcon: Icons.card_giftcard_rounded,
          leadingColor: AppColors.accentOrange,
          title: 'Invita amigos',
          subtitle: 'Comparte tu código y haz crecer la comunidad',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReferralScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _publicProfileSection() {
    return SettingsSection(
      title: 'Perfil publico',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Usuario',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(color: Colors.white70),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                  errorText: _usernameError ? _usernameErrorMsg : null,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Biografia',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _bioController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 3,
                maxLength: 150,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Cuentanos algo sobre ti',
                  hintStyle: TextStyle(color: Colors.white24),
                  counterStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _physicalSection() {
    return SettingsSection(
      title: 'Datos fisicos',
      children: [
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.scales,
          title: 'Peso actual',
          subtitle:
              _weight != null ? '${_weight!.toStringAsFixed(1)} kg' : 'Sin registrar',
          onTap: _openWeightSheet,
        ),
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.flag,
          title: 'Peso objetivo',
          subtitle: _targetWeight != null
              ? '${_targetWeight!.toStringAsFixed(1)} kg'
              : 'Sin definir',
          showChevron: false,
          trailing: const SizedBox.shrink(),
        ),
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.chartLineUp,
          title: 'Historial completo',
          onTap: () => Navigator.pushNamed(context, '/weight-log'),
        ),
      ],
    );
  }

  Widget _trainingSection() {
    return SettingsSection(
      title: 'Entrenamiento',
      children: [
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.target,
          title: 'Objetivo',
          subtitle: labelForGoal(_fitnessGoal),
          pillState: _pillStateFor(_changesUsed),
          pillLabel: _pillLabelFor(_changesUsed),
          onTap: _openGoalSheet,
        ),
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.mapPin,
          title: 'Lugar de entrenamiento',
          subtitle: labelForLocation(_trainingLocation),
          pillState: _pillStateFor(_changesUsed),
          pillLabel: _pillLabelFor(_changesUsed),
          onTap: _openLocationSheet,
        ),
      ],
    );
  }

  Future<void> _openManageSubscription() async {
    await ManageSubscriptionScreen.open(context);
    if (!mounted) return;
    SubscriptionService.instance.invalidate();
    final tier = await SubscriptionService.instance.currentTier(
      forceRefresh: true,
    );
    if (!mounted) return;
    setState(() => _tier = tier);
  }

  String _tierLabelFor(SubscriptionTier t) {
    switch (t) {
      case SubscriptionTier.plus:
        return 'Plus';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.free:
        return 'Free';
    }
  }

  Widget _subscriptionSection() {
    final isPaid = _tier != SubscriptionTier.free;
    return SettingsSection(
      title: 'Suscripcion',
      children: [
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.crown,
          leadingColor: isPaid
              ? AppColors.accentOrange
              : Colors.white70,
          title: isPaid ? 'Gestionar suscripcion' : 'Ver planes',
          subtitle: 'Plan actual: ${_tierLabelFor(_tier)}',
          onTap: isPaid ? _openManageSubscription : _openPremiumPaywall,
        ),
      ],
    );
  }

  Widget _legalSection() {
    return SettingsSection(
      title: 'Legal',
      children: [
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.shieldCheck,
          title: 'Politica de privacidad',
          onTap: () => Navigator.pushNamed(context, '/legal/privacy'),
        ),
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.fileText,
          title: 'Terminos y condiciones',
          onTap: () => Navigator.pushNamed(context, '/legal/terms'),
        ),
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.users,
          title: 'Reglas de comunidad',
          onTap: () => Navigator.pushNamed(context, '/legal/community'),
        ),
      ],
    );
  }

  Widget _accountSection() {
    return SettingsSection(
      title: 'Cuenta',
      children: [
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.signOut,
          leadingColor: Colors.white70,
          title: 'Cerrar sesion',
          showChevron: true,
          onTap: _confirmLogout,
        ),
      ],
    );
  }

  Widget _aiSection() {
    return SettingsSection(
      title: 'Entrenador IA',
      children: [
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.calendarCheck,
          title: 'Check-in semanal',
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.darkSurfaceCard,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const WeeklyCheckinSheet(),
            );
          },
        ),
        SettingsTile(
          leadingIcon: PhosphorIconsRegular.chartBar,
          title: 'Reporte mensual IA',
          onTap: () => MonthlyReportScreen.open(context),
        ),
      ],
    );
  }

  Widget _stickySaveBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.deepBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.deepBlue,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Guardar cambios',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Helper para `routes.dart`: construye `LegalDocumentScreen` desde un slug.
Widget buildLegalScreen(String slug) => LegalDocumentScreen(slug: slug);
