import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/config/payment_gateway_environment.dart';
import '../../domain/models/card_entry.dart';
import '../../domain/models/payment_customer_identity.dart';
import '../../domain/models/payment_method.dart';
import '../../domain/payment_gateway_exception.dart';
import '../../domain/repositories/payment_gateway_client.dart';

/// Direct HTTP access to the internal Fluir API Gateway.
///
/// DEBUG / SANDBOX ONLY. A mobile client must not be the component that decides
/// which tenant's payment methods it may read, so this implementation may only
/// be wired through [HttpPaymentGatewayClient.fromEnvironment], which refuses
/// to run outside a debug build. Production has to go through an authenticated
/// Fluir backend.
///
/// Card capture happens in the app, so the PAN and the security code travel in
/// the tokenisation request. That puts the gateway — and this client — inside
/// PCI-DSS scope: the transport must stay TLS-only outside the local emulator,
/// and no part of the request body may ever be logged or retried from a stored
/// copy. Nothing here writes the card anywhere; it is read from [CardEntry],
/// encoded and dropped.
class HttpPaymentGatewayClient implements PaymentGatewayClient {
  HttpPaymentGatewayClient({
    required String baseUrl,
    required this.companyId,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  /// Builds the sandbox client from `--dart-define` values.
  ///
  /// Throws when the current build is not allowed to reach the gateway
  /// directly, which is the case for every release build.
  factory HttpPaymentGatewayClient.fromEnvironment({http.Client? client}) {
    if (!PaymentGatewayEnvironment.isDirectGatewayEnabled) {
      throw PaymentGatewayException(
        PaymentGatewayFailure.unavailable,
        PaymentGatewayEnvironment.unavailableReason,
      );
    }
    return HttpPaymentGatewayClient(
      baseUrl: PaymentGatewayEnvironment.baseUrl,
      companyId: PaymentGatewayEnvironment.companyId,
      client: client,
    );
  }

  static const _writeTimeout = Duration(seconds: 25);
  static const _readTimeout = Duration(seconds: 12);
  static const environment = 'SANDBOX';

  final String companyId;
  final Uri _baseUri;
  final http.Client _client;
  final bool _ownsClient;

  Uri endpoint(List<String> segments, [Map<String, String>? query]) {
    final basePath = _baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    return _baseUri.replace(
      pathSegments: [...basePath, ...segments],
      queryParameters: query,
    );
  }

  @override
  Future<PaymentMethod> tokenizeCard({
    required PaymentCustomerIdentity identity,
    required CardEntry card,
    required String idempotencyKey,
    bool makeDefault = false,
  }) async {
    final payload = <String, dynamic>{
      'environment': environment,
      'userId': identity.userId,
      'makeDefault': makeDefault,
      'card': {
        'number': card.number,
        'expiration': card.expirationYyMm,
        'cvc': card.securityCode,
        'holderName': card.holderName,
      },
    };

    final decoded = await _send(
      () => _client.post(
        _tenantPaymentMethods(identity),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(payload),
      ),
      timeout: _writeTimeout,
      conflictMessage:
          'Ya tienes esta tarjeta guardada o hay un registro en curso.',
      invalidRequestMessage:
          'El banco no autorizó esta tarjeta. Revisa los datos o prueba con '
          'otra.',
    );

    final method = PaymentMethod.tryParse(decoded);
    if (method == null) {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.invalidResponse,
        'No pudimos confirmar el registro de la tarjeta.',
      );
    }
    return method;
  }

  @override
  Future<List<PaymentMethod>> fetchActivePaymentMethods(
    PaymentCustomerIdentity identity,
  ) async {
    final decoded = await _send(
      () => _client.get(
        _tenantPaymentMethods(identity, const {'status': 'ACTIVE'}),
        headers: const {'Accept': 'application/json'},
      ),
      timeout: _readTimeout,
      allowList: true,
    );

    final items = decoded['items'] ?? decoded['data'] ?? decoded['_list'];
    if (items is! List) {
      return const [];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethod.tryParse)
        .whereType<PaymentMethod>()
        .where((method) => method.isActive)
        .toList(growable: false);
  }

  /// Sets [paymentMethodId] as the tenant default.
  ///
  /// `POST …/payment-methods/{paymentMethodId}/make-default`.
  Future<void> setDefaultPaymentMethod({
    required PaymentCustomerIdentity identity,
    required String paymentMethodId,
  }) => _send(
    () => _client.post(
      _paymentMethodAction(identity, paymentMethodId, 'make-default'),
      headers: const {'Accept': 'application/json'},
    ),
    timeout: _readTimeout,
    allowEmptyBody: true,
    notFoundMessage: 'Esta tarjeta ya no está disponible en tu cuenta.',
    conflictMessage:
        'No pudimos cambiar tu tarjeta predeterminada en este momento. '
        'Inténtalo de nuevo.',
  );

  /// Logically revokes a saved card.
  ///
  /// `POST …/payment-methods/{paymentMethodId}/revoke`. The gateway owns the
  /// card's lifecycle: the app never deletes it physically.
  Future<void> revokePaymentMethod({
    required PaymentCustomerIdentity identity,
    required String paymentMethodId,
  }) => _send(
    () => _client.post(
      _paymentMethodAction(identity, paymentMethodId, 'revoke'),
      headers: const {'Accept': 'application/json'},
    ),
    timeout: _readTimeout,
    allowEmptyBody: true,
    notFoundMessage: 'Esta tarjeta ya no está disponible en tu cuenta.',
    conflictMessage:
        'No pudimos eliminar esta tarjeta en este momento. Inténtalo de nuevo.',
  );

  Uri _tenantPaymentMethods(
    PaymentCustomerIdentity identity, [
    Map<String, String>? query,
  ]) => endpoint([
    'v1',
    'companies',
    companyId,
    'tenants',
    identity.tenantReference,
    'payment-methods',
  ], query);

  Uri _paymentMethodAction(
    PaymentCustomerIdentity identity,
    String paymentMethodId,
    String action,
  ) => endpoint([
    'v1',
    'companies',
    companyId,
    'tenants',
    identity.tenantReference,
    'payment-methods',
    paymentMethodId,
    action,
  ]);

  /// Performs the request and maps transport/HTTP problems onto
  /// [PaymentGatewayException]. Request and response bodies are never logged.
  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    required Duration timeout,
    bool allowList = false,
    bool allowEmptyBody = false,
    String? conflictMessage,
    String? notFoundMessage,
    String? invalidRequestMessage,
  }) async {
    late final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.timeout,
        'El servicio de pagos tardó demasiado en responder.',
      );
    } on SocketException {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.network,
        'No pudimos conectar con el servicio de pagos.',
      );
    } on http.ClientException {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.network,
        'No pudimos conectar con el servicio de pagos.',
      );
    }

    _throwForStatus(
      response.statusCode,
      conflictMessage: conflictMessage,
      notFoundMessage: notFoundMessage,
      invalidRequestMessage: invalidRequestMessage,
    );

    final body = response.body.trim();
    if (body.isEmpty) {
      if (allowEmptyBody) {
        return const <String, dynamic>{};
      }
      throw const PaymentGatewayException(
        PaymentGatewayFailure.invalidResponse,
        'El servicio de pagos respondió sin contenido.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.invalidResponse,
        'El servicio de pagos respondió en un formato inesperado.',
      );
    }

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (allowList && decoded is List) {
      return <String, dynamic>{'_list': decoded};
    }
    throw const PaymentGatewayException(
      PaymentGatewayFailure.invalidResponse,
      'El servicio de pagos respondió en un formato inesperado.',
    );
  }

  void _throwForStatus(
    int statusCode, {
    String? conflictMessage,
    String? notFoundMessage,
    String? invalidRequestMessage,
  }) {
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    if (statusCode == 401 || statusCode == 403) {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.unauthorized,
        'El servicio de pagos no autorizó esta consulta. La gestión de '
        'tarjetas necesita el backend autenticado de Fluir.',
      );
    }
    if (statusCode == 404) {
      throw PaymentGatewayException(
        PaymentGatewayFailure.notFound,
        notFoundMessage ?? 'El servicio de pagos no encontró el recurso.',
      );
    }
    if (statusCode == 409) {
      throw PaymentGatewayException(
        PaymentGatewayFailure.conflict,
        conflictMessage ??
            'Ya hay un registro de tarjeta en curso. Inténtalo de nuevo.',
      );
    }
    if (statusCode == 422) {
      throw PaymentGatewayException(
        PaymentGatewayFailure.invalidRequest,
        invalidRequestMessage ?? 'El servicio de pagos no aceptó la solicitud.',
      );
    }
    if (statusCode >= 500) {
      throw const PaymentGatewayException(
        PaymentGatewayFailure.server,
        'El servicio de pagos no está disponible en este momento.',
      );
    }
    throw PaymentGatewayException(
      PaymentGatewayFailure.invalidRequest,
      invalidRequestMessage ?? 'El servicio de pagos rechazó la solicitud.',
    );
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
