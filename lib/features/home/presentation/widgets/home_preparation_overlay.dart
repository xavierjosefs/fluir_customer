import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/fluir_wordmark.dart';
import '../../domain/models/home_readiness_state.dart';

class HomePreparationOverlay extends StatelessWidget {
  const HomePreparationOverlay({
    required this.state,
    required this.onRetry,
    super.key,
  });

  final HomeReadinessState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: state.isReady,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: state.isReady
          ? const SizedBox.expand(key: ValueKey('home-ready'))
          : state.hasFailed
          ? _HomePreparationError(
              key: const ValueKey('home-readiness-error'),
              message: state.failureMessage!,
              onRetry: onRetry,
            )
          : const _HomePreparationLoading(
              key: ValueKey('home-readiness-loading'),
            ),
    ),
  );
}

class _HomePreparationLoading extends StatelessWidget {
  const _HomePreparationLoading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Preparando Fluir',
    child: const ColoredBox(
      color: AppColors.brandBlue,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FluirWordmark(fontSize: 44),
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'Preparando tu experiencia…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomePreparationError extends StatelessWidget {
  const _HomePreparationError({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: 'No pudimos cargar el mapa. $message',
    child: ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No pudimos cargar el mapa',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
