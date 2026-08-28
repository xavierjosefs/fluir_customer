import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class CodeSentScreen extends ConsumerWidget {
  const CodeSentScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    return AuthScaffold(
      onBack: controller.editPhone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FluirWordmark(),
          const SizedBox(height: AppSpacing.xxl),
          const Icon(
            Icons.mark_email_read_outlined,
            size: 72,
            color: AppColors.brandBlue,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Código enviado',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enviamos un código a ${state.maskedPhone}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (state.remainingSeconds > 0)
            Text(
              'Puedes reenviarlo en ${_formatTime(state.remainingSeconds)}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            TextButton.icon(
              onPressed: controller.sendCode,
              icon: const Icon(Icons.refresh),
              label: const Text('Reenviar código'),
            ),
          const SizedBox(height: AppSpacing.xxl),
          ElevatedButton(
            onPressed: controller.enterOtp,
            child: const Text('Ingresar código'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: controller.editPhone,
            child: const Text('Cambiar número'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) => '00:${seconds.toString().padLeft(2, '0')}';
}
