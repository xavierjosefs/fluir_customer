import 'dart:convert';

import 'package:fluir_customer/features/payments/data/gateway/http_payment_gateway_client.dart';
import 'package:fluir_customer/features/payments/domain/models/card_entry.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Shared sandbox gateway fixtures for the payments tests.
abstract final class PaymentsTestGateway {
  static const baseUrl = 'http://10.0.2.2:8080';
  static const companyId = 'company-test-uuid';

  /// Luhn-valid test PANs. Never real cards.
  static const testPan = '4111111111111111';

  /// Ends in [LocalCardVault.declineLast4], the simulated decline case.
  static const declinedPan = '4111111111170000';

  static HttpPaymentGatewayClient client(MockClientHandler handler) =>
      HttpPaymentGatewayClient(
        baseUrl: baseUrl,
        companyId: companyId,
        client: MockClient(handler),
      );

  static CardEntry card({
    String number = testPan,
    int expiryMonth = 12,
    int expiryYear = 2030,
    String securityCode = '123',
    String holderName = 'Ana Pérez',
  }) => CardEntry(
    number: number,
    expiryMonth: expiryMonth,
    expiryYear: expiryYear,
    securityCode: securityCode,
    holderName: holderName,
  );

  static CardEntryDraft draft({
    String number = '4111 1111 1111 1111',
    String expiry = '12/30',
    String securityCode = '123',
    String holder = 'Ana Pérez',
  }) => CardEntryDraft(
    number: number,
    expiry: expiry,
    securityCode: securityCode,
    holder: holder,
  );

  static http.Response json(Map<String, dynamic> body, [int status = 200]) =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  static Map<String, dynamic> paymentMethodBody({
    String id = 'pm_1',
    String brand = 'VISA',
    String last4 = '4242',
    bool isDefault = true,
  }) => {
    'paymentMethodId': id,
    'brand': brand,
    'last4': last4,
    'expiryMonth': 12,
    'expiryYear': 2030,
    'status': 'ACTIVE',
    'isDefault': isDefault,
  };

  static Map<String, dynamic> paymentMethodsBody(
    List<Map<String, dynamic>> items,
  ) => {'items': items};

  static bool isTokenizeCard(http.BaseRequest request) =>
      request.method == 'POST' && request.url.path.endsWith('/payment-methods');

  static bool isPaymentMethodsRead(http.BaseRequest request) =>
      request.method == 'GET' && request.url.path.endsWith('/payment-methods');

  /// A `make-default` or `revoke` call on a single saved card.
  static bool isPaymentMethodAction(http.BaseRequest request) =>
      request.url.path.endsWith('/make-default') ||
      request.url.path.endsWith('/revoke');
}
