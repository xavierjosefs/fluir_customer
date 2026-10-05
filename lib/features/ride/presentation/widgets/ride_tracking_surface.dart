import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/ride_models.dart';
import '../../domain/models/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../controllers/ride_controller.dart';
import 'ride_receipt.dart';

class RideTrackingSurface extends StatefulWidget {
  const RideTrackingSurface({
    required this.state,
    required this.controller,
    required this.onCancelRide,
    required this.onReturnHome,
    this.syncStatus,
    super.key,
  });

  final RideState state;
  final RideController controller;
  final VoidCallback onCancelRide;
  final VoidCallback onReturnHome;

  /// How fresh the trip is; `null` for the local simulation and previews.
  final TripSyncStatus? syncStatus;

  @override
  State<RideTrackingSurface> createState() => _RideTrackingSurfaceState();
}

class _RideTrackingSurfaceState extends State<RideTrackingSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _unlocked = false;
  bool _receipt = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  RideState get state => widget.state;
  RideController get controller => widget.controller;
  bool get _human => state.hasHumanDriver;

  @override
  Widget build(BuildContext context) {
    if (_receipt) return _receiptScreen(context);
    final banner = _bannerText();
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.md,
            child: _TopBackButton(onTap: _backAction),
          ),
          if (banner != null)
            Positioned(
              top: AppSpacing.sm + 6,
              left: 72,
              right: 72,
              child: _SyncBanner(text: banner),
            ),
          if (state.status == RideStatus.searchingVehicle) ...[
            Positioned.fill(
              child: _SearchingMapOverlay(controller: _pulseController),
            ),
            Positioned(
              top: AppSpacing.xxl,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Text(
                _searchingTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, .72),
              child: _SearchingCopy(
                title: _searchingTitle,
                detail: _human
                    ? 'Estamos buscando un conductor cerca de ti.'
                    : 'Estamos buscando el mejor vehículo para ti.',
                message: state.message,
                cancelling: state.isCancelling,
                onCancel: _human ? () => _confirmCancellation(context) : null,
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.bottomCenter,
              child: _TrackingPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.message != null &&
                        state.status != RideStatus.cancelled) ...[
                      _InlineMessage(text: state.message!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    _trackingContent(context),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _searchingTitle =>
      _human ? 'Buscando conductor' : 'Buscando vehículo';

  /// Only live backend trips can fall behind; say so instead of freezing.
  String? _bannerText() {
    final trip = state.trip;
    if (!_human || trip == null || trip.isTerminal) return null;
    return switch (widget.syncStatus) {
      TripSyncStatus.reconnecting => 'Reconectando…',
      TripSyncStatus.polling => 'Actualizando sin tiempo real',
      _ => null,
    };
  }

  Widget _trackingContent(BuildContext context) {
    if (_human) {
      switch (state.status) {
        case RideStatus.vehicleAssigned:
          return _DriverStage(
            title: 'Conductor encontrado',
            subtitle: state.trip?.driver?.displayName == null
                ? 'Un conductor aceptó tu viaje.'
                : '${state.trip!.driver!.displayName} aceptó tu viaje.',
            state: state,
            onCancel: () => _confirmCancellation(context),
          );
        case RideStatus.vehicleArriving:
          return _DriverStage(
            title: 'Tu conductor va en camino',
            subtitle: 'Se dirige al punto de recogida.',
            state: state,
            showEta: true,
            onCancel: () => _confirmCancellation(context),
          );
        case RideStatus.readyToBoard:
          return _DriverStage(
            title: 'Tu conductor llegó',
            subtitle: 'Te espera en el punto de recogida.',
            state: state,
            onCancel: () => _confirmCancellation(context),
          );
        default:
          break;
      }
    }
    switch (state.status) {
      case RideStatus.vehicleAssigned:
        return _VehicleStage(
          title: 'Vehículo encontrado',
          subtitle: 'Hemos encontrado una unidad para ti.',
          state: state,
          eta: state.option.pickupMinutes,
          action: 'Ver detalles',
          outlined: true,
          onAction: () => _vehicleDetails(context),
        );
      case RideStatus.vehicleArriving:
        return _VehicleStage(
          title: 'En camino',
          subtitle: 'Tu vehículo va en camino.',
          state: state,
          eta: 2,
          action: 'Compartir viaje',
          outlined: true,
          onAction: () => _shareTrip(context),
        );
      case RideStatus.readyToBoard:
        return _VehicleStage(
          title: 'Ha llegado',
          subtitle: 'Tu vehículo ha llegado.',
          state: state,
          eta: null,
          action: _unlocked ? 'Ya estoy dentro' : 'Desbloquear vehículo',
          onAction: _unlocked ? controller.board : _unlockVehicle,
        );
      case RideStatus.inProgress:
        return _TripProgress(state: state, onHelp: () => _showHelp(context));
      case RideStatus.completed:
        return _CompletedTrip(
          state: state,
          onRate: controller.rate,
          onDone: () => setState(() => _receipt = true),
        );
      case RideStatus.noDriverFound:
        return _OutcomeStage(
          icon: Icons.person_search_outlined,
          title: 'No encontramos conductor',
          subtitle:
              'No hay conductores disponibles en este momento. '
              'Puedes buscar de nuevo.',
          primary: 'Buscar de nuevo',
          busy: state.isSubmitting,
          onPrimary: controller.retrySearch,
          secondary: 'Cancelar solicitud',
          onSecondary: state.isCancelling
              ? null
              : () => _confirmCancellation(context),
        );
      case RideStatus.cancelled:
        final byDriver = state.trip?.canceledBy == 'worker';
        return _OutcomeStage(
          icon: Icons.event_busy_outlined,
          title: byDriver
              ? 'El conductor canceló el viaje'
              : 'El viaje fue cancelado',
          subtitle: byDriver
              ? 'Puedes pedir otro viaje al mismo destino.'
              : 'Este viaje ya no está activo. Puedes pedir otro.',
          primary: 'Pedir otro viaje',
          onPrimary: controller.requestAgain,
          secondary: 'Volver al inicio',
          onSecondary: widget.onReturnHome,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _backAction() {
    switch (state.status) {
      case RideStatus.searchingVehicle ||
          RideStatus.vehicleAssigned ||
          RideStatus.vehicleArriving:
        _confirmCancellation(context);
      case RideStatus.readyToBoard || RideStatus.noDriverFound when _human:
        _confirmCancellation(context);
      case RideStatus.cancelled:
        widget.onReturnHome();
      default:
        break;
    }
  }

  Future<void> _confirmCancellation(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Cancelar viaje?'),
      content: const Text('Puedes seguir esperando o cancelar esta solicitud.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Seguir esperando'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            widget.onCancelRide();
          },
          child: const Text('Cancelar viaje'),
        ),
      ],
    ),
  );

  void _vehicleDetails(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _vehicleLabel(state),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${_displayName(state.option)} · Blanco'),
            Text('${state.option.passengerCapacity} pasajeros'),
            const SizedBox(height: AppSpacing.sm),
            const Text('Vehículo autónomo Fluir'),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  void _shareTrip(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compartir estado del viaje',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Mi vehículo autónomo ${_vehicleLabel(state)} está en camino.',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _unlockVehicle() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Desbloqueando…'),
        duration: Duration(milliseconds: 900),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _unlocked = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Vehículo desbloqueado')));
  }

  void _showHelp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          _human ? 'Ayuda para tu viaje' : 'Ayuda para tu viaje autónomo',
        ),
      ),
    ),
  );

  Widget _receiptScreen(BuildContext context) => RideReceipt(
    state: state,
    onReturnHome: widget.onReturnHome,
    onDownload: () => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recibo guardado para esta sesión.')),
    ),
    onShare: () => _shareReceipt(context),
  );

  void _shareReceipt(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Compartir recibo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Fluir · Viaje completado'),
            const SizedBox(height: AppSpacing.xs),
            Text('Destino: ${state.destination?.name ?? 'Destino'}'),
            Text('Total: ${formatRideFare(state)}'),
            if (_human)
              Text('Conductor: ${_driverName(state.trip?.driver)}')
            else
              Text('Vehículo: ${_vehicleLabel(state)}'),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TopBackButton extends StatelessWidget {
  const _TopBackButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    elevation: 2,
    child: IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      tooltip: 'Opciones del viaje',
    ),
  );
}

/// "Reconectando…": the trip on screen may be a few seconds behind.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Center(
      child: Container(
        key: const ValueKey('ride-sync-banner'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const ValueKey('ride-inline-message'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Text(text),
    ),
  );
}

class _SearchingMapOverlay extends StatelessWidget {
  const _SearchingMapOverlay({required this.controller});
  final AnimationController controller;
  @override
  Widget build(BuildContext context) => Center(
    child: AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final value = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            for (final delay in [0.0, .33, .66])
              _PulseCircle(value: (value + delay) % 1),
            const Icon(
              Icons.location_on,
              color: AppColors.brandGreen,
              size: 48,
            ),
          ],
        );
      },
    ),
  );
}

class _PulseCircle extends StatelessWidget {
  const _PulseCircle({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => Container(
    width: 74 + value * 150,
    height: 74 + value * 150,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.brandGreen.withValues(alpha: .13 * (1 - value)),
      border: Border.all(
        color: AppColors.brandGreen.withValues(alpha: .28 * (1 - value)),
      ),
    ),
  );
}

class _SearchingCopy extends StatelessWidget {
  const _SearchingCopy({
    required this.title,
    required this.detail,
    this.message,
    this.cancelling = false,
    this.onCancel,
  });
  final String title;
  final String detail;
  final String? message;
  final bool cancelling;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) => _TrackingPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 54,
          child: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          _InlineMessage(text: message!),
        ],
        if (onCancel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const ValueKey('ride-cancel-request'),
            onPressed: cancelling ? null : onCancel,
            child: Text(cancelling ? 'Cancelando…' : 'Cancelar solicitud'),
          ),
        ],
      ],
    ),
  );
}

class _TrackingPanel extends StatelessWidget {
  const _TrackingPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppRadius.large),
    ),
    elevation: 8,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: child,
    ),
  );
}

class _VehicleStage extends StatelessWidget {
  const _VehicleStage({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.eta,
    required this.action,
    required this.onAction,
    this.outlined = false,
  });
  final String title, subtitle, action;
  final RideState state;
  final int? eta;
  final VoidCallback onAction;
  final bool outlined;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          _TrackingVehicleImage(optionId: state.option.id),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName(state.option),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _vehicleLabel(state),
                  style: const TextStyle(
                    color: AppColors.brandGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                const Text('Color: Blanco'),
                if (eta != null)
                  Text(
                    'Llega en $eta min',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: outlined
            ? OutlinedButton(onPressed: onAction, child: Text(action))
            : FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                ),
                onPressed: onAction,
                child: Text(action),
              ),
      ),
    ],
  );
}

/// A Fluir Workers driver: who they are, what they drive and where they are.
/// Missing data gets a neutral label, never an invented value.
class _DriverStage extends StatelessWidget {
  const _DriverStage({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.onCancel,
    this.showEta = false,
  });
  final String title, subtitle;
  final RideState state;
  final VoidCallback onCancel;
  final bool showEta;

  @override
  Widget build(BuildContext context) {
    final driver = state.trip?.driver;
    final location = state.trip?.driverLocation;
    final now = DateTime.now();
    final eta = showEta ? _etaMinutes(location, state.trip?.pickup, now) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _DriverAvatar(driver: driver),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _driverName(driver),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (driver?.rating != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: AppColors.brandGreen,
                        ),
                        Text(
                          driver!.rating!.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    driver?.carModel ?? 'Vehículo sin especificar',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    driver?.licensePlate == null
                        ? 'Placa no disponible'
                        : 'Placa ${driver!.licensePlate}',
                    style: const TextStyle(
                      color: AppColors.brandGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (eta != null)
                    Text(
                      'Llega en ~$eta min',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  _LocationFreshness(location: location, now: now),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            key: const ValueKey('ride-cancel-trip'),
            onPressed: state.isCancelling ? null : onCancel,
            child: Text(state.isCancelling ? 'Cancelando…' : 'Cancelar viaje'),
          ),
        ),
      ],
    );
  }

  /// Straight-line distance × 1.3 at 25 km/h: a rough city estimate, only
  /// from a live position.
  static int? _etaMinutes(
    DriverLocation? location,
    TripPlace? pickup,
    DateTime now,
  ) {
    if (location == null || pickup == null || !location.isFreshAt(now)) {
      return null;
    }
    final meters = _distanceMeters(
      location.coordinate.latitude,
      location.coordinate.longitude,
      pickup.coordinate.latitude,
      pickup.coordinate.longitude,
    );
    return math.max(1, (meters * 1.3 / (25000 / 60)).ceil());
  }
}

class _LocationFreshness extends StatelessWidget {
  const _LocationFreshness({required this.location, required this.now});
  final DriverLocation? location;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final at = location?.recordedAt;
    final String text;
    final Color color;
    if (location == null || at == null) {
      text = 'Esperando la ubicación del conductor';
      color = AppColors.textSecondary;
    } else if (location!.isFreshAt(now)) {
      text = 'Ubicación en vivo';
      color = AppColors.brandGreenInk;
    } else {
      final age = now.difference(at);
      text = age.inMinutes >= 1
          ? 'Ubicación sin actualizar (hace ${age.inMinutes} min)'
          : 'Ubicación sin actualizar (hace ${age.inSeconds} s)';
      color = AppColors.warning;
    }
    return Text(
      text,
      key: const ValueKey('ride-driver-location-freshness'),
      style: TextStyle(fontSize: 12, color: color),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.driver});
  final TripDriver? driver;

  @override
  Widget build(BuildContext context) {
    final name = driver?.displayName;
    final initial = name?.characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.brandBlue.withValues(alpha: .12),
      child: initial == null
          ? const Icon(Icons.person_outline, color: AppColors.brandBlue)
          : Text(
              initial,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.brandBlue,
              ),
            ),
    );
    final url = driver?.avatarUrl;
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        semanticLabel: 'Foto del conductor',
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _TrackingVehicleImage extends StatelessWidget {
  const _TrackingVehicleImage({required this.optionId});
  final String optionId;
  @override
  Widget build(BuildContext context) {
    final asset = RideVehicleAssets.forOptionId(optionId);
    return SizedBox(
      width: 136,
      height: 92,
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        semanticLabel: 'Vehículo autónomo',
      ),
    );
  }
}

class _TripProgress extends StatelessWidget {
  const _TripProgress({required this.state, required this.onHelp});
  final RideState state;
  final VoidCallback onHelp;
  @override
  Widget build(BuildContext context) {
    final atDestination = state.atDestination;
    final driver = state.trip?.driver;
    final duration = state.durationSeconds;
    final distance = state.distanceMeters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          atDestination ? 'Llegaste a tu destino' : 'En viaje',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          atDestination
              ? 'Tu conductor está finalizando el viaje.'
              : 'Disfruta tu viaje.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (state.hasHumanDriver) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              _driverName(driver),
              if (driver?.licensePlate != null) 'Placa ${driver!.licensePlate}',
            ].join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Icon(Icons.circle_outlined, color: AppColors.brandGreen),
                Container(width: 2, height: 38, color: AppColors.brandGreen),
                const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inicio',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    state.destination?.name ?? 'Destino',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Text(
                    'Destino',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (duration != null && distance != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              '${(duration / 60).ceil()} min  •  '
              '${(distance / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: onHelp, child: const Text('Ayuda')),
        ),
      ],
    );
  }
}

class _CompletedTrip extends StatelessWidget {
  const _CompletedTrip({
    required this.state,
    required this.onRate,
    required this.onDone,
  });
  final RideState state;
  final ValueChanged<int> onRate;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Viaje finalizado',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          '¡Gracias por viajar con Fluir!',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          formatRideFare(state),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          (state.payment ?? RidePaymentOption.cash).label,
          textAlign: TextAlign.center,
        ),
        // No payment is processed yet: never claim this ride was paid.
        if (!(state.trip?.paymentCompleted ?? false))
          const Text(
            'Pago pendiente',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Califica tu experiencia',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => IconButton(
              onPressed: () => onRate(index + 1),
              icon: Icon(
                index < (state.rating ?? 0) ? Icons.star : Icons.star_border,
                color: AppColors.brandGreen,
              ),
              tooltip: '${index + 1} estrella${index == 0 ? '' : 's'}',
            ),
          ),
        ),
        const TextField(
          decoration: InputDecoration(
            hintText: 'Escribe un comentario (opcional)',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
            ),
            onPressed: onDone,
            child: const Text('Listo'),
          ),
        ),
      ],
    ),
  );
}

/// No driver found, or a trip canceled by someone else: say what happened
/// and offer the next step instead of waiting forever.
class _OutcomeStage extends StatelessWidget {
  const _OutcomeStage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    this.busy = false,
  });
  final IconData icon;
  final String title, subtitle, primary, secondary;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 40, color: AppColors.brandBlue),
      const SizedBox(height: AppSpacing.sm),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.lg),
      SizedBox(
        height: 50,
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.brandGreen),
          onPressed: busy ? null : onPrimary,
          child: busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Text(primary),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      TextButton(onPressed: onSecondary, child: Text(secondary)),
    ],
  );
}

String _displayName(RideOption option) => switch (option.id) {
  'standard' => 'FLUIR',
  'xl' => 'FLUIR XL',
  _ => 'FLUIR Comfort',
};

/// The simulated autonomous unit; there is no invented fallback id.
String _vehicleLabel(RideState state) => state.vehicleId ?? 'Vehículo Fluir';

String _driverName(TripDriver? driver) => driver?.displayName ?? 'Tu conductor';

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * math.pi / 180;
  final dLat = radians(lat2 - lat1);
  final dLon = radians(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(radians(lat1)) *
          math.cos(radians(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(a));
}
