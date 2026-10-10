import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/payment_method.dart';
import '../controllers/payment_methods_controller.dart';
import '../payments_providers.dart';
import '../widgets/payment_method_tile.dart';
import '../widgets/payments_status_view.dart';

/// "Métodos de pago": the customer's saved cards and the entry point to
/// registering a new one.
class PaymentMethodsPage extends ConsumerWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentMethodsControllerProvider);
    final controller = ref.read(paymentMethodsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Métodos de pago'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SafeArea(
        child: switch (state.status) {
          PaymentMethodsStatus.loading => const PaymentsProgressView(
            key: ValueKey('payment-methods-loading'),
            title: 'Cargando tus métodos de pago',
            description: 'Estamos consultando tus tarjetas guardadas.',
          ),
          PaymentMethodsStatus.error => PaymentsStatusView(
            key: const ValueKey('payment-methods-error'),
            icon: Icons.wifi_off_rounded,
            iconColor: AppColors.error,
            title: 'No pudimos cargar tus tarjetas',
            description:
                state.errorMessage ??
                'Revisa tu conexión e inténtalo nuevamente.',
            primaryLabel: state.isRecoverable ? 'Reintentar' : null,
            onPrimary: state.isRecoverable ? controller.load : null,
            secondaryLabel: 'Volver',
            onSecondary: () => _leave(context),
          ),
          PaymentMethodsStatus.ready =>
            state.methods.isEmpty
                ? PaymentsStatusView(
                    key: const ValueKey('payment-methods-empty'),
                    icon: Icons.credit_card_outlined,
                    iconColor: AppColors.brandBlue,
                    title: 'Aún no tienes tarjetas',
                    description:
                        'Agrega una tarjeta para pagar tus viajes sin '
                        'interrupciones.',
                    primaryLabel: 'Agregar método de pago',
                    onPrimary: () => _openAddFlow(context, ref),
                  )
                : _MethodsList(state: state, controller: controller),
        },
      ),
      bottomNavigationBar: state.canManageMethods
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: ElevatedButton.icon(
                key: const ValueKey('add-payment-method-button'),
                onPressed: () => _openAddFlow(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Agregar método de pago'),
              ),
            )
          : null,
    );
  }

  Future<void> _openAddFlow(BuildContext context, WidgetRef ref) async {
    ref.read(addCardControllerProvider.notifier).reset();
    await context.push<PaymentMethod>(AppRoutes.addPaymentMethod);
    if (!context.mounted) return;
    await ref.read(paymentMethodsControllerProvider.notifier).refresh();
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.account);
    }
  }
}

class _MethodsList extends StatelessWidget {
  const _MethodsList({required this.state, required this.controller});

  final PaymentMethodsState state;
  final PaymentMethodsController controller;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: controller.refresh,
    child: ListView(
      // Keeps pull-to-refresh available when a short list does not overflow.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      children: [
        if (state.errorMessage != null) ...[
          _InlineError(
            message: state.errorMessage!,
            onRetry: state.isRecoverable ? controller.refresh : null,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(
          'Tus tarjetas',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final method in state.methods) ...[
          PaymentMethodTile(
            key: ValueKey('payment-method-${method.id}'),
            method: method,
            isBusy: state.busyMethodId == method.id,
            onSetDefault: () => controller.setDefault(method.id),
            onRemove: () => controller.revoke(method.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Modo demostración: estas tarjetas se tokenizan en este '
          'dispositivo. Fluir solo conserva la marca y los últimos cuatro '
          'dígitos, y no se genera ningún cargo.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('payment-methods-inline-error'),
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: .10),
      border: Border.all(color: AppColors.error.withValues(alpha: .40)),
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}
