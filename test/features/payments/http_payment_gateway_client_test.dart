import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluir_customer/features/payments/domain/models/payment_customer_identity.dart';
import 'package:fluir_customer/features/payments/domain/payment_gateway_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'payments_test_gateway.dart';

void main() {
  const identity = PaymentCustomerIdentity.debugFallback;

  test('tokenising a card carries the documented contract', () async {
    late http.Request captured;
    final client = PaymentsTestGateway.client((request) async {
      captured = request;
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodBody(last4: '1111'),
      );
    });

    final method = await client.tokenizeCard(
      identity: identity,
      card: PaymentsTestGateway.card(),
      idempotencyKey: 'key-1',
      makeDefault: true,
    );

    expect(
      captured.url.path,
      '/v1/companies/${PaymentsTestGateway.companyId}/tenants/'
      '${identity.tenantReference}/payment-methods',
    );
    expect(captured.method, 'POST');
    expect(captured.headers['Idempotency-Key'], 'key-1');
    expect(captured.headers['Content-Type'], contains('application/json'));

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['environment'], 'SANDBOX');
    expect(body['userId'], identity.userId);
    expect(body['makeDefault'], isTrue);
    final card = body['card'] as Map<String, dynamic>;
    expect(card['number'], PaymentsTestGateway.testPan);
    expect(card['expiration'], '3012');
    expect(card['cvc'], '123');
    expect(card['holderName'], 'Ana Pérez');

    expect(method.last4, '1111');
  });

  test('the request never carries merchant or internal credentials', () async {
    late http.Request captured;
    final client = PaymentsTestGateway.client((request) async {
      captured = request;
      return PaymentsTestGateway.json(PaymentsTestGateway.paymentMethodBody());
    });

    await client.tokenizeCard(
      identity: identity,
      card: PaymentsTestGateway.card(),
      idempotencyKey: 'key-1',
    );

    final serialized = '${captured.headers}${captured.body}'.toLowerCase();
    for (final secret in const [
      'merchantid',
      'authkey',
      'auth1',
      'auth2',
      'authhash',
      'datavaulttoken',
      'x-internal-api-key',
    ]) {
      expect(serialized, isNot(contains(secret)), reason: secret);
    }
  });

  test('a declined tokenisation explains itself without the body', () async {
    final client = PaymentsTestGateway.client(
      (_) async => http.Response('{"azulResponse":"DECLINED 05"}', 422),
    );

    try {
      await client.tokenizeCard(
        identity: identity,
        card: PaymentsTestGateway.card(),
        idempotencyKey: 'key-1',
      );
      fail('Expected a PaymentGatewayException.');
    } on PaymentGatewayException catch (error) {
      expect(error.failure, PaymentGatewayFailure.invalidRequest);
      expect(error.message, contains('no autorizó'));
      expect(error.toString(), isNot(contains('DECLINED 05')));
    }
  });

  test('payment method reads use the documented path', () async {
    final paths = <String>[];
    final client = PaymentsTestGateway.client((request) async {
      paths.add(request.url.toString());
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(),
        ]),
      );
    });

    await client.fetchActivePaymentMethods(identity);

    expect(
      paths.single,
      '${PaymentsTestGateway.baseUrl}/v1/companies/'
      '${PaymentsTestGateway.companyId}/tenants/${identity.tenantReference}/'
      'payment-methods?status=ACTIVE',
    );
  });

  test('only active methods with usable fields are kept', () async {
    final client = PaymentsTestGateway.client(
      (request) async => PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(),
          {
            ...PaymentsTestGateway.paymentMethodBody(id: 'pm_2'),
            'status': 'REVOKED',
          },
          const {'brand': 'VISA'},
        ]),
      ),
    );

    final methods = await client.fetchActivePaymentMethods(identity);

    expect(methods, hasLength(1));
    expect(methods.single.id, 'pm_1');
  });

  test('a bare JSON array is the gateway list shape', () async {
    // PaymentMethodController returns List<PaymentMethodResponse> directly.
    final client = PaymentsTestGateway.client(
      (_) async => http.Response(
        jsonEncode([
          PaymentsTestGateway.paymentMethodBody(),
          {
            ...PaymentsTestGateway.paymentMethodBody(id: 'pm_2'),
            'status': 'REVOKED',
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    final methods = await client.fetchActivePaymentMethods(identity);

    expect(methods, hasLength(1));
    expect(methods.single.id, 'pm_1');
  });

  test('401 is reported as an unauthorised, unrecoverable call', () async {
    final client = PaymentsTestGateway.client(
      (_) async => http.Response(
        '{"code":"unauthorized",'
        '"message":"Missing or invalid internal API key"}',
        401,
        headers: {'content-type': 'application/json'},
      ),
    );

    try {
      await client.fetchActivePaymentMethods(identity);
      fail('Expected a PaymentGatewayException.');
    } on PaymentGatewayException catch (error) {
      expect(error.failure, PaymentGatewayFailure.unauthorized);
      expect(error.isRecoverable, isFalse);
      // The gateway's own wording is not echoed to the customer.
      expect(error.message, isNot(contains('internal API key')));
    }
  });

  group('payment method actions', () {
    test('make-default posts to the verified route', () async {
      late http.BaseRequest captured;
      final client = PaymentsTestGateway.client((request) async {
        captured = request;
        return PaymentsTestGateway.json(const {});
      });

      await client.setDefaultPaymentMethod(
        identity: identity,
        paymentMethodId: 'pm_9',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        '${PaymentsTestGateway.baseUrl}/v1/companies/'
        '${PaymentsTestGateway.companyId}/tenants/'
        '${identity.tenantReference}/payment-methods/pm_9/make-default',
      );
    });

    test('revoke posts to the verified route and never deletes', () async {
      late http.BaseRequest captured;
      final client = PaymentsTestGateway.client((request) async {
        captured = request;
        return PaymentsTestGateway.json(const {});
      });

      await client.revokePaymentMethod(
        identity: identity,
        paymentMethodId: 'pm_9',
      );

      expect(captured.method, 'POST');
      expect(captured.method, isNot('DELETE'));
      expect(
        captured.url.toString(),
        '${PaymentsTestGateway.baseUrl}/v1/companies/'
        '${PaymentsTestGateway.companyId}/tenants/'
        '${identity.tenantReference}/payment-methods/pm_9/revoke',
      );
    });

    test('an empty 204 body is a valid success', () async {
      final client = PaymentsTestGateway.client(
        (_) async => http.Response('', 204),
      );

      await expectLater(
        client.revokePaymentMethod(identity: identity, paymentMethodId: 'pm_9'),
        completes,
      );
    });

    test('404 reports the card as no longer available', () async {
      final client = PaymentsTestGateway.client(
        (_) async => PaymentsTestGateway.json(const {}, 404),
      );

      try {
        await client.revokePaymentMethod(
          identity: identity,
          paymentMethodId: 'pm_9',
        );
        fail('Expected a PaymentGatewayException.');
      } on PaymentGatewayException catch (error) {
        expect(error.failure, PaymentGatewayFailure.notFound);
        expect(error.isRecoverable, isFalse);
        expect(error.message, contains('ya no está disponible'));
      }
    });

    test('409 is recoverable and stays specific to the action', () async {
      final client = PaymentsTestGateway.client(
        (_) async => PaymentsTestGateway.json(const {}, 409),
      );

      try {
        await client.setDefaultPaymentMethod(
          identity: identity,
          paymentMethodId: 'pm_9',
        );
        fail('Expected a PaymentGatewayException.');
      } on PaymentGatewayException catch (error) {
        expect(error.failure, PaymentGatewayFailure.conflict);
        expect(error.isRecoverable, isTrue);
        expect(error.message, contains('predeterminada'));
      }
    });
  });

  group('failure mapping', () {
    Future<PaymentGatewayFailure> failureFor(
      Future<http.Response> Function(http.Request) handler,
    ) async {
      final client = PaymentsTestGateway.client(handler);
      try {
        await client.tokenizeCard(
          identity: identity,
          card: PaymentsTestGateway.card(),
          idempotencyKey: 'key-1',
        );
      } on PaymentGatewayException catch (error) {
        return error.failure;
      }
      fail('Expected a PaymentGatewayException.');
    }

    test('409 becomes a recoverable conflict', () async {
      expect(
        await failureFor((_) async => PaymentsTestGateway.json(const {}, 409)),
        PaymentGatewayFailure.conflict,
      );
    });

    test('422 becomes an invalid request', () async {
      expect(
        await failureFor((_) async => PaymentsTestGateway.json(const {}, 422)),
        PaymentGatewayFailure.invalidRequest,
      );
    });

    test('5xx becomes a server failure', () async {
      expect(
        await failureFor((_) async => PaymentsTestGateway.json(const {}, 503)),
        PaymentGatewayFailure.server,
      );
    });

    test('a dropped connection becomes a network failure', () async {
      expect(
        await failureFor((_) async => throw const SocketException('down')),
        PaymentGatewayFailure.network,
      );
    });

    test('a slow gateway becomes a timeout', () async {
      expect(
        await failureFor((_) async => throw TimeoutException('slow')),
        PaymentGatewayFailure.timeout,
      );
    });

    test('an unusable payload becomes an invalid response', () async {
      expect(
        await failureFor(
          (_) async => PaymentsTestGateway.json(const {'unexpected': true}),
        ),
        PaymentGatewayFailure.invalidResponse,
      );
    });

    test('a gateway error message never leaks the response body', () async {
      final client = PaymentsTestGateway.client(
        (_) async => http.Response('{"authHash":"super-secret"}', 500),
      );

      try {
        await client.fetchActivePaymentMethods(identity);
        fail('Expected a PaymentGatewayException.');
      } on PaymentGatewayException catch (error) {
        expect(error.toString(), isNot(contains('super-secret')));
        expect(error.message, isNot(contains('authHash')));
      }
    });
  });
}
