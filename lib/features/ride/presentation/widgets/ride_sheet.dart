import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/ride_models.dart';
import '../../domain/models/ride_route.dart';
import '../controllers/ride_controller.dart';
import 'ride_tracking_surface.dart';

Iterable<RideOption> get _planningOptions => [
  rideOptions[0],
  rideOptions[2],
  rideOptions[1],
];

class RideSheet extends StatelessWidget {
  const RideSheet({
    required this.state,
    required this.controller,
    required this.onBackToDestination,
    required this.onReturnHome,
    super.key,
  });

  final RideState state;
  final RideController controller;
  final VoidCallback onBackToDestination;
  final VoidCallback onReturnHome;

  bool get _isFocusedPlanning =>
      state.status == RideStatus.calculatingRoute ||
      state.status == RideStatus.planning ||
      state.status == RideStatus.error;

  bool get _isTracking =>
      state.status == RideStatus.searchingVehicle ||
      state.status == RideStatus.vehicleAssigned ||
      state.status == RideStatus.vehicleArriving ||
      state.status == RideStatus.readyToBoard ||
      state.status == RideStatus.inProgress ||
      state.status == RideStatus.completed;

  @override
  Widget build(BuildContext context) {
    if (_isTracking) {
      return RideTrackingSurface(
        state: state,
        controller: controller,
        onCancelRide: onBackToDestination,
        onReturnHome: onReturnHome,
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: _isFocusedPlanning ? 0 : 8,
      borderRadius: _isFocusedPlanning
          ? null
          : const BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      child: SafeArea(
        top: _isFocusedPlanning,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            _isFocusedPlanning ? AppSpacing.lg : AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _content(context),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final route = state.route;
    if (state.status == RideStatus.calculatingRoute) {
      return const _Status(
        title: 'Calculando tu ruta…',
        detail: 'Estamos preparando las opciones para tu viaje.',
        loading: true,
      );
    }
    if (state.status == RideStatus.error) {
      return _PlanningHeader(
        destination: state.destination?.name ?? 'Destino',
        metadata: '',
        onBack: onBackToDestination,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No pudimos calcular la ruta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text('Inténtalo nuevamente o cambia tu destino.'),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: controller.retry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (state.status == RideStatus.planning) {
      return _planning(context, route!);
    }
    if (state.status == RideStatus.searchingVehicle ||
        state.status == RideStatus.vehicleAssigned ||
        state.status == RideStatus.vehicleArriving ||
        state.status == RideStatus.readyToBoard ||
        state.status == RideStatus.inProgress ||
        state.status == RideStatus.completed) {
      return RideTrackingSurface(
        state: state,
        controller: controller,
        onCancelRide: onBackToDestination,
        onReturnHome: onReturnHome,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _planning(BuildContext context, RideRoute route) => _PlanningHeader(
    destination: state.destination!.name,
    metadata:
        '${(route.durationSeconds / 60).ceil()} min • ${(route.distanceMeters / 1000).toStringAsFixed(1)} km',
    onBack: onBackToDestination,
    child: Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        ..._planningOptions.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _VehicleOptionCard(
              option: option,
              price: _fare(route.distanceMeters, option),
              selected: state.option.id == option.id,
              onTap: () => controller.selectOption(option),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _PaymentRow(payment: state.payment, onTap: () => _payment(context)),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: controller.confirm,
            child: const Text('Confirmar viaje'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Puedes cancelar sin costo antes de confirmar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  void _payment(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: paymentMethods
              .map(
                (payment) => ListTile(
                  leading: const _PaymentBadge(),
                  title: Text(payment.label),
                  trailing: state.payment.id == payment.id
                      ? const Icon(Icons.check, color: AppColors.brandGreen)
                      : null,
                  onTap: () {
                    controller.selectPayment(payment);
                    Navigator.pop(sheetContext);
                  },
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
  String _fare(double distance, RideOption option) =>
      'RD\$${(85 + distance / 1000 * 42 + option.multiplier * 20).round()}';
}

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({
    required this.destination,
    required this.metadata,
    required this.onBack,
    required this.child,
  });
  final String destination, metadata;
  final VoidCallback onBack;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            tooltip: 'Cambiar destino',
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (metadata.isNotEmpty)
                  Text(
                    metadata,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      child,
    ],
  );
}

class _VehicleOptionCard extends StatelessWidget {
  const _VehicleOptionCard({
    required this.option,
    required this.price,
    required this.selected,
    required this.onTap,
  });
  final RideOption option;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final displayName = switch (option.id) {
      'standard' => 'FLUIR',
      'comfort' => 'FLUIR Comfort',
      _ => 'FLUIR XL',
    };
    return Semantics(
      selected: selected,
      button: true,
      label:
          '$displayName, ${option.passengerCapacity} pasajeros, llega en ${option.pickupMinutes} min, $price',
      child: InkWell(
        key: Key('ride-option-${option.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 126,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandGreen.withValues(alpha: .12)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: selected
                  ? AppColors.brandGreen
                  : Theme.of(context).colorScheme.outline,
              width: selected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A111827),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _VehicleImage(optionId: option.id),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${option.passengerCapacity} pasajeros',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Llega en ${option.pickupMinutes} min',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 19,
                    color: selected
                        ? AppColors.brandGreen
                        : Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.optionId});
  final String optionId;
  @override
  Widget build(BuildContext context) {
    final assetPath = switch (optionId) {
      'standard' => 'assets/images/vehicles/fluir_standard.png',
      'xl' => 'assets/images/vehicles/fluir_xl.png',
      _ => 'assets/images/vehicles/fluir_comfort.png',
    };
    return SizedBox(
      width: 132,
      height: 94,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        semanticLabel:
            'Vehículo autónomo ${optionId == 'standard' ? 'FLUIR' : optionId}',
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});
  final PaymentMethod payment;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Método de pago ${payment.label}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            _PaymentBadge(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                payment.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF173F8A),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Text(
      'VISA',
      style: TextStyle(
        color: Colors.white,
        fontSize: 7,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({
    required this.title,
    required this.detail,
    this.loading = false,
  });
  final String title, detail;
  final bool loading;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (loading) const LinearProgressIndicator(),
      if (loading) const SizedBox(height: 16),
      Text(
        title,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(detail),
    ],
  );
}
