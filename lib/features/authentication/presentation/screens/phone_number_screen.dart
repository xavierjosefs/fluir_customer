import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/dominican_phone_input_formatter.dart';
import '../../domain/models/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_status_message.dart';
import '../widgets/phone_auth_background.dart';

class PhoneNumberScreen extends ConsumerStatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  ConsumerState<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends ConsumerState<PhoneNumberScreen> {
  late final TextEditingController _phoneController;
  late final FocusNode _phoneFocusNode;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: DominicanPhoneInputFormatter.format(
        ref.read(authControllerProvider).phone,
      ),
    );
    _phoneFocusNode = FocusNode()..addListener(_refresh);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final isSending = state.status == AuthStatus.sendingCode;
    final isPhoneError = state.message != null && !state.isPhoneValid;
    final fieldBorder = isPhoneError
        ? AppColors.error
        : _phoneFocusNode.hasFocus
        ? AppColors.brandBlue
        : colors.outline;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const PhoneAuthBackground(),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: AppSpacing.xs,
                  left: AppSpacing.xs,
                  child: IconButton(
                    tooltip: 'Volver al inicio',
                    onPressed: controller.returnToEntry,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      92,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 92,
                        maxWidth: 460,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hola, te damos\nla bienvenida',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontSize: 36, height: 1.08),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Ingresa tu número de celular para continuar.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Número de celular',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            height: 82,
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: .94),
                              borderRadius: BorderRadius.circular(
                                AppRadius.large,
                              ),
                              border: Border.all(
                                color: fieldBorder,
                                width: _phoneFocusNode.hasFocus ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Semantics(
                                  button: true,
                                  label: 'País o territorio: República Dominicana, código más uno',
                                  child: InkWell(
                                    key: const ValueKey('territory-selector'),
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(AppRadius.large),
                                    ),
                                    onTap: () => _showTerritorySheet(context),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '🇩🇴',
                                            style: TextStyle(fontSize: 20),
                                          ),
                                          SizedBox(width: AppSpacing.xxs),
                                          Text('+1'),
                                          Icon(Icons.arrow_drop_down),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: colors.outline,
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    focusNode: _phoneFocusNode,
                                    enabled: !isSending,
                                    keyboardType: TextInputType.phone,
                                    autofillHints: const [
                                      AutofillHints.telephoneNumber,
                                    ],
                                    inputFormatters: const [
                                      DominicanPhoneInputFormatter(),
                                    ],
                                    onChanged: (value) => controller.updatePhone(
                                      DominicanPhoneInputFormatter.normalize(
                                        value,
                                      ),
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.md,
                                      ),
                                      hintText: '(829) 273-1655',
                                    ),
                                  ),
                                ),
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
                          const SizedBox(height: AppSpacing.xl),
                          ElevatedButton(
                            onPressed: isSending ? null : controller.sendCode,
                            child: isSending
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.onPrimary,
                                        ),
                                      ),
                                      SizedBox(width: AppSpacing.xs),
                                      Text('Enviando código'),
                                    ],
                                  )
                                : Text(
                                    state.status == AuthStatus.sendFailure
                                        ? 'Reintentar'
                                        : 'Continuar',
                                  ),
                          ),
                          if (isSending) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Se está enviando el código.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          _ConsentSection(
                            value: state.hasConsent,
                            enabled: !isSending,
                            onChanged: controller.updateConsent,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: () => _showHelpSheet(context),
                            child: const Text('¿Necesitas ayuda?'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTerritorySheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
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
            ListTile(
              leading: const Text('🇩🇴', style: TextStyle(fontSize: 24)),
              title: const Text('República Dominicana'),
              subtitle: const Text('Código de país +1'),
              trailing: const Icon(Icons.check, color: AppColors.brandGreen),
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  );

  void _showHelpSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Necesitas ayuda?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Verifica que tu número de República Dominicana tenga 10 dígitos.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConsentSection extends StatelessWidget {
  const _ConsentSection({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 48,
        height: 48,
        child: Checkbox(
          value: value,
          onChanged: enabled ? (next) => onChanged(next ?? false) : null,
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              Text('Al continuar, aceptas nuestros '),
              _LegalLink(label: 'Términos y Condiciones'),
              Text(' y la '),
              _LegalLink(label: 'Política de Privacidad'),
              Text('.'),
            ],
          ),
        ),
      ),
    ],
  );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
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
