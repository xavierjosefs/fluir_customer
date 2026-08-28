import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/home_service.dart';
import 'home_service_row.dart';

class HomeServicesPanel extends StatelessWidget {
  const HomeServicesPanel({
    required this.services,
    required this.onServiceTap,
    super.key,
  });

  final List<HomeService> services;
  final ValueChanged<HomeService> onServiceTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.large),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .1),
          blurRadius: 18,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '¿Qué necesitas hoy?',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final service in services) ...[
            HomeServiceRow(
              service: service,
              onTap: () => onServiceTap(service),
            ),
            if (service != services.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    ),
  );
}
