class HomeReadinessState {
  const HomeReadinessState({
    this.mapCreated = false,
    this.styleLoaded = false,
    this.cameraInitialized = false,
    this.mapRendered = false,
    this.pickupMarkerReady = false,
    this.vehicleMarkersReady = false,
    this.homeDataReady = false,
    this.servicesReady = false,
    this.failureMessage,
  });

  final bool mapCreated;
  final bool styleLoaded;
  final bool cameraInitialized;
  final bool mapRendered;
  final bool pickupMarkerReady;
  final bool vehicleMarkersReady;
  final bool homeDataReady;
  final bool servicesReady;
  final String? failureMessage;

  bool get isReady =>
      failureMessage == null &&
      mapCreated &&
      styleLoaded &&
      cameraInitialized &&
      mapRendered &&
      pickupMarkerReady &&
      vehicleMarkersReady &&
      homeDataReady &&
      servicesReady;

  bool get hasFailed => failureMessage != null;

  HomeReadinessState copyWith({
    bool? mapCreated,
    bool? styleLoaded,
    bool? cameraInitialized,
    bool? mapRendered,
    bool? pickupMarkerReady,
    bool? vehicleMarkersReady,
    bool? homeDataReady,
    bool? servicesReady,
    String? failureMessage,
    bool clearFailure = false,
  }) => HomeReadinessState(
    mapCreated: mapCreated ?? this.mapCreated,
    styleLoaded: styleLoaded ?? this.styleLoaded,
    cameraInitialized: cameraInitialized ?? this.cameraInitialized,
    mapRendered: mapRendered ?? this.mapRendered,
    pickupMarkerReady: pickupMarkerReady ?? this.pickupMarkerReady,
    vehicleMarkersReady: vehicleMarkersReady ?? this.vehicleMarkersReady,
    homeDataReady: homeDataReady ?? this.homeDataReady,
    servicesReady: servicesReady ?? this.servicesReady,
    failureMessage: clearFailure ? null : failureMessage ?? this.failureMessage,
  );
}
