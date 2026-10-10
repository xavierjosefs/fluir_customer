import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/card_input_formatters.dart';
import '../../domain/models/card_entry.dart';
import '../controllers/add_card_controller.dart';
import '../payments_providers.dart';
import '../widgets/payment_method_brand_mark.dart';

/// "Agregar tarjeta": the card is captured and tokenised inside Fluir, with no
/// hosted payment page in between.
///
/// The typed card never leaves this screen's controller: it goes straight to
/// the vault and is dropped. Only the brand, the last four digits and the
/// expiry come back.
class AddPaymentMethodPage extends ConsumerStatefulWidget {
  const AddPaymentMethodPage({super.key});

  @override
  ConsumerState<AddPaymentMethodPage> createState() =>
      _AddPaymentMethodPageState();
}

class _AddPaymentMethodPageState extends ConsumerState<AddPaymentMethodPage> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _securityCode = TextEditingController();
  final _holder = TextEditingController();
  final _expiryFocus = FocusNode();
  final _securityFocus = FocusNode();

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _securityCode.dispose();
    _holder.dispose();
    _expiryFocus.dispose();
    _securityFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addCardControllerProvider);
    final controller = ref.read(addCardControllerProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(addCardControllerProvider, (previous, next) {
      if (next.stage != AddCardStage.saved || !context.mounted) return;
      // The wallet already re-read the vault; hand the saved card back to
      // whoever opened this screen. Reached directly, fall back to the wallet
      // instead of leaving the customer on a finished form.
      if (context.canPop()) {
        context.pop(next.savedMethod);
      } else {
        context.go(AppRoutes.paymentMethods);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar tarjeta'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Text(
              'Ingresa los datos de tu tarjeta',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'La guardamos tokenizada para que pagues tus viajes con un toque.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const ValueKey('card-number-field'),
              controller: _number,
              enabled: !state.isBusy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.creditCardNumber],
              inputFormatters: const [CardNumberInputFormatter()],
              onChanged: (value) {
                controller.updateNumber(value);
                if (CardEntryDraft.digitsOf(value).length ==
                    state.draft.brand.maxNumberLength) {
                  _expiryFocus.requestFocus();
                }
              },
              decoration: InputDecoration(
                labelText: 'Número de tarjeta',
                hintText: '1234 5678 9012 3456',
                errorText: state.errors[CardField.number],
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: PaymentMethodBrandMark(
                    brand: state.draft.brand,
                    size: .8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('card-expiry-field'),
                    controller: _expiry,
                    focusNode: _expiryFocus,
                    enabled: !state.isBusy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [
                      AutofillHints.creditCardExpirationDate,
                    ],
                    inputFormatters: const [CardExpiryInputFormatter()],
                    onChanged: (value) {
                      controller.updateExpiry(value);
                      if (CardEntryDraft.digitsOf(value).length == 4) {
                        _securityFocus.requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Vencimiento',
                      hintText: 'MM/AA',
                      errorText: state.errors[CardField.expiry],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    key: const ValueKey('card-security-code-field'),
                    controller: _securityCode,
                    focusNode: _securityFocus,
                    enabled: !state.isBusy,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: state.draft.brand.securityCodeLength,
                    buildCounter: _noCounter,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        state.draft.brand.securityCodeLength,
                      ),
                    ],
                    onChanged: controller.updateSecurityCode,
                    decoration: InputDecoration(
                      labelText: state.draft.brand.securityCodeLabel,
                      hintText: '•' * state.draft.brand.securityCodeLength,
                      errorText: state.errors[CardField.securityCode],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const ValueKey('card-holder-field'),
              controller: _holder,
              enabled: !state.isBusy,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.creditCardName],
              onChanged: controller.updateHolder,
              decoration: InputDecoration(
                labelText: 'Nombre en la tarjeta',
                hintText: 'Como aparece impreso',
                errorText: state.errors[CardField.holder],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SwitchListTile.adaptive(
              key: const ValueKey('card-make-default-switch'),
              value: state.makeDefault,
              onChanged: state.isBusy ? null : controller.setMakeDefault,
              contentPadding: EdgeInsets.zero,
              title: const Text('Usar como método predeterminado'),
            ),
            if (state.message != null && state.stage != AddCardStage.saved) ...[
              const SizedBox(height: AppSpacing.sm),
              _FormMessage(
                key: const ValueKey('card-form-error'),
                message: state.message!,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const _SecurityNote(),
            const SizedBox(height: AppSpacing.xs),
            const _SimulatedVaultNote(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: SizedBox(
          height: 52,
          child: FilledButton(
            key: const ValueKey('save-card-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: state.canSubmit ? controller.submit : null,
            child: state.isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar tarjeta'),
          ),
        ),
      ),
    );
  }

  static Widget? _noCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

class _FormMessage extends StatelessWidget {
  const _FormMessage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: .10),
      border: Border.all(color: AppColors.error.withValues(alpha: .40)),
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 18, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Tus datos viajan cifrados y se guardan tokenizados. Fluir solo '
            'conserva la marca y los últimos cuatro dígitos.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _SimulatedVaultNote extends StatelessWidget {
  const _SimulatedVaultNote();

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('simulated-vault-note'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.science_outlined, size: 18, color: AppColors.warning),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Text(
          'Modo demostración: la tarjeta se tokeniza en este dispositivo y '
          'no se realiza ningún cargo.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ],
  );
}
