import 'card_brand.dart';

/// A card the customer saved through the in-app form.
///
/// Only the fields needed to recognise a card are modelled. PAN, security code,
/// expiration beyond month/year, and the DataVault token never leave the vault
/// and must never reach this class.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expiryMonth,
    required this.expiryYear,
    required this.status,
    required this.isDefault,
    this.label,
  });

  final String id;
  final String brand;
  final String last4;
  final int expiryMonth;
  final int expiryYear;
  final String status;
  final bool isDefault;

  /// Short name the customer gave the card, shown the way a wallet does
  /// ("Visa •••• 4242 (Personal)"). Never the full cardholder name.
  final String? label;

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  CardBrand get brandKind => CardBrand.fromCode(brand);

  /// Display label such as `Visa •••• 4242`.
  String get maskedLabel => '$displayBrand •••• $last4';

  /// [maskedLabel] plus the customer's own name for the card, when there is
  /// one.
  String get walletLabel =>
      label == null || label!.isEmpty ? maskedLabel : '$maskedLabel ($label)';

  String get displayBrand {
    final kind = brandKind;
    if (kind != CardBrand.unknown) return kind.displayName;
    return brand.isEmpty ? CardBrand.unknown.displayName : brand;
  }

  /// `MM/AA`, matching the way the expiry is printed on a card.
  String get formattedExpiry {
    final month = expiryMonth.clamp(1, 12).toString().padLeft(2, '0');
    final year = expiryYear.toString().padLeft(2, '0');
    return '$month/${year.substring(year.length - 2)}';
  }

  bool get isExpired {
    final now = DateTime.now();
    final normalizedYear = expiryYear < 100 ? 2000 + expiryYear : expiryYear;
    final endOfMonth = DateTime(normalizedYear, expiryMonth + 1);
    return !endOfMonth.isAfter(now);
  }

  PaymentMethod copyWith({bool? isDefault, String? status}) => PaymentMethod(
    id: id,
    brand: brand,
    last4: last4,
    expiryMonth: expiryMonth,
    expiryYear: expiryYear,
    status: status ?? this.status,
    isDefault: isDefault ?? this.isDefault,
    label: label,
  );

  static PaymentMethod? tryParse(Map<String, dynamic> json) {
    final id = _asTrimmedString(
      json['paymentMethodId'] ?? json['id'] ?? json['paymentMethodID'],
    );
    final last4 = _asTrimmedString(json['last4'] ?? json['lastFour']);
    if (id == null || last4 == null) {
      return null;
    }
    return PaymentMethod(
      id: id,
      brand: _asTrimmedString(json['brand']) ?? '',
      last4: last4,
      expiryMonth: _asInt(json['expiryMonth']) ?? 0,
      expiryYear: _asInt(json['expiryYear']) ?? 0,
      status: _asTrimmedString(json['status']) ?? 'UNKNOWN',
      isDefault: json['isDefault'] == true,
      label: _asTrimmedString(json['label'] ?? json['nickname']),
    );
  }

  /// Round-trips the fields the simulated vault persists. Deliberately the same
  /// shape [tryParse] accepts, and just as free of card data.
  Map<String, dynamic> toJson() => {
    'paymentMethodId': id,
    'brand': brand,
    'last4': last4,
    'expiryMonth': expiryMonth,
    'expiryYear': expiryYear,
    'status': status,
    'isDefault': isDefault,
    if (label != null) 'label': label,
  };

  static String? _asTrimmedString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  bool operator ==(Object other) =>
      other is PaymentMethod &&
      other.id == id &&
      other.brand == brand &&
      other.last4 == last4 &&
      other.expiryMonth == expiryMonth &&
      other.expiryYear == expiryYear &&
      other.status == status &&
      other.isDefault == isDefault &&
      other.label == label;

  @override
  int get hashCode => Object.hash(
    id,
    brand,
    last4,
    expiryMonth,
    expiryYear,
    status,
    isDefault,
    label,
  );

  /// Deliberately masked: this value can end up in logs or error reports.
  @override
  String toString() => 'PaymentMethod($displayBrand ••••$last4, $status)';
}
