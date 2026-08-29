import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({required this.child, this.onBack, super.key});
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
