import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

class AuthEntryScreen extends ConsumerWidget {
  const AuthEntryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FluirWordmark(),
        const SizedBox(height: AppSpacing.xxl),
        Icon(
          Icons.verified_user_outlined,
          size: 72,
          color: AppColors.brandBlue.withValues(alpha: .85),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Muévete con confianza',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Verifica tu número para mantener tu cuenta segura y recibir actualizaciones importantes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xxl),
        ElevatedButton(
          onPressed: ref.read(authControllerProvider.notifier).begin,
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}
