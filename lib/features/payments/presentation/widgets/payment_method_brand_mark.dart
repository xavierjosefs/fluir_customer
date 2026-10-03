import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../domain/models/card_brand.dart';
import '../../domain/models/payment_method.dart';

/// Neutral card mark. Fluir does not ship third-party card logos, so the brand
/// is communicated with type and colour inside the Fluir card shape.
class PaymentMethodBrandMark extends StatelessWidget {
  const PaymentMethodBrandMark({required this.brand, this.size = 1, super.key});

  PaymentMethodBrandMark.forMethod(PaymentMethod method, {super.key})
    : brand = method.brandKind,
      size = 1;

  final CardBrand brand;

  /// Multiplier applied to the mark, for the places that need it compact.
  final double size;

  static String shortLabel(String displayBrand) =>
      CardBrand.fromCode(displayBrand).shortLabel;

  /// A recognisable accent per network, without reproducing its logo.
  static Color inkFor(CardBrand brand) => switch (brand) {
    CardBrand.visa => const Color(0xFF1A1F71),
    CardBrand.mastercard => const Color(0xFFB4470F),
    CardBrand.amex => const Color(0xFF0F5FA6),
    CardBrand.discover => const Color(0xFF8A4B08),
    CardBrand.diners => const Color(0xFF13497B),
    CardBrand.unknown => AppColors.brandBlue,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = Theme.of(context).brightness == Brightness.dark
        ? Color.alphaBlend(inkFor(brand).withValues(alpha: .45), Colors.white)
        : inkFor(brand);
    return Container(
      width: 52 * size,
      height: 36 * size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .10),
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(AppRadius.small * .75),
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            brand.shortLabel,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
        ),
      ),
    );
  }
}
