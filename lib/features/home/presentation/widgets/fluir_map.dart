import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_environment.dart';
import '../../domain/models/destination_search_result.dart';
import '../../domain/models/home_coordinate.dart';
import '../../domain/models/nearby_vehicle.dart';
import '../../../ride/domain/models/ride_route.dart';
import 'home_map_lifecycle_callbacks.dart';
import 'home_marker_images.dart';

typedef HomeMapSurfaceBuilder = Widget Function(
  BuildContext context,
  HomeMapLifecycleCallbacks lifecycle,
);

String mapStyleUriFor(Brightness brightness) =>
    brightness == Brightness.dark ? MapboxStyles.DARK : MapboxStyles.LIGHT;

class FluirMap extends StatefulWidget {
  const FluirMap({
    required this.camera,
    required this.pickup,
    required this.vehicles,
    required this.lifecycle,
    this.destination,
    this.route,
    this.surfaceBuilder,
    super.key,
  });

  final HomeCoordinate camera;
  final HomeCoordinate pickup;
  final List<NearbyVehicle> vehicles;
  final DestinationSearchResult? destination;
  final RideRoute? route;
  final HomeMapLifecycleCallbacks lifecycle;
  final HomeMapSurfaceBuilder? surfaceBuilder;

  @override
  State<FluirMap> createState() => _FluirMapState();
}

class _FluirMapState extends State<FluirMap> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pickupManager;
  PointAnnotationManager? _vehicleManager;
  PointAnnotationManager? _destinationManager;
  Uint8List? _destinationImage;
  Uint8List? _pickupImage;
  Uint8List? _vehicleImage;
  bool _isLoading = true;
  bool _hasError = false;
  bool _markersAdded = false;
  bool _styleLoaded = false;
  bool _hasLoadedStyle = false;
  String? _appliedStyleUri;
  String? _desiredStyleUri;
  String? _queuedStyleUri;
  bool _styleSyncInFlight = false;
  bool _mapLoaded = false;
  bool _baseAnnotationsReady = false;
  bool _mapRenderedReported = false;
  bool _failureReported = false;
  int _renderedFrameSequence = 0;
  int? _annotationsReadyFrameSequence;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestMapStyle(mapStyleUriFor(Theme.of(context).brightness));
  }

  @override
  void didUpdateWidget(covariant FluirMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.camera != widget.camera ||
            oldWidget.pickup != widget.pickup) &&
        _styleLoaded) {
      unawaited(_updateCurrentLocation());
    }
    if (oldWidget.destination != widget.destination && _styleLoaded) {
      _showSelectedDestination(widget.destination);
    }
    if (oldWidget.route != widget.route && _styleLoaded) {
      _showRoute(widget.route);
    }
  }

  void _requestMapStyle(String styleUri) {
    _desiredStyleUri = styleUri;
    _debugLog('Desired style: $styleUri.');
    if (_appliedStyleUri == styleUri && !_styleSyncInFlight) return;
    _queuedStyleUri = styleUri;
    if (_styleSyncInFlight) return;
    unawaited(_synchronizeRequestedStyle());
  }

  Future<void> _synchronizeRequestedStyle() async {
    _styleSyncInFlight = true;
    while (true) {
      final styleUri = _queuedStyleUri;
      if (styleUri == null) {
        break;
      }
      _queuedStyleUri = null;
      if (_appliedStyleUri == styleUri) continue;
      final mapboxMap = _mapboxMap;
      if (mapboxMap == null) {
        _queuedStyleUri = styleUri;
        _styleSyncInFlight = false;
        return;
      }
      try {
        _debugLog('Requesting native style load: $styleUri.');
        await mapboxMap.loadStyleURI(styleUri);
        _appliedStyleUri = styleUri;
      } catch (_) {
        _debugLog('Native style load failed.');
        _styleSyncInFlight = false;
        _reportFailure('Inténtalo nuevamente.');
        return;
      }
    }
    _styleSyncInFlight = false;
    if (_queuedStyleUri != null && _mapboxMap != null) {
      unawaited(_synchronizeRequestedStyle());
    }
  }

  Future<void> _updateCurrentLocation() async {
    final mapboxMap = _mapboxMap;
    final pickupManager = _pickupManager;
    if (mapboxMap == null || pickupManager == null) return;
    try {
      await mapboxMap.easeTo(
        CameraOptions(center: _point(widget.camera), zoom: 14.8),
        MapAnimationOptions(duration: 450),
      );
      _pickupImage ??= await HomeMarkerImages.pickup();
      await pickupManager.deleteAll();
      await pickupManager.create(
        PointAnnotationOptions(
          geometry: _point(widget.pickup),
          image: _pickupImage!,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (_) {
      // A location refresh must never block the usable map fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.surfaceBuilder != null) {
      return widget.surfaceBuilder!(context, widget.lifecycle);
    }
    if (!AppEnvironment.isMapboxConfigured) {
      return const _MapConfigurationFallback();
    }
    if (_hasError) {
      return const _MapRuntimeErrorSurface();
    }

    final styleUri = mapStyleUriFor(Theme.of(context).brightness);
    return Stack(
      fit: StackFit.expand,
      children: [
        MapWidget(
          styleUri: styleUri,
          viewport: CameraViewportState(
            center: _point(widget.camera),
            zoom: 14.8,
            pitch: 0,
            bearing: 0,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: (_) => _onStyleLoaded(),
          onMapLoadedListener: (_) => _onMapLoaded(),
          onRenderFrameFinishedListener: (_) => _onRenderFrameFinished(),
          onMapLoadErrorListener: (_) {
            if (!_mapLoaded) {
              _reportFailure('Inténtalo nuevamente.');
            }
          },
        ),
        if (_isLoading)
          const ColoredBox(color: Color(0xFFF3F6F8), child: SizedBox.expand()),
      ],
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    final initialStyleUri = mapStyleUriFor(Theme.of(context).brightness);
    // MapWidget owns the first style request through its styleUri. Treat its
    // first callback as current rather than discarding it as a stale reload.
    _appliedStyleUri ??= initialStyleUri;
    _desiredStyleUri ??= initialStyleUri;
    _debugLog('Map created with initial style: $initialStyleUri.');
    if (_desiredStyleUri != _appliedStyleUri) {
      _requestMapStyle(_desiredStyleUri!);
    }
    widget.lifecycle.onMapCreated();
    try {
      await mapboxMap.setCamera(
        CameraOptions(
          center: _point(widget.camera),
          zoom: 14.8,
          pitch: 0,
          bearing: 0,
        ),
      );
      widget.lifecycle.onCameraInitialized();
      _debugLog('Initial camera ready.');
      if (_styleLoaded) {
        await _restoreStyleDependentMapContent();
      }
    } catch (_) {
      _reportFailure('No pudimos preparar la vista del mapa.');
    }
  }

  Future<void> _onStyleLoaded() async {
    final desiredStyleUri = _desiredStyleUri;
    if (desiredStyleUri != null && desiredStyleUri != _appliedStyleUri) {
      _requestMapStyle(desiredStyleUri);
      return;
    }
    final isStyleReload = _hasLoadedStyle;
    _hasLoadedStyle = true;
    _styleLoaded = true;
    if (isStyleReload) {
      _pickupManager = null;
      _vehicleManager = null;
      _destinationManager = null;
      _markersAdded = false;
      _baseAnnotationsReady = false;
    }
    _debugLog('Style loaded${isStyleReload ? ' and reloading visuals' : ''}.');
    widget.lifecycle.onStyleLoaded();
    await _restoreStyleDependentMapContent();
  }

  void _onMapLoaded() {
    _mapLoaded = true;
    _tryReportCompleteMapFrame();
  }

  void _onRenderFrameFinished() {
    if (_mapRenderedReported) {
      return;
    }
    _renderedFrameSequence++;
    _tryReportCompleteMapFrame();
  }

  void _tryReportCompleteMapFrame() {
    if (_mapRenderedReported ||
        !_mapLoaded ||
        !_baseAnnotationsReady ||
        _annotationsReadyFrameSequence == null ||
        _renderedFrameSequence <= _annotationsReadyFrameSequence!) {
      return;
    }

    _mapRenderedReported = true;
    if (mounted) {
      setState(() => _isLoading = false);
    }
    widget.lifecycle.onMapRendered();
  }

  Future<void> _restoreStyleDependentMapContent() async {
    if (_markersAdded || _mapboxMap == null) {
      return;
    }
    _markersAdded = true;
    final mapboxMap = _mapboxMap!;
    _debugLog('Restoring style-dependent visuals.');

    try {
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
    } catch (_) {
      _debugLog('Map ornaments could not be restored.');
    }

    try {
      final images = await Future.wait<Uint8List>([
        HomeMarkerImages.pickup(),
        HomeMarkerImages.vehicle(),
        HomeMarkerImages.destination(),
      ]);
      _destinationImage = images[2];
      _pickupImage = images[0];
      _vehicleImage = images[1];
    } catch (_) {
      _debugLog('Marker images could not be prepared.');
    }

    try {
      if (_pickupImage == null) {
        throw StateError('Pickup marker image unavailable.');
      }
      _pickupManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      await _pickupManager!.create(
        PointAnnotationOptions(
          geometry: _point(widget.pickup),
          image: _pickupImage!,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    } catch (_) {
      _debugLog('Pickup marker could not be restored.');
    } finally {
      // Decorative overlays must never make the native map unavailable.
      widget.lifecycle.onPickupMarkerReady();
    }

    try {
      if (_vehicleImage == null) {
        throw StateError('Vehicle marker image unavailable.');
      }
      _vehicleManager = await mapboxMap.annotations
          .createPointAnnotationManager();
      await _vehicleManager!.createMulti(
        widget.vehicles
            .map(
              (vehicle) => PointAnnotationOptions(
                geometry: _point(vehicle.position),
                image: _vehicleImage!,
                iconRotate: vehicle.heading,
                iconAnchor: IconAnchor.CENTER,
              ),
            )
            .toList(growable: false),
      );
    } catch (_) {
      _debugLog('Vehicle markers could not be restored.');
    } finally {
      widget.lifecycle.onVehicleMarkersReady();
    }

    try {
      if (widget.destination != null) {
        await _showSelectedDestination(widget.destination, animate: false);
      }
      if (widget.route != null) {
        await _showRoute(widget.route, fitCamera: false);
      }
    } catch (_) {
      _debugLog('Optional destination or route visual could not be restored.');
    }
    _baseAnnotationsReady = true;
    _annotationsReadyFrameSequence = _renderedFrameSequence;
    _tryReportCompleteMapFrame();
    _debugLog('Style-dependent visual restoration completed.');
  }

  static const _routeSourceId = 'fluir-ride-route-source';
  static const _routeLayerId = 'fluir-ride-route-layer';

  Future<void> _showRoute(RideRoute? route, {bool fitCamera = true}) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || !_styleLoaded) return;
    final style = mapboxMap.style;
    try {
      await style.removeStyleLayer(_routeLayerId);
      await style.removeStyleSource(_routeSourceId);
    } catch (_) {
      // The first route has no prior style objects to remove.
    }
    if (route == null) return;
    try {
      final geoJson =
          '{"type":"Feature","geometry":{"type":"LineString","coordinates":[${route.coordinates.map((point) => '[${point.longitude},${point.latitude}]').join(',')}]},"properties":{}}';
      await style.addSource(GeoJsonSource(id: _routeSourceId, data: geoJson));
      await style.addLayer(
        LineLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          lineColor: AppColors.brandBlue.toARGB32(),
          lineWidth: 5,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );
      if (!fitCamera) return;
      final options = await mapboxMap.cameraForCoordinatesPadding(
        route.coordinates.map(_point).toList(growable: false),
        CameraOptions(pitch: 0, bearing: 0),
        MbxEdgeInsets(top: 150, left: 36, bottom: 310, right: 36),
        16,
        null,
      );
      await mapboxMap.easeTo(options, MapAnimationOptions(duration: 600));
    } catch (_) {
      // The planning sheet can still communicate a valid route if map styling
      // is temporarily unavailable after initial readiness.
    }
  }

  Future<void> _showSelectedDestination(
    DestinationSearchResult? destination, {
    bool animate = true,
  }) async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null || !_styleLoaded) {
      return;
    }

    try {
      _destinationManager ??= await mapboxMap.annotations
          .createPointAnnotationManager();
      await _destinationManager!.deleteAll();

      if (destination == null) {
        return;
      }

      _destinationImage ??= await HomeMarkerImages.destination();
      await _destinationManager!.create(
        PointAnnotationOptions(
          geometry: _point(destination.coordinate),
          image: _destinationImage,
          iconAnchor: IconAnchor.CENTER,
        ),
      );

      if (animate) {
        await mapboxMap.easeTo(
          CameraOptions(
            center: _point(destination.coordinate),
            zoom: _destinationZoom(destination.featureType),
            pitch: 0,
            bearing: 0,
          ),
          MapAnimationOptions(duration: 550, startDelay: 0),
        );
      }
    } catch (_) {
      // Destination feedback remains represented in Home state even if a
      // non-critical marker/camera update fails after initial map readiness.
    }
  }

  double _destinationZoom(String featureType) {
    if (featureType == 'country' || featureType == 'region') {
      return 10.5;
    }
    if (featureType == 'district' || featureType == 'place') {
      return 13.5;
    }
    if (featureType == 'locality' || featureType == 'neighborhood') {
      return 15.0;
    }
    return 15.7;
  }

  void _reportFailure(String message) {
    if (_failureReported) {
      return;
    }
    _failureReported = true;
    _debugLog('Map initialization failed.');
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
    widget.lifecycle.onFailure(message);
  }

  Point _point(HomeCoordinate coordinate) =>
      Point(coordinates: Position(coordinate.longitude, coordinate.latitude));

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[FluirMap] $message');
    }
  }
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

class _MapRuntimeErrorSurface extends StatelessWidget {
  const _MapRuntimeErrorSurface();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFFF3F6F8), child: SizedBox.expand());
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
