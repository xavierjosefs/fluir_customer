import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_environment.dart';
import '../../domain/models/home_coordinate.dart';
import '../../domain/models/nearby_vehicle.dart';
import 'home_marker_images.dart';

typedef HomeMapSurfaceBuilder = Widget Function(BuildContext context);

class FluirMap extends StatefulWidget {
  const FluirMap({
    required this.camera,
    required this.pickup,
    required this.vehicles,
    this.surfaceBuilder,
    super.key,
  });

  final HomeCoordinate camera;
  final HomeCoordinate pickup;
  final List<NearbyVehicle> vehicles;
  final HomeMapSurfaceBuilder? surfaceBuilder;

  @override
  State<FluirMap> createState() => _FluirMapState();
}

class _FluirMapState extends State<FluirMap> {
  MapboxMap? _mapboxMap;
  bool _isLoading = true;
  bool _hasError = false;
  bool _markersAdded = false;
  int _retryAttempt = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.surfaceBuilder != null) {
      return widget.surfaceBuilder!(context);
    }
    if (!AppEnvironment.isMapboxConfigured) {
      return const _MapConfigurationFallback();
    }
    if (_hasError) {
      return _MapErrorSurface(onRetry: _retry);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        MapWidget(
          key: ValueKey('mapbox-map-$_retryAttempt'),
          styleUri: MapboxStyles.LIGHT,
          viewport: CameraViewportState(
            center: _point(widget.camera),
            zoom: 14.8,
            pitch: 0,
            bearing: 0,
          ),
          onMapCreated: (mapboxMap) => _mapboxMap = mapboxMap,
          onStyleLoadedListener: (_) => _addMarkers(),
          onMapLoadedListener: (_) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onMapLoadErrorListener: (_) {
            if (mounted) {
              setState(() => _hasError = true);
            }
          },
        ),
        if (_isLoading)
          const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xEFFFFFFF),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addMarkers() async {
    if (_markersAdded || _mapboxMap == null) {
      return;
    }
    _markersAdded = true;
    try {
      final mapboxMap = _mapboxMap!;
      await Future.wait([
        mapboxMap.logo.updateSettings(
          LogoSettings(
            position: OrnamentPosition.BOTTOM_LEFT,
            marginLeft: 12,
            marginBottom: 304,
          ),
        ),
        mapboxMap.attribution.updateSettings(
          AttributionSettings(
            position: OrnamentPosition.BOTTOM_LEFT,
            marginLeft: 80,
            marginBottom: 304,
          ),
        ),
      ]);
      final images = await Future.wait<Uint8List>([
        HomeMarkerImages.pickup(),
        HomeMarkerImages.vehicle(),
      ]);
      final pickupManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      await pickupManager.create(
        PointAnnotationOptions(
          geometry: _point(widget.pickup),
          image: images.first,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
      final vehicleManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      await vehicleManager.createMulti(
        widget.vehicles
            .map(
              (vehicle) => PointAnnotationOptions(
                geometry: _point(vehicle.position),
                image: images.last,
                iconRotate: vehicle.heading,
                iconAnchor: IconAnchor.CENTER,
              ),
            )
            .toList(),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _isLoading = true;
      _markersAdded = false;
      _mapboxMap = null;
      _retryAttempt++;
    });
  }

  Point _point(HomeCoordinate coordinate) =>
      Point(coordinates: Position(coordinate.longitude, coordinate.latitude));
}

class _MapConfigurationFallback extends StatelessWidget {
  const _MapConfigurationFallback();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Mapa no configurado. Agrega ACCESS_TOKEN para cargar Mapbox.',
    child: CustomPaint(
      painter: _MapFallbackPainter(),
      child: const Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xEFFFFFFF),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, color: AppColors.brandBlue, size: 32),
                SizedBox(height: 8),
                Text('Mapa no configurado'),
                SizedBox(height: 4),
                Text(
                  'Agrega ACCESS_TOKEN para cargar Mapbox.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _MapErrorSurface extends StatelessWidget {
  const _MapErrorSurface({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF3F6F8),
    child: Center(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, color: AppColors.error, size: 32),
              const SizedBox(height: 8),
              const Text('Mapa no disponible'),
              const SizedBox(height: 4),
              const Text('No pudimos cargar el mapa.'),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MapFallbackPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawColor(const Color(0xFFF3F6F8), BlendMode.srcOver);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final detail = Paint()
      ..color = const Color(0xFFDDE5EA)
      ..strokeWidth = 1.5;
    for (var offset = -size.height; offset < size.width; offset += 74) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height, size.height),
        road,
      );
    }
    for (var offset = 0.0; offset < size.height; offset += 80) {
      canvas.drawLine(
        Offset(0, offset),
        Offset(size.width, offset + 28),
        detail,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapFallbackPainter oldDelegate) => false;
}
