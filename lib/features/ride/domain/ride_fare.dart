import 'models/ride_models.dart';

/// Deterministic local fare estimate for the prototype.
///
/// One formula for every surface — options, tracking and receipt — so a ride
/// can never be quoted at one price and charged at another. It is mock data
/// until a backend prices rides for real.
abstract final class RideFare {
  static const baseFare = 85.0;
  static const perKilometre = 42.0;
  static const currencySymbol = r'RD$';

  static int pesos({
    required double distanceMeters,
    required RideOption option,
  }) => ((baseFare + distanceMeters / 1000 * perKilometre) * option.multiplier)
      .round();

  static String format(int pesos) => '$currencySymbol$pesos';

  static String formatted({
    required double distanceMeters,
    required RideOption option,
  }) => format(pesos(distanceMeters: distanceMeters, option: option));
}
