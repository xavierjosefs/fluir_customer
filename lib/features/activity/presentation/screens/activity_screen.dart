import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/ride_history_item.dart';
import '../activity_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(completedRideHistoryProvider);
    return SafeArea(
      bottom: false,
      child: rides.isEmpty
          ? const _ActivityEmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                116,
              ),
              children: [
                Text(
                  'Actividad',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Tu historial de viajes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final ride in rides) ...[
                  _RideHistoryCard(
                    ride: ride,
                    onTap: () => _showRideDetail(context, ride),
                  ),
                  if (ride != rides.last) const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }

  void _showRideDetail(BuildContext context, RideHistoryItem ride) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RideDetailSheet(
        ride: ride,
        onClose: () => Navigator.pop(sheetContext),
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  const _RideHistoryCard({required this.ride, required this.onTap});
  final RideHistoryItem ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        'Viaje a ${ride.destination}, completado, ${_dateLabel(ride.completedAt)}, ${ride.totalPesos} pesos dominicanos',
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: InkWell(
        key: ValueKey('activity-ride-${ride.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline
                  .withValues(alpha: .75),
            ),
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
          child: Row(
            children: [
              _ActivityVehicleVisual(ride: ride),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${ride.origin}  →  ${ride.destination}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _dateLabel(ride.completedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _fare(ride.totalPesos),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _CompletedBadge(),
                  const SizedBox(height: AppSpacing.xxs),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ActivityVehicleVisual extends StatelessWidget {
  const _ActivityVehicleVisual({required this.ride});
  final RideHistoryItem ride;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      key: ValueKey('activity-vehicle-${ride.id}'),
      width: 64,
      height: 52,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Image.asset(
        _vehicleAssetFor(ride.serviceName),
        fit: BoxFit.contain,
      ),
    ),
  );
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.brandGreen.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: const Text(
      'Completado',
      style: TextStyle(color: Color(0xFF167C53), fontWeight: FontWeight.w700),
    ),
  );
}

class _RideDetailSheet extends StatelessWidget {
  const _RideDetailSheet({required this.ride, required this.onClose});
  final RideHistoryItem ride;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .9;
    return Semantics(
      namesRoute: true,
      label: 'Detalle del viaje a ${ride.destination}',
      child: SizedBox(
        height: maxHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.large),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(child: _SheetHandle()),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          ride.destination,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Viaje completado',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _DetailTotal(totalPesos: ride.totalPesos),
                        const SizedBox(height: AppSpacing.lg),
                        const _DetailSectionTitle('Ruta'),
                        const SizedBox(height: AppSpacing.sm),
                        _RouteSummaryCard(ride: ride),
                        const SizedBox(height: AppSpacing.lg),
                        const _DetailSectionTitle('Resumen'),
                        const SizedBox(height: AppSpacing.sm),
                        _QuickMetrics(ride: ride),
                        const SizedBox(height: AppSpacing.lg),
                        const _DetailSectionTitle('Detalles del viaje'),
                        const SizedBox(height: AppSpacing.sm),
                        _DetailInformationCard(ride: ride),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      key: const ValueKey('activity-detail-close'),
                      onPressed: onClose,
                      child: const Text('Cerrar detalle'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.outline,
      borderRadius: BorderRadius.circular(99),
    ),
  );
}

class _DetailTotal extends StatelessWidget {
  const _DetailTotal({required this.totalPesos});
  final int totalPesos;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Total, $totalPesos pesos dominicanos',
    child: ExcludeSemantics(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.brandBlue.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              _fare(totalPesos),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const _CompletedBadge(),
          ],
        ),
      ),
    ),
  );
}

class _RouteSummaryCard extends StatelessWidget {
  const _RouteSummaryCard({required this.ride});
  final RideHistoryItem ride;

  @override
  Widget build(BuildContext context) => _DetailCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RouteMotif(),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoutePlace(label: 'Origen', name: ride.origin),
              const SizedBox(height: AppSpacing.lg),
              _RoutePlace(label: 'Destino', name: ride.destination),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RouteMotif extends StatelessWidget {
  const _RouteMotif();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 22,
      height: 78,
      child: Column(
        children: [
          const Icon(Icons.circle, color: AppColors.brandBlue, size: 16),
          Expanded(
            child: Container(
              width: 2,
              color: AppColors.brandBlue.withValues(alpha: .5),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brandGreen, width: 3),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoutePlace extends StatelessWidget {
  const _RoutePlace({required this.label, required this.name});
  final String label;
  final String name;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $name',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailInformationCard extends StatelessWidget {
  const _DetailInformationCard({required this.ride});
  final RideHistoryItem ride;

  @override
  Widget build(BuildContext context) => _DetailCard(
    key: const ValueKey('activity-secondary-details'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TripDetailItem(
          key: const ValueKey('activity-detail-vehicle'),
          icon: Icons.directions_car_outlined,
          label: 'Vehículo',
          value: ride.vehicleId,
          subtitle: 'Vehículo autónomo',
        ),
        const Divider(height: AppSpacing.xl),
        _TripDetailItem(
          key: const ValueKey('activity-detail-payment'),
          icon: Icons.credit_card_outlined,
          label: 'Pago',
          value: ride.paymentLabel,
        ),
        const Divider(height: AppSpacing.xl),
        _TripDetailItem(
          key: const ValueKey('activity-detail-date'),
          icon: Icons.calendar_today_outlined,
          label: 'Fecha',
          value: _dateLabel(ride.completedAt),
        ),
      ],
    ),
  );
}

class _QuickMetrics extends StatelessWidget {
  const _QuickMetrics({required this.ride});
  final RideHistoryItem ride;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = [
        _QuickMetricTile(
          key: const ValueKey('activity-metric-distance'),
          icon: Icons.route_outlined,
          label: 'Distancia',
          value: '${ride.distanceKm.toStringAsFixed(1)} km',
        ),
        _QuickMetricTile(
          key: const ValueKey('activity-metric-time'),
          icon: Icons.access_time_outlined,
          label: 'Tiempo',
          value: '${ride.durationMinutes} min',
        ),
      ];
      return Semantics(
        container: true,
        label: 'Resumen del viaje',
        child: Container(
          key: const ValueKey('activity-quick-metrics'),
          child: constraints.maxWidth < 260
              ? Column(
                  children: [
                    metrics.first,
                    const SizedBox(height: AppSpacing.sm),
                    metrics.last,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: metrics.first),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: metrics.last),
                  ],
                ),
        ),
      );
    },
  );
}

class _QuickMetricTile extends StatelessWidget {
  const _QuickMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandBlue.withValues(alpha: .045),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: .75),
        ),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.brandBlue),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _TripDetailItem extends StatelessWidget {
  const _TripDetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Semantics(
    label: subtitle == null ? '$label: $value' : '$label: $value, $subtitle',
    child: ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleMedium);
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: .8),
      ),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      boxShadow: [
        BoxShadow(
          color: AppColors.navy.withValues(alpha: .035),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _ActivityEmptyState extends StatelessWidget {
  const _ActivityEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.route_outlined,
            size: 48,
            color: AppColors.brandBlue,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sin actividad todavía',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tus viajes completados aparecerán aquí.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ),
  );
}

String _vehicleAssetFor(String serviceName) => switch (serviceName) {
  'FLUIR XL' => 'assets/images/vehicles/fluir_xl.png',
  'FLUIR Comfort' => 'assets/images/vehicles/fluir_comfort.png',
  _ => 'assets/images/vehicles/fluir_standard.png',
};

String _fare(int pesos) => 'RD\$$pesos';

String _dateLabel(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final meridiem = date.hour < 12 ? 'a. m.' : 'p. m.';
  return '${date.day} ${months[date.month - 1]} ${date.year} • $hour:$minute $meridiem';
}
