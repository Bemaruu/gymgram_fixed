import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Claves PUBLICAS de RevenueCat (son seguras de incluir en el cliente, igual
/// que la anon key de Supabase). Se inyectan con --dart-define:
///   --dart-define=REVENUECAT_APPLE_KEY=appl_xxx
///   --dart-define=REVENUECAT_GOOGLE_KEY=goog_xxx
const _rcAppleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');
const _rcGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

enum PurchaseStatus { success, cancelled, error }

class PurchaseOutcome {
  final PurchaseStatus status;
  final String? message;
  const PurchaseOutcome._(this.status, this.message);

  factory PurchaseOutcome.success() =>
      const PurchaseOutcome._(PurchaseStatus.success, null);
  factory PurchaseOutcome.cancelled() =>
      const PurchaseOutcome._(PurchaseStatus.cancelled, null);
  factory PurchaseOutcome.error(String message) =>
      PurchaseOutcome._(PurchaseStatus.error, message);
}

/// Capa de pagos. Usa Apple In-App Purchase / Google Play Billing via RevenueCat.
///
/// Mapea el appUserID de RevenueCat al user id de Supabase, de modo que el
/// webhook (`supabase/functions/revenuecat-webhook`) puede ubicar el perfil y
/// actualizar `subscription_tier` con service_role. El cliente NUNCA escribe el
/// tier directamente (lo bloquea el trigger en profiles).
///
/// Convencion de identificadores de paquete en RevenueCat (offering "default"):
///   plus_monthly   plus_annual   premium_monthly   premium_annual
class PurchaseService {
  static final PurchaseService instance = PurchaseService._();
  PurchaseService._();

  bool _configured = false;
  StreamSubscription? _authSub;

  bool get isAvailable => _configured;

  /// Inicializa RevenueCat. Se debe llamar una sola vez al arrancar la app.
  /// Si las claves no estan configuradas no hace nada (la app sigue funcionando,
  /// las compras simplemente no estaran disponibles).
  Future<void> init() async {
    if (_configured) return;
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;

    final apiKey = Platform.isIOS ? _rcAppleKey : _rcGoogleKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) debugPrint('PurchaseService: clave RevenueCat no configurada, pagos off.');
      return;
    }

    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);

      final uid = Supabase.instance.client.auth.currentUser?.id;
      final config = PurchasesConfiguration(apiKey);
      if (uid != null) config.appUserID = uid;
      await Purchases.configure(config);
      _configured = true;

      // Mantener el appUserID de RevenueCat sincronizado con la sesion Supabase.
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final newUid = data.session?.user.id;
        try {
          if (newUid != null) {
            await Purchases.logIn(newUid);
          } else {
            await Purchases.logOut();
          }
        } catch (e) {
          if (kDebugMode) debugPrint('PurchaseService auth sync error: $e');
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('PurchaseService init error: $e');
    }
  }

  /// Lanza el flujo de compra nativo (Apple/Google) para el tier y periodo dados.
  /// [tier] = 'plus' | 'premium'.  [period] = 'monthly' | 'annual'.
  /// El tier real del usuario lo confirma el webhook contra Supabase; aqui solo
  /// gestionamos el flujo de pago y errores de cara al usuario.
  Future<PurchaseOutcome> purchase({
    required String tier,
    required String period,
  }) async {
    if (!_configured) {
      return PurchaseOutcome.error('Los pagos no estan disponibles ahora mismo.');
    }
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null || current.availablePackages.isEmpty) {
        return PurchaseOutcome.error('No hay planes disponibles por ahora.');
      }

      final pkg = _findPackage(current, tier, period);
      if (pkg == null) {
        return PurchaseOutcome.error('No se encontro el plan seleccionado.');
      }

      await Purchases.purchasePackage(pkg);
      // El webhook actualizara profiles.subscription_tier en segundos.
      return PurchaseOutcome.success();
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseOutcome.cancelled();
      }
      return PurchaseOutcome.error(_messageFor(code));
    } catch (e) {
      if (kDebugMode) debugPrint('PurchaseService.purchase error: $e');
      return PurchaseOutcome.error('Ocurrio un error. Intenta de nuevo.');
    }
  }

  /// Restaura compras previas (requisito de App Store: boton "Restaurar").
  Future<PurchaseOutcome> restore() async {
    if (!_configured) {
      return PurchaseOutcome.error('Los pagos no estan disponibles ahora mismo.');
    }
    try {
      await Purchases.restorePurchases();
      return PurchaseOutcome.success();
    } catch (e) {
      if (kDebugMode) debugPrint('PurchaseService.restore error: $e');
      return PurchaseOutcome.error('No se pudieron restaurar las compras.');
    }
  }

  Package? _findPackage(Offering offering, String tier, String period) {
    final wantedId = '${tier}_$period';
    for (final p in offering.availablePackages) {
      if (p.identifier == wantedId) return p;
    }
    // Fallback: emparejar por el identificador del producto de la tienda.
    final t = tier.toLowerCase();
    final pMonthly = period == 'annual' ? 'annual' : 'monthly';
    final pAlt = period == 'annual' ? 'yearly' : 'month';
    for (final p in offering.availablePackages) {
      final id = p.storeProduct.identifier.toLowerCase();
      if (id.contains(t) && (id.contains(pMonthly) || id.contains(pAlt))) {
        return p;
      }
    }
    return null;
  }

  String _messageFor(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Las compras no estan permitidas en este dispositivo.';
      case PurchasesErrorCode.paymentPendingError:
        return 'Tu pago quedo pendiente de aprobacion.';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'Ya tienes este plan activo.';
      case PurchasesErrorCode.networkError:
        return 'Sin conexion. Revisa tu internet e intenta de nuevo.';
      default:
        return 'No se pudo completar la compra. Intenta de nuevo.';
    }
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    _authSub = null;
  }
}
