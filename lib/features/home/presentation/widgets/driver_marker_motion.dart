import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/models/home_coordinate.dart';

/// Lets the map follow the driver without re-centring on every update.
class FluirMapController extends ChangeNotifier {
  bool _following = true;
  int _recenterRequests = 0;

  /// Whether the camera keeps the driver in view.
  bool get followingDriver => _following;

  int get recenterRequests => _recenterRequests;

  /// The customer moved the map: stop moving it for them.
  void stopFollowing() {
    if (!_following) return;
    _following = false;
    notifyListeners();
  }

  /// "Centrar" button: follow again and bring the driver back into view.
  void recenter() {
    _following = true;
    _recenterRequests++;
    notifyListeners();
  }

  /// A new trip starts by following again, without moving the camera yet.
  void resetFollowing() {
    if (_following) return;
    _following = true;
    notifyListeners();
  }
}

/// Pure geometry behind the live driver marker, kept apart from Mapbox so it
/// can be tested.
abstract final class DriverMarkerMotion {
  /// Longer jumps (a first fix far away, a GPS glitch) are not animated
  /// across the city: the marker is placed directly.
  static const maxAnimatedMeters = 2000.0;

  static const minDuration = Duration(milliseconds: 300);
  static const maxDuration = Duration(milliseconds: 1500);

  /// Glide for roughly the time between fixes, so the marker keeps moving
  /// instead of stopping and jumping.
  static Duration durationFor(Duration sinceLastFix) {
    if (sinceLastFix < minDuration) return minDuration;
    if (sinceLastFix > maxDuration) return maxDuration;
    return sinceLastFix;
  }

  static bool shouldAnimate(HomeCoordinate from, HomeCoordinate to) {
    final meters = distanceMeters(from, to);
    return meters > .5 && meters <= maxAnimatedMeters;
  }

  /// Ease-out interpolation, `t` in 0…1.
  static HomeCoordinate lerp(HomeCoordinate from, HomeCoordinate to, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - clamped, 3).toDouble();
    return HomeCoordinate(
      latitude: from.latitude + (to.latitude - from.latitude) * eased,
      longitude: from.longitude + (to.longitude - from.longitude) * eased,
    );
  }

  static double distanceMeters(HomeCoordinate a, HomeCoordinate b) {
    const earthRadius = 6371000.0;
    double radians(double degrees) => degrees * math.pi / 180;
    final dLat = radians(b.latitude - a.latitude);
    final dLon = radians(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(a.latitude)) *
            math.cos(radians(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  /// Whether [driver] left the part of the visible map that is not covered
  /// by the top controls (top 22 %) or the trip panel (bottom 45 %).
  static bool outsideComfortArea({
    required HomeCoordinate driver,
    required HomeCoordinate southWest,
    required HomeCoordinate northEast,
  }) {
    final latSpan = northEast.latitude - southWest.latitude;
    final lonSpan = northEast.longitude - southWest.longitude;
    if (latSpan <= 0 || lonSpan <= 0) return true;
    final top = northEast.latitude - latSpan * .22;
    final bottom = southWest.latitude + latSpan * .45;
    final left = southWest.longitude + lonSpan * .12;
    final right = northEast.longitude - lonSpan * .12;
    return driver.latitude > top ||
        driver.latitude < bottom ||
        driver.longitude < left ||
        driver.longitude > right;
  }
}
