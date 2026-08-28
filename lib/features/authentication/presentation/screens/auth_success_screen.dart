import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../widgets/auth_scaffold.dart';

class AuthSuccessScreen extends StatelessWidget {
  const AuthSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FluirWordmark(),
        const SizedBox(height: AppSpacing.xxl),
        Semantics(
          label: 'Cuenta verificada correctamente',
          child: const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 88,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '¡Cuenta verificada!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tu número ha sido verificado correctamente.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.xxl),
        ElevatedButton(
          onPressed: () => context.go('/inicio'),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}
