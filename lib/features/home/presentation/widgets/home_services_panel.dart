import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/home_service.dart';
import 'home_service_row.dart';

enum HomeServicesSheetMode { collapsed, medium, expanded }

class HomeServicesPanel extends StatelessWidget {
  const HomeServicesPanel({
    required this.services,
    required this.onServiceTap,
    required this.scrollController,
    required this.onHeaderTap,
    required this.mode,
    super.key,
  });

  final List<HomeService> services;
  final ValueChanged<HomeService> onServiceTap;
  final ScrollController scrollController;
  final VoidCallback onHeaderTap;
  final HomeServicesSheetMode mode;

  bool get isFullyExpanded => mode == HomeServicesSheetMode.expanded;
  bool get isCollapsed => mode == HomeServicesSheetMode.collapsed;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 8,
    shadowColor: Colors.black.withValues(alpha: .1),
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppRadius.large),
    ),
    child: SafeArea(
      top: isFullyExpanded,
      bottom: false,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          isFullyExpanded ? AppSpacing.lg : AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Semantics(
                button: true,
                label: 'Panel de servicios. Toca para expandir.',
                child: InkWell(
                  key: const ValueKey('home-services-sheet-handle'),
                  onTap: onHeaderTap,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isFullyExpanded ? AppSpacing.lg : AppSpacing.md),
            InkWell(
              onTap: onHeaderTap,
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  '¿Qué necesitas hoy?',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SizedBox(height: isFullyExpanded ? AppSpacing.lg : AppSpacing.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Column(
                key: ValueKey(mode),
                children: [
                  for (final service
                      in isCollapsed
                          ? services.where(
                              (service) =>
                                  service.availability ==
                                  HomeServiceAvailability.available,
                            )
                          : services) ...[
                    isFullyExpanded
                        ? HomeExpandedServiceCard(
                            service: service,
                            onTap: () => onServiceTap(service),
                          )
                        : HomeServiceRow(
                            service: service,
                            onTap: () => onServiceTap(service),
                          ),
                    if (service != services.last)
                      SizedBox(
                        height: isFullyExpanded ? AppSpacing.md : AppSpacing.sm,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
