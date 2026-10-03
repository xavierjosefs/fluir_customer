import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/ride_models.dart';
import '../../domain/ride_fare.dart';
import '../controllers/ride_controller.dart';
import 'ride_receipt.dart';

class RideTrackingSurface extends StatefulWidget {
  const RideTrackingSurface({
    required this.state,
    required this.controller,
    required this.onCancelRide,
    required this.onReturnHome,
    super.key,
  });

  final RideState state;
  final RideController controller;
  final VoidCallback onCancelRide;
  final VoidCallback onReturnHome;

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

  @override
  Widget build(BuildContext context) {
    if (_receipt) return _receiptScreen(context);
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.md,
            child: _TopBackButton(onTap: _backAction),
          ),
          if (state.status == RideStatus.searchingVehicle) ...[
            Positioned.fill(
              child: _SearchingMapOverlay(controller: _pulseController),
            ),
            const Positioned(
              top: AppSpacing.xxl,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Text(
                'Buscando vehículo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
            ),
            const Align(alignment: Alignment(0, .72), child: _SearchingCopy()),
          ] else ...[
            Align(
              alignment: Alignment.bottomCenter,
              child: _TrackingPanel(child: _trackingContent(context)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trackingContent(BuildContext context) {
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
      default:
        return const SizedBox.shrink();
    }
  }

  void _backAction() {
    if (state.status == RideStatus.searchingVehicle ||
        state.status == RideStatus.vehicleAssigned ||
        state.status == RideStatus.vehicleArriving) {
      _confirmCancellation(context);
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
              state.vehicleId ?? 'FLUIR-001',
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
              'Mi vehículo autónomo ${state.vehicleId ?? 'FLUIR-001'} está en camino.',
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
    builder: (sheetContext) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text('Ayuda para tu viaje autónomo'),
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
            Text('Destino: ${state.destination!.name}'),
            Text('Total: ${formatRideFare(state)}'),
            Text('Vehículo: ${state.vehicleId ?? 'FLUIR-001'}'),
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
  const _SearchingCopy();
  @override
  Widget build(BuildContext context) => _TrackingPanel(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Buscando vehículo',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Estamos buscando el mejor vehículo para ti.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 54,
          child: LinearProgressIndicator(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
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
                  state.vehicleId ?? 'FLUIR-001',
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'En viaje',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: AppSpacing.xs),
      const Text(
        'Disfruta tu viaje.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
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
                  state.destination!.name,
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
      const SizedBox(height: AppSpacing.lg),
      Center(
        child: Text(
          '${(state.route!.durationSeconds / 60).ceil()} min  •  ${(state.route!.distanceMeters / 1000).toStringAsFixed(1)} km',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(onPressed: onHelp, child: const Text('Ayuda')),
      ),
    ],
  );
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
          _fare(state),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          (state.payment ?? RidePaymentOption.cash).label,
          textAlign: TextAlign.center,
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

String _displayName(RideOption option) => switch (option.id) {
  'standard' => 'FLUIR',
  'xl' => 'FLUIR XL',
  _ => 'FLUIR Comfort',
};
String _fare(RideState state) => RideFare.formatted(
  distanceMeters: state.route!.distanceMeters,
  option: state.option,
);
