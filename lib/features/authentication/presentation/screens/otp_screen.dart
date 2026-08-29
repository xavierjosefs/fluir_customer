import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_status_message.dart';
import '../widgets/otp_input.dart';

class OtpScreen extends ConsumerWidget {
  const OtpScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final isExpired = state.status == AuthStatus.expiredOtp;
    final isVerifying = state.status == AuthStatus.verifyingOtp;
    final hasError = state.status == AuthStatus.invalidOtp || isExpired;
    return AuthScaffold(
      onBack: controller.editPhone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Text(
            isExpired ? 'Código expirado' : 'Ingresa el código',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isExpired
                ? 'El código ya no es válido. Solicita uno nuevo para continuar.'
                : 'Enviamos un código a ${state.maskedPhone}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!isExpired)
            OtpInput(
              value: state.otp,
              onChanged: controller.updateOtp,
              hasError: hasError,
            ),
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            if (state.status == AuthStatus.invalidOtp) ...[
              Text(
                'Código incorrecto',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            AuthStatusMessage(message: state.message!),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (isExpired)
            ElevatedButton(
              onPressed: controller.sendCode,
              child: const Text('Enviar nuevo código'),
            )
          else
            ElevatedButton(
              onPressed: isVerifying ? null : controller.verifyOtp,
              child: isVerifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        Text('Verificando'),
                      ],
                    )
                  : const Text('Verificar código'),
            ),
          const SizedBox(height: AppSpacing.md),
          if (state.remainingSeconds > 0)
            Text(
              'Reenviar en 00:${state.remainingSeconds.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            TextButton.icon(
              onPressed: controller.sendCode,
              icon: const Icon(Icons.refresh),
              label: const Text('Reenviar código'),
            ),
          TextButton(
            onPressed: controller.editPhone,
            child: const Text('Cambiar número'),
          ),
        ],
      ),
    );
  }
}
