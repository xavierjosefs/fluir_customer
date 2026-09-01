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
  Widget build(BuildContext context, WidgetRef ref) =>
      AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppSystemUi.lightContent,
        child: Scaffold(
          backgroundColor: AppColors.brandBlue,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const OnboardingReferenceBackground(),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Positioned(
                        top: constraints.maxHeight * .09,
                        left: AppSpacing.xl,
                        right: AppSpacing.xl,
                        child: Column(
                          children: [
                            const FluirWordmark(fontSize: 76),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Movilidad autónoma,\nenvíos y servicios',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: constraints.maxHeight * .29,
                        left: -constraints.maxWidth * .42,
                        width: constraints.maxWidth * 1.86,
                        height: constraints.maxHeight * .62,
                        child: IgnorePointer(
                          child: Semantics(
                            image: true,
                            label: 'Vehículo autónomo Fluir',
                            child: ClipRect(
                              child: Image.asset(
                                'assets/images/onboarding/fluir_onboarding_vehicle.png',
                                key: const ValueKey('onboarding-vehicle'),
                                fit: BoxFit.cover,
                                alignment: const Alignment(-.18, .22),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        bottom: AppSpacing.md,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              key: const ValueKey('onboarding-continue'),
                              onPressed: () => _continue(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF080A0D),
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: const Text('Continuar'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
