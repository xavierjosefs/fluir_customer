import 'package:flutter/foundation.dart';

/// How the customer app is allowed to reach the AZUL payment gateway.
enum PaymentGatewayMode {
  /// The app talks to a locally running Fluir API Gateway. Debug/sandbox only.
  localSandbox,

  /// No direct gateway access is configured for this build.
  disabled;

  static PaymentGatewayMode parse(String raw) =>
      raw.trim().toLowerCase() == 'localsandbox'
      ? PaymentGatewayMode.localSandbox
      : PaymentGatewayMode.disabled;
}

/// Payment gateway configuration supplied through `--dart-define`.
///
/// Only non-secret routing values live here. Merchant identifiers, auth keys,
/// auth hashes, DataVault tokens and internal API keys are never shipped to or
/// read by the mobile client: they belong to the gateway.
abstract final class PaymentGatewayEnvironment {
  static const baseUrl = String.fromEnvironment(
    'FLUIR_PAYMENT_GATEWAY_BASE_URL',
  );
  static const companyId = String.fromEnvironment('FLUIR_AZUL_COMPANY_ID');
  static const _rawMode = String.fromEnvironment('FLUIR_PAYMENT_MODE');

  static PaymentGatewayMode get mode => PaymentGatewayMode.parse(_rawMode);

  static bool get hasRoutingValues =>
      baseUrl.isNotEmpty && companyId.isNotEmpty;

  /// Direct gateway access is a debug/sandbox affordance. A release build must
  /// never be able to call the internal gateway: production has to go through
  /// an authenticated Fluir backend instead. Without it the wallet falls back
  /// to the on-device simulator, which never touches AZUL.
  static bool get isDirectGatewayEnabled =>
      kDebugMode && mode == PaymentGatewayMode.localSandbox && hasRoutingValues;

  /// Explains to the UI why direct gateway access is unavailable.
  static String get unavailableReason {
    if (!kDebugMode) {
      return 'Los métodos de pago con el gateway interno solo están '
          'disponibles en compilaciones de desarrollo.';
    }
    if (mode != PaymentGatewayMode.localSandbox) {
      return 'Configura FLUIR_PAYMENT_MODE=localSandbox para usar el sandbox '
          'local.';
    }
    return 'Faltan FLUIR_PAYMENT_GATEWAY_BASE_URL o FLUIR_AZUL_COMPANY_ID.';
  }
}
