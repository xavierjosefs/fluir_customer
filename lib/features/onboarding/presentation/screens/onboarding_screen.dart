import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/system_ui.dart';
import '../../../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../../../features/authentication/presentation/controllers/customer_session_controller.dart';
import '../../../../shared/widgets/fluir_wordmark.dart';
import '../widgets/onboarding_reference_background.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  void _continue(BuildContext context, WidgetRef ref) {
    ref.read(authControllerProvider.notifier).begin();
    context.go('/auth/phone');
  }

  /// Demo builds only: signs in the seeded demo customer of the backend.
  Future<void> _signInAsDemoCustomer(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final signedIn = await ref
        .read(customerSessionProvider.notifier)
        .signInWithDemoCustomer();
    if (signedIn && context.mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoSignIn = ref.watch(demoSignInAvailableProvider);
    final session = ref.watch(customerSessionProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (session.message != null) ...[
                              _SessionNotice(message: session.message!),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            if (demoSignIn) ...[
                              _DemoSignInButton(
                                busy:
                                    session.status ==
                                    CustomerSessionStatus.signingIn,
                                onPressed: () =>
                                    _signInAsDemoCustomer(context, ref),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            SizedBox(
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
                          ],
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
}

/// Why the customer is back here (expired session, failed demo sign-in).
class _SessionNotice extends StatelessWidget {
  const _SessionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const ValueKey('onboarding-session-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xE6080A0D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

class _DemoSignInButton extends StatelessWidget {
  const _DemoSignInButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: OutlinedButton(
      key: const ValueKey('onboarding-demo-customer'),
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white),
      ),
      child: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : const Text('Entrar como cliente demo'),
    ),
  );
}
