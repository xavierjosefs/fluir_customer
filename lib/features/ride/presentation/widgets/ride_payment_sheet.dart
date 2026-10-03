import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../payments/domain/models/payment_method.dart';
import '../../../payments/presentation/controllers/payment_methods_controller.dart';
import '../../../payments/presentation/payments_providers.dart';
import '../../../payments/presentation/widgets/payment_method_brand_mark.dart';
import '../../domain/models/ride_models.dart';

/// "Pagar con": the wallet, inline in the ride flow.
///
/// Cash is always listed, so a customer without a saved card can still pay, and
/// adding a card happens in the app and comes straight back here.
Future<RidePaymentOption?> showRidePaymentSheet(
  BuildContext context, {
  required RidePaymentOption selected,
}) => showModalBottomSheet<RidePaymentOption>(
  context: context,
  isScrollControlled: true,
  builder: (sheetContext) => RidePaymentSheet(selected: selected),
);

class RidePaymentSheet extends ConsumerWidget {
  const RidePaymentSheet({required this.selected, super.key});

  final RidePaymentOption selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(paymentMethodsControllerProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text('Pagar con', style: theme.textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                children: [
                  if (wallet.status == PaymentMethodsStatus.loading)
                    const _WalletHint(
                      key: ValueKey('ride-payment-loading'),
                      message: 'Cargando tus tarjetas…',
                      showProgress: true,
                    ),
                  if (wallet.status == PaymentMethodsStatus.error ||
                      wallet.status == PaymentMethodsStatus.listingUnavailable)
                    _WalletHint(
                      key: const ValueKey('ride-payment-wallet-error'),
                      message:
                          wallet.errorMessage ??
                          'No pudimos cargar tus tarjetas guardadas.',
                      onRetry: wallet.isRecoverable
                          ? ref
                                .read(paymentMethodsControllerProvider.notifier)
                                .load
                          : null,
                    ),
                  for (final method in wallet.methods)
                    _PaymentRow(
                      key: ValueKey('ride-payment-${method.id}'),
                      option: RidePaymentOption.fromMethod(method),
                      selected: selected.id == method.id,
                      trailingNote: method.isDefault ? 'Predeterminada' : null,
                    ),
                  _PaymentRow(
                    key: const ValueKey('ride-payment-cash'),
                    option: RidePaymentOption.cash,
                    selected: selected.isCash,
                    trailingNote: 'Paga al llegar',
                  ),
                  const Divider(height: AppSpacing.lg),
                  ListTile(
                    key: const ValueKey('ride-payment-add-card'),
                    leading: const Icon(Icons.add, color: AppColors.brandBlue),
                    title: const Text('Agregar método de pago'),
                    onTap: () => _addCard(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCard(BuildContext context, WidgetRef ref) async {
    ref.read(addCardControllerProvider.notifier).reset();
    final added = await context.push<PaymentMethod>(AppRoutes.addPaymentMethod);
    if (!context.mounted) return;
    // A freshly added card becomes the choice; cancelling leaves the sheet as
    // it was so the customer can still pick something else.
    if (added == null) return;
    Navigator.of(context).pop(RidePaymentOption.fromMethod(added));
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.option,
    required this.selected,
    this.trailingNote,
    super.key,
  });

  final RidePaymentOption option;
  final bool selected;
  final String? trailingNote;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: option.isCash
        ? const _CashMark()
        : PaymentMethodBrandMark(brand: option.brand, size: .78),
    title: Text(option.label, overflow: TextOverflow.ellipsis),
    subtitle: trailingNote == null ? null : Text(trailingNote!),
    trailing: selected
        ? const Icon(Icons.check_circle, color: AppColors.brandBlue)
        : null,
    selected: selected,
    onTap: () => Navigator.of(context).pop(option),
  );
}

class _CashMark extends StatelessWidget {
  const _CashMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 41,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.brandGreen.withValues(alpha: .14),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(AppRadius.small * .75),
    ),
    child: const Icon(
      Icons.payments_outlined,
      size: 16,
      color: AppColors.brandGreenInk,
    ),
  );
}

class _WalletHint extends StatelessWidget {
  const _WalletHint({
    required this.message,
    this.onRetry,
    this.showProgress = false,
    super.key,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool showProgress;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        if (showProgress) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
