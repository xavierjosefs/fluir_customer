import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fluir_customer/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:fluir_customer/features/payments/domain/models/payment_customer_identity.dart';
import 'package:fluir_customer/features/payments/presentation/controllers/add_card_controller.dart';
import 'package:fluir_customer/features/payments/presentation/payments_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'payments_test_gateway.dart';

/// Two things must never escape the payments module: the customer's phone
/// number, which the opaque payment identity deliberately does not derive from,
/// and the card itself, which only exists between the form and the vault.
void main() {
  // The number the customer authenticates with in the prototype.
  const phone = '8095551234';
  const phoneWithCountryCode = '18095551234';
  const formattedPhone = '809 555 1234';
  const phoneFragments = [
    phone,
    phoneWithCountryCode,
    formattedPhone,
    '5551234',
  ];

  ProviderContainer authenticatedContainer({
    required List<http.BaseRequest> requests,
  }) {
    final container = ProviderContainer(
      overrides: [
        paymentGatewayClientProvider.overrideWithValue(
          PaymentsTestGateway.client((request) async {
            requests.add(request);
            if (PaymentsTestGateway.isTokenizeCard(request)) {
              return PaymentsTestGateway.json(
                PaymentsTestGateway.paymentMethodBody(last4: '1111'),
              );
            }
            return PaymentsTestGateway.json(
              PaymentsTestGateway.paymentMethodsBody([
                PaymentsTestGateway.paymentMethodBody(last4: '1111'),
              ]),
            );
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Authenticate exactly as the app does before reaching the payments screen.
    container.read(authControllerProvider.notifier).updatePhone(phone);
    return container;
  }

  void fillCard(AddCardController controller) {
    final draft = PaymentsTestGateway.draft();
    controller
      ..updateNumber(draft.number)
      ..updateExpiry(draft.expiry)
      ..updateSecurityCode(draft.securityCode)
      ..updateHolder(draft.holder);
  }

  test('the identity is the opaque demo reference, not the phone', () {
    final requests = <http.BaseRequest>[];
    final container = authenticatedContainer(requests: requests);

    final identity = container.read(paymentCustomerIdentityProvider)!;

    expect(identity.tenantReference, 'fluir-demo-customer-001');
    expect(identity.userId, 'fluir-demo-customer-001');
    expect(identity.isDebugFallback, isTrue);
  });

  test('tenantReference and userId never contain the authenticated phone', () {
    final requests = <http.BaseRequest>[];
    final container = authenticatedContainer(requests: requests);
    // The authenticated phone is really in the session.
    expect(container.read(authControllerProvider).phone, phone);

    final identity = container.read(paymentCustomerIdentityProvider)!;

    for (final fragment in [...phoneFragments, '1234']) {
      expect(identity.tenantReference, isNot(contains(fragment)));
      expect(identity.userId, isNot(contains(fragment)));
      expect(identity.toString(), isNot(contains(fragment)));
    }
  });

  test('no request URL, body or header carries the phone', () async {
    final requests = <http.BaseRequest>[];
    final container = authenticatedContainer(requests: requests);

    // Exercise both the listing and a real card tokenisation.
    await container.read(paymentMethodsControllerProvider.notifier).load();
    fillCard(container.read(addCardControllerProvider.notifier));
    await container.read(addCardControllerProvider.notifier).submit();

    expect(requests, isNotEmpty);
    for (final request in requests) {
      final body = request is http.Request ? request.body : '';
      final serialized = '${request.url}|${request.headers}|$body';
      for (final fragment in phoneFragments) {
        expect(
          serialized,
          isNot(contains(fragment)),
          reason: '${request.url.path} leaked "$fragment"',
        );
      }
      expect(
        serialized,
        contains('fluir-demo-customer-001'),
        reason: 'the opaque identity should be what identifies the caller',
      );
    }
  });

  test('the card only travels in the tokenisation body', () async {
    final requests = <http.BaseRequest>[];
    final container = authenticatedContainer(requests: requests);

    fillCard(container.read(addCardControllerProvider.notifier));
    await container.read(addCardControllerProvider.notifier).submit();

    expect(requests, isNotEmpty);
    for (final request in requests) {
      expect(request.url.toString(), isNot(contains('4111')));
      expect(request.headers.toString(), isNot(contains('4111')));
      if (!PaymentsTestGateway.isTokenizeCard(request)) {
        final body = request is http.Request ? request.body : '';
        expect(body, isNot(contains('4111')));
      }
    }
    // Nothing keeps the typed card once the vault has it.
    final draft = container.read(addCardControllerProvider).draft;
    expect(draft.number, isEmpty);
    expect(draft.securityCode, isEmpty);
  });

  test('nothing printed while paying carries the phone or the card', () async {
    final logs = <String>[];
    final requests = <http.BaseRequest>[];

    await runZoned(
      () async {
        final previousDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message != null) logs.add(message);
        };
        addTearDown(() => debugPrint = previousDebugPrint);

        final container = authenticatedContainer(requests: requests);
        await container.read(paymentMethodsControllerProvider.notifier).load();
        final add = container.read(addCardControllerProvider.notifier);
        fillCard(add);
        // Whatever the app would surface about the attempt is also checked.
        logs.add(container.read(addCardControllerProvider).draft.toString());
        await add.submit();

        final state = container.read(addCardControllerProvider);
        logs
          ..add(state.message ?? '')
          ..add(state.savedMethod?.toString() ?? '')
          ..add(
            container.read(paymentMethodsControllerProvider).errorMessage ?? '',
          );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );

    final printed = logs.join('\n');
    for (final fragment in [...phoneFragments, '4111111111111111', '4111']) {
      expect(printed, isNot(contains(fragment)), reason: fragment);
    }
  });

  test('the identity does not depend on the authenticated session', () {
    final requests = <http.BaseRequest>[];
    final container = authenticatedContainer(requests: requests);
    final before = container.read(paymentCustomerIdentityProvider);

    // Changing the phone must not change the payment identity at all.
    container.read(authControllerProvider.notifier).updatePhone('8299999999');

    expect(container.read(paymentCustomerIdentityProvider), before);
    expect(
      container.read(paymentCustomerIdentityProvider)!.tenantReference,
      PaymentCustomerIdentity.debugFallbackReference,
    );
  });
}
