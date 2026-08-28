import 'package:flutter/services.dart';

class DominicanPhoneInputFormatter extends TextInputFormatter {
  const DominicanPhoneInputFormatter();

  static String normalize(String value) => value.replaceAll(RegExp(r'\D'), '');

  static String format(String value) {
    final digits = normalize(value)
        .substring(0, normalize(value).length.clamp(0, 10));
    if (digits.length <= 2) return digits;
    if (digits.length == 3) return '($digits)';
    final area = digits.substring(0, 3);
    if (digits.length <= 6) return '($area) ${digits.substring(3)}';
    return '($area) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsBeforeCursor = normalize(
      newValue.text.substring(
        0,
        newValue.selection.baseOffset.clamp(0, newValue.text.length),
      ),
    ).length;
    final formatted = format(newValue.text);
    var offset = 0;
    var seenDigits = 0;
    while (offset < formatted.length && seenDigits < digitsBeforeCursor) {
      if (RegExp(r'\d').hasMatch(formatted[offset])) seenDigits++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
