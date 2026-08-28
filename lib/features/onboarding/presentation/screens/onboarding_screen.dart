import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/system_ui.dart';
import '../../../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../../../shared/widgets/fluir_wordmark.dart';
import '../widgets/onboarding_reference_background.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  void _continue(BuildContext context, WidgetRef ref) {
    ref.read(authControllerProvider.notifier).begin();
    context.go('/auth/phone');
  }

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppSystemUi.lightContent,
        child: Scaffold(
          backgroundColor: AppColors.brandBlue,
          body: Stack(
            children: [
              const OnboardingReferenceBackground(),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      SizedBox(height: constraints.maxHeight * .27),
                      const FluirWordmark(fontSize: 88),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Movilidad autónoma,\nenvíos y servicios',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const ValueKey('onboarding-continue'),
                              onPressed: () => _continue(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.brandBlue,
                                elevation: 0,
                              ),
                              child: const Text('Continuar'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
