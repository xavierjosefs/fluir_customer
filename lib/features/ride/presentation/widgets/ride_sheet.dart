import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../payments/presentation/widgets/payment_method_brand_mark.dart';
import '../../domain/models/ride_models.dart';
import '../../domain/models/ride_route.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/ride_fare.dart';
import '../controllers/ride_controller.dart';
import 'ride_option_row.dart';
import 'ride_payment_sheet.dart';
import 'ride_tracking_surface.dart';

class RideSheet extends ConsumerWidget {
  const RideSheet({
    required this.state,
    required this.controller,
    required this.onBackToDestination,
    required this.onReturnHome,
    this.now,
    this.options = rideOptions,
    this.syncStatus,
    super.key,
  });

  final RideState state;
  final RideController controller;
  final VoidCallback onBackToDestination;
  final VoidCallback onReturnHome;

  /// Reference clock for the arrival estimates. Injected by tests.
  final DateTime? now;

  /// The fleet on offer. Overridden by tests.
  final List<RideOption> options;

  /// How fresh a live trip is (banners). `null` for the local simulation.
  final TripSyncStatus? syncStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status.isActiveTrip) {
      return RideTrackingSurface(
        state: state,
        controller: controller,
        onCancelRide: onBackToDestination,
        onReturnHome: onReturnHome,
        syncStatus: syncStatus,
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.large),
      ),
      // Home already positions the sheet above the system inset.
      child: SafeArea(top: false, bottom: false, child: _content(context, ref)),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    if (state.status == RideStatus.calculatingRoute) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: _Status(
          title: 'Calculando tu ruta…',
          detail: 'Estamos preparando las opciones para tu viaje.',
          loading: true,
        ),
      );
    }
    if (state.status == RideStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: _PlanningHeader(
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
        ),
      );
    }
    if (state.status == RideStatus.planning) {
      return _planning(context, ref, state.route!);
    }
    return const SizedBox.shrink();
  }

  Widget _planning(BuildContext context, WidgetRef ref, RideRoute route) {
    final clock = now ?? DateTime.now();
    final payment = ref.watch(effectiveRidePaymentProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetGrabber(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.lg,
            0,
          ),
          child: _PlanningHeader(
            destination: state.destination!.name,
            metadata:
                '${(route.durationSeconds / 60).ceil()} min • '
                '${(route.distanceMeters / 1000).toStringAsFixed(1)} km',
            onBack: onBackToDestination,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            children: [
              for (final option in options.map(_offered))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: RideOptionRow(
                    option: option,
                    price: option.isAvailable ? _price(option, route) : null,
                    arrival: _arrivalLabel(clock, route, option),
                    selected: state.option.id == option.id,
                    onTap: () => _selectOption(context, option),
                  ),
                ),
              if (state.quotes?.status == RideQuoteStatus.failed)
                _QuoteFailure(onRetry: controller.retryQuotes),
            ],
          ),
        ),
        _Footer(
          payment: payment,
          onPaymentTap: () => _changePayment(context, ref, payment),
          onConfirm: controller.confirm,
          submitting: state.isSubmitting,
          canConfirm: _canConfirm,
          message: state.quotes?.status == RideQuoteStatus.failed
              ? null
              : state.message,
        ),
      ],
    );
  }

  /// With server fares, a tier the backend does not price cannot be booked.
  RideOption _offered(RideOption option) {
    final quotes = state.quotes;
    if (!option.isAvailable ||
        quotes == null ||
        quotes.status != RideQuoteStatus.ready ||
        quotes.offers(option)) {
      return option;
    }
    return option.asUnavailable();
  }

  /// Server fare when the backend prices rides; the local estimate otherwise.
  String? _price(RideOption option, RideRoute route) {
    final quotes = state.quotes;
    if (quotes == null) {
      return RideFare.formatted(
        distanceMeters: route.distanceMeters,
        option: option,
      );
    }
    final quote = quotes.forOption(option);
    return switch (quotes.status) {
      RideQuoteStatus.loading => '…',
      RideQuoteStatus.failed => '—',
      RideQuoteStatus.ready =>
        quote == null ? null : RideFare.format(quote.price.round()),
    };
  }

  bool get _canConfirm {
    final quotes = state.quotes;
    return !state.isSubmitting &&
        (quotes == null || quotes.offers(state.option));
  }

  void _selectOption(BuildContext context, RideOption option) {
    if (option.isAvailable) {
      controller.selectOption(option);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.displayName,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${option.description}. Todavía no está disponible en tu zona; '
                'mientras tanto puedes viajar con las unidades terrestres.',
                style: Theme.of(sheetContext).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePayment(
    BuildContext context,
    WidgetRef ref,
    RidePaymentOption current,
  ) async {
    final chosen = await showRidePaymentSheet(context, selected: current);
    if (chosen == null) return;
    controller.selectPayment(chosen);
  }

  /// Clock time the customer is expected to arrive: the wait for the vehicle
  /// plus the route duration.
  static String _arrivalLabel(
    DateTime now,
    RideRoute route,
    RideOption option,
  ) {
    final arrival = now.add(
      Duration(minutes: option.pickupMinutes) +
          Duration(seconds: route.durationSeconds.round()),
    );
    return '${arrival.hour.toString().padLeft(2, '0')}:'
        '${arrival.minute.toString().padLeft(2, '0')}';
  }
}

/// Pinned bottom bar: how the ride is paid, and the single action that starts
/// it.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.payment,
    required this.onPaymentTap,
    required this.onConfirm,
    this.submitting = false,
    this.canConfirm = true,
    this.message,
  });

  final RidePaymentOption payment;
  final VoidCallback onPaymentTap;
  final VoidCallback onConfirm;

  /// The request is on its way: one tap creates one trip.
  final bool submitting;
  final bool canConfirm;

  /// Why the last request failed, in Spanish.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PaymentRow(payment: payment, onTap: onPaymentTap),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  message!,
                  key: const ValueKey('ride-request-message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('ride-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: AppColors.navy,
                ),
                onPressed: submitting || !canConfirm ? null : onConfirm,
                child: submitting
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            'Solicitando viaje…',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    : const Text(
                        'Confirmar viaje',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Puedes cancelar sin costo antes de confirmar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The backend fares could not be loaded: say so and offer to try again.
class _QuoteFailure extends StatelessWidget {
  const _QuoteFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'No pudimos obtener las tarifas.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

/// The usual affordance that this surface is a sheet sitting over the map.
class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 44,
      height: 4,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _PlanningHeader extends StatelessWidget {
  const _PlanningHeader({
    required this.destination,
    required this.metadata,
    required this.onBack,
    this.child,
  });
  final String destination, metadata;
  final VoidCallback onBack;

  /// Content shown under the destination, when the state has any.
  final Widget? child;
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
      ?child,
    ],
  );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});
  final RidePaymentOption payment;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Método de pago ${payment.label}. Tocar para cambiar',
    child: InkWell(
      key: const ValueKey('ride-payment-selector'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            if (payment.isCash)
              const Icon(
                Icons.payments_outlined,
                size: 22,
                color: AppColors.brandGreenInk,
              )
            else
              PaymentMethodBrandMark(brand: payment.brand, size: .7),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                payment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    mainAxisSize: MainAxisSize.min,
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
