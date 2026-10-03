import 'package:fluir_customer/features/payments/domain/models/payment_customer_identity.dart';
import 'package:fluir_customer/features/payments/presentation/controllers/payment_methods_controller.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'payments_test_gateway.dart';

void main() {
  ProviderContainer containerWith(MockClientHandler handler) {
    final container = ProviderContainer(
      overrides: [
        paymentGatewayClientProvider.overrideWithValue(
          PaymentsTestGateway.client(handler),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('starts loading and settles on the gateway list', () async {
    final container = containerWith(
      (_) async => PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(id: 'pm_1', isDefault: false),
          PaymentsTestGateway.paymentMethodBody(
            id: 'pm_2',
            brand: 'MASTERCARD',
            last4: '1881',
            isDefault: true,
          ),
        ]),
      ),
    );

    expect(
      container.read(paymentMethodsControllerProvider).status,
      PaymentMethodsStatus.loading,
    );

    await container.read(paymentMethodsControllerProvider.notifier).load();
    final state = container.read(paymentMethodsControllerProvider);

    expect(state.status, PaymentMethodsStatus.ready);
    expect(state.methods, hasLength(2));
    // The default card leads the list.
    expect(state.methods.first.id, 'pm_2');
    expect(state.methods.first.isDefault, isTrue);
    expect(state.errorMessage, isNull);
  });

  test('reports an empty wallet instead of an error', () async {
    final container = containerWith(
      (_) async =>
          PaymentsTestGateway.json(PaymentsTestGateway.paymentMethodsBody([])),
    );

    await container.read(paymentMethodsControllerProvider.notifier).load();
    final state = container.read(paymentMethodsControllerProvider);

    expect(state.status, PaymentMethodsStatus.ready);
    expect(state.isEmpty, isTrue);
  });

  test(
    'surfaces a recoverable error when the gateway is unreachable',
    () async {
      final container = containerWith(
        (_) async => throw http.ClientException('connection refused'),
      );

      await container.read(paymentMethodsControllerProvider.notifier).load();
      final state = container.read(paymentMethodsControllerProvider);

      expect(state.status, PaymentMethodsStatus.error);
      expect(state.isRecoverable, isTrue);
      expect(state.errorMessage, isNotNull);
    },
  );

  test('make-default hits the verified route and re-reads the list', () async {
    var defaultId = 'pm_1';
    final mutations = <http.BaseRequest>[];
    final container = containerWith((request) async {
      if (PaymentsTestGateway.isPaymentMethodAction(request)) {
        mutations.add(request);
        defaultId = 'pm_2';
        return PaymentsTestGateway.json(const {});
      }
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(
            id: 'pm_1',
            isDefault: defaultId == 'pm_1',
          ),
          PaymentsTestGateway.paymentMethodBody(
            id: 'pm_2',
            isDefault: defaultId == 'pm_2',
          ),
        ]),
      );
    });

    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();
    await controller.setDefault('pm_2');

    final mutation = mutations.single;
    expect(mutation.method, 'POST');
    expect(
      mutation.url.toString(),
      '${PaymentsTestGateway.baseUrl}/v1/companies/'
      '${PaymentsTestGateway.companyId}/tenants/'
      '${PaymentCustomerIdentity.debugFallbackReference}/payment-methods/'
      'pm_2/make-default',
    );

    // The list is re-read, never patched locally.
    final state = container.read(paymentMethodsControllerProvider);
    expect(state.busyMethodId, isNull);
    expect(state.methods.first.id, 'pm_2');
    expect(state.methods.first.isDefault, isTrue);
  });

  test('revoke hits the verified route and re-reads the list', () async {
    var revoked = false;
    final mutations = <http.BaseRequest>[];
    final container = containerWith((request) async {
      if (PaymentsTestGateway.isPaymentMethodAction(request)) {
        mutations.add(request);
        revoked = true;
        return PaymentsTestGateway.json(const {});
      }
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody(
          revoked ? [] : [PaymentsTestGateway.paymentMethodBody()],
        ),
      );
    });

    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();
    expect(
      container.read(paymentMethodsControllerProvider).methods,
      hasLength(1),
    );

    await controller.revoke('pm_1');

    final mutation = mutations.single;
    expect(mutation.method, 'POST');
    expect(
      mutation.url.toString(),
      '${PaymentsTestGateway.baseUrl}/v1/companies/'
      '${PaymentsTestGateway.companyId}/tenants/'
      '${PaymentCustomerIdentity.debugFallbackReference}/payment-methods/'
      'pm_1/revoke',
    );
    expect(container.read(paymentMethodsControllerProvider).isEmpty, isTrue);
  });

  test('a card is never deleted physically', () async {
    final methods = <String>[];
    final container = containerWith((request) async {
      methods.add(request.method);
      if (PaymentsTestGateway.isPaymentMethodAction(request)) {
        return PaymentsTestGateway.json(const {});
      }
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(),
        ]),
      );
    });

    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();
    await controller.revoke('pm_1');
    await controller.setDefault('pm_1');

    expect(methods, isNot(contains('DELETE')));
  });

  test('409 keeps the card listed and offers a retry', () async {
    final container = containerWith((request) async {
      if (PaymentsTestGateway.isPaymentMethodAction(request)) {
        return PaymentsTestGateway.json(const {}, 409);
      }
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(),
        ]),
      );
    });

    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();
    await controller.revoke('pm_1');

    final state = container.read(paymentMethodsControllerProvider);
    expect(state.status, PaymentMethodsStatus.ready);
    expect(state.methods, hasLength(1));
    expect(state.errorMessage, isNotNull);
    expect(state.isRecoverable, isTrue);
    expect(state.busyMethodId, isNull);
  });

  test('404 drops the stale card and explains why', () async {
    var listed = true;
    final container = containerWith((request) async {
      if (PaymentsTestGateway.isPaymentMethodAction(request)) {
        // The gateway no longer knows this card.
        listed = false;
        return PaymentsTestGateway.json(const {}, 404);
      }
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody(
          listed ? [PaymentsTestGateway.paymentMethodBody()] : const [],
        ),
      );
    });

    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();
    await controller.setDefault('pm_1');

    final state = container.read(paymentMethodsControllerProvider);
    expect(state.status, PaymentMethodsStatus.ready);
    // The stale card is gone because the list was re-read.
    expect(state.methods, isEmpty);
    expect(state.errorMessage, contains('ya no está disponible'));
    // Retrying the same card cannot help.
    expect(state.isRecoverable, isFalse);
    expect(state.busyMethodId, isNull);
  });

  test('a failed mutation keeps the list and offers a retry', () async {
    final container = containerWith((request) async {
      if (PaymentsTestGateway.isPaymentMethodAction(request)) {
        return PaymentsTestGateway.json(const {}, 503);
      }
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(),
        ]),
      );
    });

    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();
    await controller.revoke('pm_1');

    final state = container.read(paymentMethodsControllerProvider);
    expect(state.status, PaymentMethodsStatus.ready);
    expect(state.methods, hasLength(1));
    expect(state.errorMessage, isNotNull);
    expect(state.isRecoverable, isTrue);
    expect(state.busyMethodId, isNull);
  });

  test('a second mutation is ignored while one is in flight', () async {
    var revocations = 0;
    final container = containerWith((request) async {
      if (PaymentsTestGateway.isPaymentMethodAction(request)) {
        revocations++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return PaymentsTestGateway.json(const {});
      }
      return PaymentsTestGateway.json(
        PaymentsTestGateway.paymentMethodsBody([
          PaymentsTestGateway.paymentMethodBody(),
        ]),
      );
    });

    final controller = container.read(
      paymentMethodsControllerProvider.notifier,
    );
    await controller.load();

    await Future.wait([controller.revoke('pm_1'), controller.revoke('pm_1')]);

    expect(revocations, 1);
  });
}
