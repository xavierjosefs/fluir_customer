import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../home/data/mock/mock_home_map_data.dart';
import '../../domain/models/ride_models.dart';
import '../controllers/ride_controller.dart';

class RideReceipt extends StatelessWidget {
  const RideReceipt({
    required this.state,
    required this.onReturnHome,
    required this.onDownload,
    required this.onShare,
    super.key,
  });

  final RideState state;
  final VoidCallback onReturnHome;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final total = formatRideFare(state);
    return SafeArea(
      child: Material(
        color: Colors.white,
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReceiptHeader(
                  completedAt: state.completedAt!,
                  onBack: onReturnHome,
                ),
                const SizedBox(height: AppSpacing.xl),
                _TotalSummary(total: total),
                const SizedBox(height: AppSpacing.xl),
                _RouteCard(state: state),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Vehículo'),
                const SizedBox(height: AppSpacing.sm),
                _VehicleCard(state: state),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Método de pago'),
                const SizedBox(height: AppSpacing.sm),
                _PaymentCard(payment: state.payment),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Detalle del cobro'),
                const SizedBox(height: AppSpacing.sm),
                _FareBreakdown(total: total),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Semantics(
                    label: 'Identificador del recibo ${receiptNumber(state)}',
                    child: Text(
                      'Recibo #${receiptNumber(state)}',
                      style: AppTypography.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                    ),
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Descargar recibo'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir recibo'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: TextButton(
                    onPressed: onReturnHome,
                    child: const Text('Volver al inicio'),
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

class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader({required this.completedAt, required this.onBack});
  final DateTime completedAt;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        button: true,
        label: 'Volver al inicio',
        child: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: 'Volver al inicio',
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recibo', style: AppTypography.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Viaje completado • ${formatReceiptDate(completedAt)}',
              style: AppTypography.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ],
  );
}

class _TotalSummary extends StatelessWidget {
  const _TotalSummary({required this.total});
  final String total;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        Text('Total', style: AppTypography.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          label: 'Total, $total pesos dominicanos',
          child: Text(
            total,
            style: AppTypography.textTheme.headlineMedium?.copyWith(
              fontSize: 42,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: 'Estado de pago: Pagado',
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withValues(alpha: .10),
              border: Border.all(
                color: AppColors.brandGreen.withValues(alpha: .5),
              ),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, color: AppColors.brandGreen, size: 17),
                SizedBox(width: AppSpacing.xxs),
                Text('Pagado', style: TextStyle(color: Color(0xFF078D5A))),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.state});
  final RideState state;
  @override
  Widget build(BuildContext context) => _ReceiptCard(
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _RouteMotif(),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoutePlace(
                    label: 'Inicio del viaje',
                    name: MockHomeMapData.currentLocationDestination.name,
                    semanticsLabel:
                        'Origen: ${MockHomeMapData.currentLocationDestination.name}',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RoutePlace(
                    label: 'Destino',
                    name: state.destination!.name,
                    semanticsLabel: 'Destino: ${state.destination!.name}',
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Divider(height: 1),
        ),
        Row(
          children: [
            _Metric(
              icon: Icons.route_outlined,
              value: formatRideDistance(state),
              label: 'Distancia',
              semanticsLabel: 'Distancia: ${formatRideDistance(state)}',
            ),
            const _MetricDivider(),
            _Metric(
              icon: Icons.access_time_outlined,
              value: formatRideDuration(state),
              label: 'Tiempo',
              semanticsLabel: 'Tiempo: ${formatRideDuration(state)}',
            ),
            const _MetricDivider(),
            _Metric(
              icon: Icons.directions_car_outlined,
              value: receiptServiceName(state.option),
              label: 'Tipo de servicio',
              semanticsLabel:
                  'Tipo de servicio: ${receiptServiceName(state.option)}',
            ),
          ],
        ),
      ],
    ),
  );
}

class _RouteMotif extends StatelessWidget {
  const _RouteMotif();
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 80,
    width: 24,
    child: Column(
      children: [
        const Icon(Icons.circle, size: 19, color: AppColors.brandGreen),
        Expanded(child: Container(width: 2, color: AppColors.brandGreen)),
        Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brandGreen, width: 2),
          ),
        ),
      ],
    ),
  );
}

class _RoutePlace extends StatelessWidget {
  const _RoutePlace({
    required this.label,
    required this.name,
    required this.semanticsLabel,
  });
  final String label, name, semanticsLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticsLabel,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.textTheme.titleMedium,
          ),
          Text(label, style: AppTypography.textTheme.bodyMedium),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
    required this.semanticsLabel,
  });
  final IconData icon;
  final String value, label, semanticsLabel;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Icon(icon, color: AppColors.brandGreen, size: 23),
            const SizedBox(height: AppSpacing.xs),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();
  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    width: 1,
    color: AppColors.outline.withValues(alpha: .7),
  );
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.state});
  final RideState state;
  @override
  Widget build(BuildContext context) => _ReceiptCard(
    child: Row(
      children: [
        SizedBox(
          width: 158,
          height: 92,
          child: Image.asset(
            vehicleAssetFor(state.option.id),
            fit: BoxFit.contain,
            semanticLabel:
                'Vehículo autónomo ${state.vehicleId ?? 'FLUIR-001'}',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.vehicleId ?? 'FLUIR-001',
                style: AppTypography.textTheme.titleMedium,
              ),
              const Text('Vehículo autónomo'),
              const Text(
                'Color: Blanco',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final PaymentMethod payment;
  @override
  Widget build(BuildContext context) {
    final isVisa = payment.id == 'visa';
    return Semantics(
      label: 'Método de pago ${payment.label}',
      child: _ReceiptCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isVisa ? const Color(0xFF143D8D) : AppColors.navy,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                isVisa ? 'VISA' : 'MC',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                payment.label,
                style: AppTypography.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FareBreakdown extends StatelessWidget {
  const _FareBreakdown({required this.total});
  final String total;
  @override
  Widget build(BuildContext context) => _ReceiptCard(
    child: Column(
      children: [
        _AmountRow(label: 'Tarifa del viaje', value: total),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Divider(height: 1),
        ),
        _AmountRow(label: 'Total', value: total, emphasized: true),
      ],
    ),
  );
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label, value;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: emphasized
            ? AppTypography.textTheme.titleMedium
            : AppTypography.textTheme.bodyLarge,
      ),
      Text(
        value,
        style: emphasized
            ? AppTypography.textTheme.titleMedium
            : AppTypography.textTheme.bodyLarge,
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTypography.textTheme.titleMedium);
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.outline.withValues(alpha: .8)),
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

String formatRideFare(RideState state) =>
    'RD\$${(85 + state.route!.distanceMeters / 1000 * 42 + state.option.multiplier * 20).round()}';

String formatRideDistance(RideState state) {
  final meters = state.route!.distanceMeters;
  return meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
}

String formatRideDuration(RideState state) =>
    '${(state.route!.durationSeconds / 60).ceil()} min';

String receiptServiceName(RideOption option) => switch (option.id) {
  'standard' => 'FLUIR',
  'xl' => 'FLUIR XL',
  _ => 'FLUIR Comfort',
};

String vehicleAssetFor(String optionId) => switch (optionId) {
  'standard' => 'assets/images/vehicles/fluir_standard.png',
  'xl' => 'assets/images/vehicles/fluir_xl.png',
  _ => 'assets/images/vehicles/fluir_comfort.png',
};

String receiptNumber(RideState state) {
  final completedAt = state.completedAt!;
  final date =
      '${completedAt.year}${completedAt.month.toString().padLeft(2, '0')}${completedAt.day.toString().padLeft(2, '0')}';
  final vehicleSuffix = (state.vehicleId ?? 'FLUIR-001').split('-').last;
  return 'FLR-$date-$vehicleSuffix';
}

String formatReceiptDate(DateTime date) {
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
  final meridiem = date.hour < 12 ? 'AM' : 'PM';
  return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $meridiem';
}
