import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.child, this.onBack, super.key});
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          if (onBack != null)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: IconButton(
                tooltip: 'Volver',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: child,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class FluirWordmark extends StatelessWidget {
  const FluirWordmark({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fluir',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.route_rounded, color: AppColors.brandGreen, size: 30),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'FLUIR',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(letterSpacing: 1.4, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
