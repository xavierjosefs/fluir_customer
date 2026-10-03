/// Card networks the Fluir wallet recognises.
///
/// The brand drives how the number is grouped, how long it may be and how many
/// digits the security code has, so the form can validate a card before any of
/// it is sent anywhere.
enum CardBrand {
  visa('Visa', 'VISA'),
  mastercard('Mastercard', 'MASTERCARD'),
  amex('American Express', 'AMEX'),
  discover('Discover', 'DISCOVER'),
  diners('Diners Club', 'DINERS'),
  unknown('Tarjeta', 'UNKNOWN');

  const CardBrand(this.displayName, this.code);

  final String displayName;

  /// Vocabulary the gateway uses for this network.
  final String code;

  /// Digit groups the number is displayed in.
  List<int> get numberGroups =>
      this == CardBrand.amex ? const [4, 6, 5] : const [4, 4, 4, 4];

  /// Lengths the network actually issues.
  Set<int> get numberLengths => switch (this) {
    CardBrand.visa => const {13, 16, 19},
    CardBrand.mastercard => const {16},
    CardBrand.amex => const {15},
    CardBrand.discover => const {16, 19},
    CardBrand.diners => const {14, 16, 19},
    CardBrand.unknown => const {12, 13, 14, 15, 16, 17, 18, 19},
  };

  int get maxNumberLength => numberLengths.reduce((a, b) => a > b ? a : b);

  int get securityCodeLength => this == CardBrand.amex ? 4 : 3;

  String get securityCodeLabel => this == CardBrand.amex ? 'CID' : 'CVV';

  /// Compact mark used where a full brand name does not fit.
  String get shortLabel => switch (this) {
    CardBrand.mastercard => 'MC',
    CardBrand.amex => 'AMEX',
    CardBrand.diners => 'DINERS',
    CardBrand.unknown => 'CARD',
    _ => displayName.toUpperCase(),
  };

  /// Recognises the network from the leading digits of a partial number.
  static CardBrand detect(String digits) {
    if (digits.isEmpty) return CardBrand.unknown;
    if (digits.startsWith('4')) return CardBrand.visa;
    if (RegExp(r'^3[47]').hasMatch(digits)) return CardBrand.amex;
    if (RegExp(r'^3(0[0-5]|[689])').hasMatch(digits)) return CardBrand.diners;
    if (RegExp(r'^5[1-5]').hasMatch(digits)) return CardBrand.mastercard;
    if (RegExp(r'^2(2[2-9]|[3-6]\d|7[01]|720)').hasMatch(digits)) {
      return CardBrand.mastercard;
    }
    if (RegExp(r'^6(011|5|4[4-9])').hasMatch(digits)) return CardBrand.discover;
    return CardBrand.unknown;
  }

  /// Maps whatever the gateway reports back onto a known network.
  static CardBrand fromCode(String raw) {
    final normalized = raw.toUpperCase().replaceAll(RegExp(r'[\s_-]'), '');
    return switch (normalized) {
      'VISA' => CardBrand.visa,
      'MASTERCARD' || 'MC' => CardBrand.mastercard,
      'AMEX' || 'AMERICANEXPRESS' => CardBrand.amex,
      'DISCOVER' => CardBrand.discover,
      'DINERS' || 'DINERSCLUB' => CardBrand.diners,
      _ => CardBrand.unknown,
    };
  }
}
