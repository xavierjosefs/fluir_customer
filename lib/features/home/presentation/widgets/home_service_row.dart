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
    final isComingSoon =
        service.availability == HomeServiceAvailability.comingSoon;
    return Semantics(
      button: true,
      label: isComingSoon
          ? '${service.title}. ${service.subtitle}. Próximamente.'
          : '${service.title}. ${service.subtitle}.',
      child: Material(
        color: Colors.white,
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
              border: Border.all(
                color: AppColors.outline.withValues(alpha: .72),
              ),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                _ServiceIcon(title: service.title),
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
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isComingSoon) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const _ComingSoonBadge(),
                ],
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final icon = switch (title) {
      'Viaje' => Icons.directions_car_filled,
      'Envío' => Icons.inventory_2_outlined,
      _ => Icons.handyman_outlined,
    };
    final color = switch (title) {
      'Viaje' => AppColors.navy,
      'Envío' => const Color(0xFFB77936),
      _ => AppColors.brandBlue,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}

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
