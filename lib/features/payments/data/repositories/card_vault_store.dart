import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/payment_method.dart';

/// Where the simulated vault keeps the cards it has issued a token for.
///
/// Only the fields the customer needs in order to recognise a card are stored:
/// brand, last four digits, expiry month/year and the label. A PAN or a
/// security code never reaches this layer.
abstract interface class CardVaultStore {
  Future<List<PaymentMethod>> read();

  Future<void> write(List<PaymentMethod> methods);
}

class SharedPreferencesCardVaultStore implements CardVaultStore {
  const SharedPreferencesCardVaultStore(this._preferences);

  static const storageKey = 'fluir.payments.simulated_wallet.v1';

  final SharedPreferences _preferences;

  @override
  Future<List<PaymentMethod>> read() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // A wallet we cannot read is treated as empty rather than crashing the
      // screen; the customer can simply add the card again.
      return const [];
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(PaymentMethod.tryParse)
        .whereType<PaymentMethod>()
        .toList(growable: false);
  }

  @override
  Future<void> write(List<PaymentMethod> methods) => _preferences.setString(
    storageKey,
    jsonEncode(methods.map((method) => method.toJson()).toList()),
  );
}

/// Keeps the wallet for the lifetime of the process. Used by tests and as the
/// fallback when platform storage is unavailable.
class InMemoryCardVaultStore implements CardVaultStore {
  InMemoryCardVaultStore([List<PaymentMethod> initial = const []])
    : _methods = List.of(initial);

  List<PaymentMethod> _methods;

  @override
  Future<List<PaymentMethod>> read() async => List.unmodifiable(_methods);

  @override
  Future<void> write(List<PaymentMethod> methods) async {
    _methods = List.of(methods);
  }
}
