import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/home_service.dart';

class HomeServiceRow extends StatelessWidget {
  const HomeServiceRow({required this.service, required this.onTap, super.key});

  final HomeService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isComingSoon =
        service.availability == HomeServiceAvailability.comingSoon;
    return Semantics(
      button: true,
      label: isComingSoon
          ? '${service.title}. ${service.subtitle}. Próximamente.'
          : '${service.title}. ${service.subtitle}.',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outline.withValues(alpha: .72)),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                ExcludeSemantics(child: _ServiceImage(title: service.title)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        service.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (isComingSoon) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const _ComingSoonBadge(),
                ],
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceImage extends StatelessWidget {
  const _ServiceImage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final asset = homeServiceAsset(title);
    return SizedBox(
      width: 64,
      height: 64,
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

class HomeExpandedServiceCard extends StatelessWidget {
  const HomeExpandedServiceCard({
    required this.service,
    required this.onTap,
    super.key,
  });

  final HomeService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isComingSoon =
        service.availability == HomeServiceAvailability.comingSoon;
    return Semantics(
      button: true,
      label: isComingSoon
          ? '${service.title}. ${service.subtitle}. Próximamente.'
          : '${service.title}. ${service.subtitle}.',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: Container(
            key: ValueKey('expanded-service-${service.title}'),
            constraints: const BoxConstraints(minHeight: 124),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outline.withValues(alpha: .72)),
              borderRadius: BorderRadius.circular(AppRadius.large),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withValues(alpha: .035),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final imageSize = constraints.maxWidth > 390 ? 106.0 : 92.0;
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            service.subtitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                          if (isComingSoon) ...[
                            const SizedBox(height: AppSpacing.xs),
                            const _ComingSoonBadge(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ExcludeSemantics(
                      child: SizedBox(
                        width: imageSize,
                        height: imageSize,
                        child: Image.asset(
                          homeServiceAsset(service.title),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

String homeServiceAsset(String title) => switch (title) {
  'Viaje' => 'assets/images/services/fluir_ride.png',
  'Envío' => 'assets/images/services/fluir_delivery.png',
  'Servicios' => 'assets/images/services/fluir_services.png',
  _ => 'assets/images/services/fluir_services.png',
};

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.brandGreen.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.small),
      border: Border.all(color: AppColors.brandGreen.withValues(alpha: .35)),
    ),
    child: const Text(
      'Próximamente',
      style: TextStyle(
        color: Color(0xFF167C53),
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
