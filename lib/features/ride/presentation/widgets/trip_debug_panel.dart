import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/backend_environment.dart';
import '../../../../core/network/backend_providers.dart';
import '../../../authentication/presentation/controllers/customer_session_controller.dart';
import '../controllers/ride_controller.dart';
import '../trip_providers.dart';

/// Debug builds only: a narrow tab on the left edge (it covers no control)
/// that opens [TripDebugSheet].
class TripDebugTab extends StatelessWidget {
  const TripDebugTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: 'Diagnóstico del viaje (solo debug)',
      child: Material(
        color: AppColors.navy.withValues(alpha: .78),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        child: InkWell(
          key: const ValueKey('trip-debug-tab'),
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(8),
          ),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const TripDebugSheet(),
          ),
          child: const SizedBox(
            width: 18,
            height: 56,
            child: RotatedBox(
              quarterTurns: 3,
              child: Center(
                child: Text(
                  'DBG',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What a developer needs to see while running the demo. Never tokens, the
/// verification code, keys, phone numbers or payment data.
class TripDebugSheet extends ConsumerWidget {
  const TripDebugSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configuration = ref.watch(backendConfigurationProvider);
    final session = ref.watch(customerSessionProvider);
    final sync = ref.watch(tripSyncProvider);
    final ride = ref.watch(rideControllerProvider);
    final trip = ride.trip;
    final location = trip?.driverLocation;
    final now = DateTime.now();
    final api = configuration.apiBaseUri;
    final realtime = ref.watch(realtimeClientProvider);

    final rows = <(String, String)>[
      (
        'Entorno',
        configuration.tripBackendMode == TripBackendMode.remote && api != null
            ? 'Backend ${api.host}:${api.port}'
                  '${configuration.demoMode ? ' · demo' : ''}'
            : 'Simulación local',
      ),
      ('Sesión API', session.status.name),
      ('Realtime', sync.status.name),
      ('Customer ID', session.customerId?.toString() ?? '—'),
      (
        'Trip ID',
        trip == null
            ? '—'
            : 'order ${trip.ref.orderId} · taxi ${trip.ref.taxiOrderId}',
      ),
      ('Estado backend', trip?.status ?? '—'),
      ('Versión', trip?.version.toString() ?? '—'),
      (
        'RideState',
        ride.unrecognizedStatus == null
            ? ride.status.name
            : '${ride.status.name} (desconocido: ${ride.unrecognizedStatus})',
      ),
      ('Último evento', _event(sync.lastEvent, sync.lastEventAt)),
      (
        'Reconciliaciones',
        '${sync.reconciliations} · última ${_time(sync.lastReconciledAt)}',
      ),
      ('Duplicados ignorados', '${sync.duplicatesIgnored}'),
      (
        'Ubicación conductor',
        location?.recordedAt == null
            ? '—'
            : '${_time(location!.recordedAt)} · '
                  'hace ${now.difference(location.recordedAt!).inSeconds} s · '
                  '${location.isFreshAt(now) ? 'en vivo' : 'vieja'}',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Diagnóstico del viaje',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Solo en builds debug. Sin tokens, códigos, claves, teléfonos ni '
              'datos de pago.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        value,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: () => ref
                      .read(rideControllerProvider.notifier)
                      .reconcile(restartWatch: true),
                  child: const Text('Reconciliar ahora'),
                ),
                if (realtime != null)
                  OutlinedButton(
                    key: const ValueKey('trip-debug-drop-socket'),
                    onPressed: realtime.simulateConnectionLoss,
                    child: const Text('Simular corte de socket'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _event(String? name, DateTime? at) =>
      name == null ? '—' : '$name · ${_time(at)}';

  static String _time(DateTime? at) {
    if (at == null) return '—';
    final local = at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
