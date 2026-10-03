import 'package:flutter/foundation.dart';

import 'card_brand.dart';

/// The fields of the in-app card form.
enum CardField { number, expiry, securityCode, holder }

/// A card the customer typed but that has not been validated yet.
///
/// Raw card data lives in memory for exactly as long as the form is open. It is
/// never written to disk, never logged and never attached to an error report.
@immutable
class CardEntryDraft {
  const CardEntryDraft({
    this.number = '',
    this.expiry = '',
    this.securityCode = '',
    this.holder = '',
  });

  final String number;
  final String expiry;
  final String securityCode;
  final String holder;

  static String digitsOf(String value) => value.replaceAll(RegExp(r'\D'), '');

  String get numberDigits => digitsOf(number);

  CardBrand get brand => CardBrand.detect(numberDigits);

  CardEntryDraft copyWith({
    String? number,
    String? expiry,
    String? securityCode,
    String? holder,
  }) => CardEntryDraft(
    number: number ?? this.number,
    expiry: expiry ?? this.expiry,
    securityCode: securityCode ?? this.securityCode,
    holder: holder ?? this.holder,
  );

  /// Field-level problems, in the order the customer meets them. An empty map
  /// means [toEntry] will succeed.
  Map<CardField, String> validate({DateTime? now}) {
    final errors = <CardField, String>{};
    final digits = numberDigits;
    if (digits.isEmpty) {
      errors[CardField.number] = 'Ingresa el número de tu tarjeta.';
    } else if (!brand.numberLengths.contains(digits.length) ||
        !passesLuhn(digits)) {
      errors[CardField.number] = 'Revisa el número de tu tarjeta.';
    }

    final expiryDigits = digitsOf(expiry);
    if (expiryDigits.isEmpty) {
      errors[CardField.expiry] = 'Ingresa el vencimiento.';
    } else if (expiryDigits.length < 4) {
      errors[CardField.expiry] = 'Usa el formato MM/AA.';
    } else {
      final month = int.parse(expiryDigits.substring(0, 2));
      final year = 2000 + int.parse(expiryDigits.substring(2, 4));
      if (month < 1 || month > 12) {
        errors[CardField.expiry] = 'El mes debe estar entre 01 y 12.';
      } else if (!_isFuture(month, year, now ?? DateTime.now())) {
        errors[CardField.expiry] = 'Esta tarjeta ya venció.';
      }
    }

    final code = digitsOf(securityCode);
    if (code.isEmpty) {
      errors[CardField.securityCode] = 'Ingresa el ${brand.securityCodeLabel}.';
    } else if (code.length != brand.securityCodeLength) {
      errors[CardField.securityCode] =
          'El ${brand.securityCodeLabel} tiene '
          '${brand.securityCodeLength} dígitos.';
    }

    if (holder.trim().length < 3) {
      errors[CardField.holder] = 'Ingresa el nombre que aparece en la tarjeta.';
    }
    return errors;
  }

  /// The validated card, or `null` when [validate] still reports a problem.
  CardEntry? toEntry({DateTime? now}) {
    if (validate(now: now).isNotEmpty) return null;
    final expiryDigits = digitsOf(expiry);
    return CardEntry(
      number: numberDigits,
      expiryMonth: int.parse(expiryDigits.substring(0, 2)),
      expiryYear: 2000 + int.parse(expiryDigits.substring(2, 4)),
      securityCode: digitsOf(securityCode),
      holderName: holder.trim(),
    );
  }

  static bool _isFuture(int month, int year, DateTime now) =>
      DateTime(year, month + 1).isAfter(DateTime(now.year, now.month, now.day));

  /// The Luhn checksum every card network uses.
  static bool passesLuhn(String digits) {
    if (digits.length < 12) return false;
    var sum = 0;
    var doubling = false;
    for (var index = digits.length - 1; index >= 0; index--) {
      var value = digits.codeUnitAt(index) - 0x30;
      if (value < 0 || value > 9) return false;
      if (doubling) {
        value *= 2;
        if (value > 9) value -= 9;
      }
      sum += value;
      doubling = !doubling;
    }
    return sum % 10 == 0;
  }

  /// Deliberately masked: a draft can reach a log through an error report.
  @override
  String toString() => 'CardEntryDraft(${brand.code}, <redacted>)';
}

/// A card that passed validation and is ready to be tokenised.
///
/// Instances are short-lived on purpose: the PAN and the security code exist
/// only between the form submit and the vault call.
@immutable
class CardEntry {
  const CardEntry({
    required this.number,
    required this.expiryMonth,
    required this.expiryYear,
    required this.securityCode,
    required this.holderName,
  });

  final String number;
  final int expiryMonth;
  final int expiryYear;
  final String securityCode;
  final String holderName;

  CardBrand get brand => CardBrand.detect(number);

  String get last4 => number.substring(number.length - 4);

  /// `YYMM`, the expiration format AZUL expects.
  String get expirationYyMm =>
      '${(expiryYear % 100).toString().padLeft(2, '0')}'
      '${expiryMonth.toString().padLeft(2, '0')}';

  /// Deliberately masked: this value can end up in logs or error reports.
  @override
  String toString() => 'CardEntry(${brand.code} ••••$last4)';
}
