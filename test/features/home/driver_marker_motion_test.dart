import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/home/presentation/widgets/driver_marker_motion.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = HomeCoordinate(latitude: 18.4900, longitude: -69.9300);
const _b = HomeCoordinate(latitude: 18.4910, longitude: -69.9300);

void main() {
  group('marker motion', () {
    test('glides between nearby fixes, eased and within bounds', () {
      expect(DriverMarkerMotion.shouldAnimate(_a, _b), isTrue);
      expect(DriverMarkerMotion.lerp(_a, _b, 0), _a);
      expect(DriverMarkerMotion.lerp(_a, _b, 1), _b);
      final middle = DriverMarkerMotion.lerp(_a, _b, .5);
      expect(middle.latitude, greaterThan(18.4905)); // ease-out
      expect(middle.latitude, lessThan(18.4910));
      expect(DriverMarkerMotion.lerp(_a, _b, 3), _b);
    });

    test('never animates across the city or for a standstill', () {
      const far = HomeCoordinate(latitude: 18.53, longitude: -69.93);
      expect(DriverMarkerMotion.distanceMeters(_a, far), greaterThan(2000));
      expect(DriverMarkerMotion.shouldAnimate(_a, far), isFalse);
      expect(DriverMarkerMotion.shouldAnimate(_a, _a), isFalse);
    });

    test('the glide follows the time between fixes, clamped', () {
      expect(
        DriverMarkerMotion.durationFor(const Duration(milliseconds: 50)),
        DriverMarkerMotion.minDuration,
      );
      expect(
        DriverMarkerMotion.durationFor(const Duration(seconds: 1)),
        const Duration(seconds: 1),
      );
      expect(
        DriverMarkerMotion.durationFor(const Duration(seconds: 10)),
        DriverMarkerMotion.maxDuration,
      );
    });

    test('distances are in metres', () {
      // 0.001° of latitude is ~111 m.
      expect(DriverMarkerMotion.distanceMeters(_a, _b), closeTo(111, 1));
    });
  });

  group('camera follow', () {
    const southWest = HomeCoordinate(latitude: 18.48, longitude: -69.94);
    const northEast = HomeCoordinate(latitude: 18.50, longitude: -69.92);

    test(
      'a driver in the clear middle of the map does not move the camera',
      () {
        expect(
          DriverMarkerMotion.outsideComfortArea(
            driver: const HomeCoordinate(latitude: 18.4935, longitude: -69.93),
            southWest: southWest,
            northEast: northEast,
          ),
          isFalse,
        );
      },
    );

    test(
      'behind the trip panel, under the top bar or off the sides it does',
      () {
        for (final driver in const [
          HomeCoordinate(latitude: 18.483, longitude: -69.93), // panel
          HomeCoordinate(latitude: 18.499, longitude: -69.93), // top bar
          HomeCoordinate(latitude: 18.493, longitude: -69.9395), // left
          HomeCoordinate(latitude: 18.493, longitude: -69.9205), // right
          HomeCoordinate(latitude: 18.6, longitude: -69.93), // off the map
        ]) {
          expect(
            DriverMarkerMotion.outsideComfortArea(
              driver: driver,
              southWest: southWest,
              northEast: northEast,
            ),
            isTrue,
            reason: '$driver',
          );
        }
      },
    );

    test('follow stops on a gesture and resumes with Centrar', () {
      final controller = FluirMapController();
      addTearDown(controller.dispose);
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.followingDriver, isTrue);
      controller
        ..stopFollowing()
        ..stopFollowing();
      expect(controller.followingDriver, isFalse);
      expect(notifications, 1);

      controller.recenter();
      expect(controller.followingDriver, isTrue);
      expect(controller.recenterRequests, 1);

      controller
        ..stopFollowing()
        ..resetFollowing();
      expect(controller.followingDriver, isTrue);
      // A new trip follows again without forcing the camera.
      expect(controller.recenterRequests, 1);
    });
  });
}
