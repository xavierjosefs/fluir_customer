import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/backend_environment.dart';
import '../../../core/network/backend_providers.dart';
import '../data/repositories/remote_trip_repository.dart';
import '../data/repositories/simulated_trip_repository.dart';
import '../domain/repositories/trip_repository.dart';

export '../domain/repositories/trip_repository.dart'
    show TripSyncDiagnostics, TripSyncStatus;

/// The trip source, chosen by configuration only (same pattern as
/// `payments_providers.dart`): a configured `FLUIR_API_BASE_URL` selects the
/// backend, otherwise the local autonomous simulation is kept. Neither the
/// ride controller nor the UI knows which one is in use.
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final configuration = ref.watch(backendConfigurationProvider);
  final api = ref.watch(fluirApiClientProvider);
  final TripRepository repository =
      configuration.tripBackendMode == TripBackendMode.remote && api != null
      ? RemoteTripRepository(
          api: api,
          realtime: ref.watch(realtimeClientProvider),
          customerId: () => ref.read(sessionStoreProvider).userId,
        )
      : SimulatedTripRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// How fresh the trip on screen is (banners, debug panel). Mirrors the
/// repository's diagnostics without exposing the repository to widgets.
final tripSyncProvider =
    NotifierProvider<TripSyncNotifier, TripSyncDiagnostics>(
      TripSyncNotifier.new,
    );

class TripSyncNotifier extends Notifier<TripSyncDiagnostics> {
  @override
  TripSyncDiagnostics build() {
    final diagnostics = ref.watch(tripRepositoryProvider).diagnostics;
    void update() {
      if (ref.mounted) state = diagnostics.value;
    }

    diagnostics.addListener(update);
    ref.onDispose(() => diagnostics.removeListener(update));
    return diagnostics.value;
  }
}
