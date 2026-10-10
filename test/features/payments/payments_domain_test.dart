import 'package:fluir_customer/core/utils/card_input_formatters.dart';
import 'package:fluir_customer/core/utils/uuid_v4.dart';
import 'package:fluir_customer/features/payments/domain/models/card_brand.dart';
import 'package:fluir_customer/features/payments/domain/models/card_entry.dart';
import 'package:fluir_customer/features/payments/domain/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payments_test_cards.dart';

void main() {
  group('PaymentMethod', () {
    test('parses only the fields the app is allowed to keep', () {
      final method = PaymentMethod.tryParse({
        ...PaymentsTestCards.methodJson(),
        'dataVaultToken': 'must-not-be-used',
        'pan': '4242424242424242',
      });

      expect(method, isNotNull);
      expect(method!.id, 'pm_1');
      expect(method.displayBrand, 'Visa');
      expect(method.last4, '4242');
      expect(method.expiryMonth, 12);
      expect(method.expiryYear, 2030);
      expect(method.isDefault, isTrue);
      expect(method.isActive, isTrue);
      expect(method.formattedExpiry, '12/30');
      expect(method.maskedLabel, 'Visa •••• 4242');
    });

    test('rejects entries without an id or last four digits', () {
      expect(PaymentMethod.tryParse(const {'brand': 'VISA'}), isNull);
      expect(PaymentMethod.tryParse(const {'paymentMethodId': 'pm_1'}), isNull);
    });

    test('normalizes brand names and flags expired cards', () {
      final mastercard = PaymentMethod.tryParse(
        PaymentsTestCards.methodJson(brand: 'MASTERCARD'),
      );
      expect(mastercard!.displayBrand, 'Mastercard');

      const expired = PaymentMethod(
        id: 'pm_old',
        brand: 'VISA',
        last4: '1881',
        expiryMonth: 1,
        expiryYear: 2020,
        status: 'ACTIVE',
        isDefault: false,
      );
      expect(expired.isExpired, isTrue);
    });

    test('round-trips through the wallet store without card data', () {
      const method = PaymentMethod(
        id: 'pm_1',
        brand: 'VISA',
        last4: '4242',
        expiryMonth: 12,
        expiryYear: 2030,
        status: 'ACTIVE',
        isDefault: true,
        label: 'Ana',
      );

      final restored = PaymentMethod.tryParse(method.toJson());

      expect(restored, method);
      expect(restored!.walletLabel, 'Visa •••• 4242 (Ana)');
      expect(method.toJson().toString(), isNot(contains('4242424242424242')));
    });

    test('never prints anything beyond the masked label', () {
      const method = PaymentMethod(
        id: 'pm_1',
        brand: 'VISA',
        last4: '4242',
        expiryMonth: 12,
        expiryYear: 2030,
        status: 'ACTIVE',
        isDefault: true,
      );
      final printed = method.toString();
      expect(printed, contains('••••4242'));
      expect(printed, isNot(contains('4242424242424242')));
      expect(printed, isNot(contains('dataVault')));
    });
  });

  group('CardBrand', () {
    test('detects the network from the leading digits', () {
      expect(CardBrand.detect('4111'), CardBrand.visa);
      expect(CardBrand.detect('5412'), CardBrand.mastercard);
      expect(CardBrand.detect('2221'), CardBrand.mastercard);
      expect(CardBrand.detect('371449'), CardBrand.amex);
      expect(CardBrand.detect('30569'), CardBrand.diners);
      expect(CardBrand.detect('6011'), CardBrand.discover);
      expect(CardBrand.detect(''), CardBrand.unknown);
      expect(CardBrand.detect('9999'), CardBrand.unknown);
    });

    test('knows how each network is shaped', () {
      expect(CardBrand.amex.numberGroups, const [4, 6, 5]);
      expect(CardBrand.amex.securityCodeLength, 4);
      expect(CardBrand.amex.securityCodeLabel, 'CID');
      expect(CardBrand.visa.securityCodeLength, 3);
      expect(CardBrand.visa.numberLengths, contains(16));
    });
  });

  group('CardEntryDraft', () {
    const validNow = null;

    test('accepts a well-formed card', () {
      final draft = PaymentsTestCards.draft();

      expect(draft.validate(now: DateTime(2026, 1, 1)), isEmpty);
      final entry = draft.toEntry(now: DateTime(2026, 1, 1));
      expect(entry, isNotNull);
      expect(entry!.number, '4111111111111111');
      expect(entry.last4, '1111');
      expect(entry.brand, CardBrand.visa);
    });

    test('rejects a number that fails the Luhn checksum', () {
      final draft = PaymentsTestCards.draft(number: '4111 1111 1111 1112');

      expect(
        draft.validate(now: DateTime(2026, 1, 1))[CardField.number],
        'Revisa el número de tu tarjeta.',
      );
      expect(draft.toEntry(now: DateTime(2026, 1, 1)), isNull);
    });

    test('rejects a number the network does not issue at that length', () {
      // Luhn-valid but only 15 digits, which Visa does not issue.
      final draft = PaymentsTestCards.draft(number: '411111111111116');

      expect(
        draft.validate(now: DateTime(2026, 1, 1))[CardField.number],
        isNotNull,
      );
    });

    test('reports an expired card and an impossible month separately', () {
      expect(
        PaymentsTestCards.draft(expiry: '12/24')
            .validate(now: DateTime(2026, 1, 1))[CardField.expiry],
        'Esta tarjeta ya venció.',
      );
      expect(
        PaymentsTestCards.draft(expiry: '13/30')
            .validate(now: DateTime(2026, 1, 1))[CardField.expiry],
        'El mes debe estar entre 01 y 12.',
      );
      expect(
        PaymentsTestCards.draft(expiry: '1')
            .validate(now: DateTime(2026, 1, 1))[CardField.expiry],
        'Usa el formato MM/AA.',
      );
    });

    test('asks for the security code the brand actually uses', () {
      final visa = PaymentsTestCards.draft(securityCode: '12');
      expect(
        visa.validate(now: DateTime(2026, 1, 1))[CardField.securityCode],
        'El CVV tiene 3 dígitos.',
      );

      final amex = PaymentsTestCards.draft(
        number: '3782 822463 10005',
        securityCode: '123',
      );
      expect(
        amex.validate(now: DateTime(2026, 1, 1))[CardField.securityCode],
        'El CID tiene 4 dígitos.',
      );
    });

    test('requires a cardholder name', () {
      expect(
        PaymentsTestCards.draft(holder: 'A')
            .validate(now: DateTime(2026, 1, 1))[CardField.holder],
        isNotNull,
      );
    });

    test('an empty draft reports every field at once', () {
      const draft = CardEntryDraft();
      final errors = draft.validate(now: validNow ?? DateTime(2026, 1, 1));

      expect(errors.keys, containsAll(CardField.values));
    });

    test('never prints the card it holds', () {
      final draft = PaymentsTestCards.draft();
      final entry = draft.toEntry(now: DateTime(2026, 1, 1))!;

      expect(draft.toString(), isNot(contains('4111')));
      expect(entry.toString(), isNot(contains('4111111111111111')));
      expect(entry.toString(), isNot(contains('123')));
      expect(entry.toString(), contains('••••1111'));
    });
  });

  group('card input formatters', () {
    test('groups the number the way the brand prints it', () {
      expect(
        CardNumberInputFormatter.format('4111111111111111'),
        '4111 1111 1111 1111',
      );
      expect(
        CardNumberInputFormatter.format('378282246310005'),
        '3782 822463 10005',
      );
      expect(CardNumberInputFormatter.format('4111'), '4111');
    });

    test('stops at the longest number the brand issues', () {
      expect(
        CardNumberInputFormatter.format('378282246310005999'),
        '3782 822463 10005',
      );
    });

    test('formats the expiry as MM/AA and pads a single-digit month', () {
      expect(CardExpiryInputFormatter.format('1'), '1');
      expect(CardExpiryInputFormatter.format('3'), '03');
      expect(CardExpiryInputFormatter.format('12'), '12');
      expect(CardExpiryInputFormatter.format('1230'), '12/30');
      expect(CardExpiryInputFormatter.format('123099'), '12/30');
    });
  });

  group('UuidV4', () {
    test('produces distinct version 4 identifiers', () {
      final first = UuidV4.generate();
      final second = UuidV4.generate();

      expect(first, isNot(second));
      expect(first.length, 36);
      expect(first[14], '4');
      expect('89ab'.contains(first[19]), isTrue);
    });
  });
}
