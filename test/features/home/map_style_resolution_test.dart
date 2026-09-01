import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fluir_customer/features/home/presentation/widgets/fluir_map.dart';

void main() {
  test('light brightness always resolves to the light Mapbox style', () {
    expect(mapStyleUriFor(Brightness.light), MapboxStyles.LIGHT);
  });

  test('dark brightness always resolves to the dark Mapbox style', () {
    expect(mapStyleUriFor(Brightness.dark), MapboxStyles.DARK);
  });

  test('a dark to light transition resolves back to the light style', () {
    final styles = [
      mapStyleUriFor(Brightness.dark),
      mapStyleUriFor(Brightness.light),
    ];
    expect(styles.last, MapboxStyles.LIGHT);
  });

  test('a rapid light dark light sequence keeps light as the final style', () {
    final styles = [
      mapStyleUriFor(Brightness.light),
      mapStyleUriFor(Brightness.dark),
      mapStyleUriFor(Brightness.light),
    ];
    expect(styles.last, MapboxStyles.LIGHT);
  });
}
