import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_message.dart';

class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});
  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  late final TextEditingController _phoneController;
  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: ref.read(authControllerProvider).formattedPhone,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final isSending = state.status == AuthStatus.sendingCode;
    return AuthScaffold(
      onBack: controller.returnToEntry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FluirWordmark(),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Ingresa tu número',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Te enviaremos un código por SMS para verificar tu número.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'País o territorio',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: () => _showTerritorySheet(context),
            icon: const Text('🇩🇴', semanticsLabel: 'República Dominicana'),
            label: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('República Dominicana (+1)'),
                Icon(Icons.expand_more),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _phoneController,
            enabled: !isSending,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: controller.updatePhone,
            decoration: const InputDecoration(
              labelText: 'Número de teléfono',
              hintText: '809 123 4567',
              prefixText: '+1  ',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Usa tu número de República Dominicana, sin el código de país.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          CheckboxListTile(
            value: state.hasConsent,
            onChanged: isSending
                ? null
                : (value) => controller.updateConsent(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: Wrap(
              children: [
                const Text('Acepto los '),
                _LegalLink(label: 'Términos'),
                const Text(' y la '),
                _LegalLink(label: 'Política de privacidad'),
                const Text('.'),
              ],
            ),
          ),
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AuthStatusMessage(
              message: state.status == AuthStatus.sendFailure
                  ? 'No pudimos enviar el código. ${state.message}'
                  : state.message!,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: isSending ? null : controller.sendCode,
            child: isSending
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text('Enviando código'),
                    ],
                  )
                : Text(
                    state.status == AuthStatus.sendFailure
                        ? 'Reintentar'
                        : 'Enviar código',
                  ),
          ),
          if (isSending) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Se está enviando el código.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  void _showTerritorySheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'País o territorio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            const ListTile(
              leading: Text('🇩🇴', style: TextStyle(fontSize: 24)),
              title: Text('República Dominicana'),
              trailing: Text('+1'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Este prototipo inicia con República Dominicana.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text('$label estará disponible próximamente.'),
        ),
      ),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.brandBlue,
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
