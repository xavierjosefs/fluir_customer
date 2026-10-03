import 'package:flutter/services.dart';

import '../../features/payments/domain/models/card_brand.dart';

/// Groups a card number the way it is printed on the card, following the brand
/// detected from the leading digits (American Express uses 4-6-5).
class CardNumberInputFormatter extends TextInputFormatter {
  const CardNumberInputFormatter();

  static String format(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final brand = CardBrand.detect(digits);
    final trimmed = digits.substring(
      0,
      digits.length.clamp(0, brand.maxNumberLength),
    );
    final buffer = StringBuffer();
    var index = 0;
    for (final group in brand.numberGroups) {
      if (index >= trimmed.length) break;
      if (index > 0) buffer.write(' ');
      final end = (index + group).clamp(0, trimmed.length);
      buffer.write(trimmed.substring(index, end));
      index = end;
    }
    // A 19-digit number outruns the brand's groups; the tail stays readable.
    if (index < trimmed.length) {
      buffer
        ..write(' ')
        ..write(trimmed.substring(index));
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _reflow(newValue, format);
}

/// Formats the expiration as `MM/AA` while it is typed.
class CardExpiryInputFormatter extends TextInputFormatter {
  const CardExpiryInputFormatter();

  static String format(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    // A lone 2…9 can only be a month if it is padded, which is what the card
    // itself shows.
    if (digits.length == 1 && digits.codeUnitAt(0) > 0x31) {
      digits = '0$digits';
    }
    digits = digits.substring(0, digits.length.clamp(0, 4));
    if (digits.length <= 2) return digits;
    return '${digits.substring(0, 2)}/${digits.substring(2)}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => _reflow(newValue, format);
}

/// Re-applies [format] while keeping the caret on the same digit.
TextEditingValue _reflow(
  TextEditingValue value,
  String Function(String) format,
) {
  final digitsBeforeCaret = value.text
      .substring(0, value.selection.baseOffset.clamp(0, value.text.length))
      .replaceAll(RegExp(r'\D'), '')
      .length;
  final formatted = format(value.text);
  var offset = 0;
  var seen = 0;
  while (offset < formatted.length && seen < digitsBeforeCaret) {
    if (formatted.codeUnitAt(offset) >= 0x30 &&
        formatted.codeUnitAt(offset) <= 0x39) {
      seen++;
    }
    offset++;
  }
  return TextEditingValue(
    text: formatted,
    selection: TextSelection.collapsed(offset: offset),
  );
}
