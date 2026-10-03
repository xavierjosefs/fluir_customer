import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/ride_models.dart';

/// One vehicle tier in the ride picker.
///
/// The row carries everything the customer needs in order to choose: the
/// vehicle, how many people fit, when it arrives, what it costs, and whether it
/// can be requested at all.
class RideOptionRow extends StatelessWidget {
  const RideOptionRow({
    required this.option,
    required this.price,
    required this.arrival,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final RideOption option;

  /// Formatted fare, or `null` when the tier cannot be requested yet.
  final String? price;

  /// Drop-off clock time, `HH:mm`.
  final String arrival;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final available = option.isAvailable;
    final timing = available
        ? '$arrival · ${option.pickupMinutes} min'
        : option.description;

    return Semantics(
      selected: selected,
      button: true,
      enabled: available,
      label: available
          ? '${option.displayName}, ${option.passengerCapacity} pasajeros, '
                'llega en ${option.pickupMinutes} minutos, '
                'llegada estimada $arrival, $price'
          : '${option.displayName}, próximamente',
      child: InkWell(
        key: Key('ride-option-${option.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandBlue.withValues(alpha: .06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: selected ? colors.onSurface : Colors.transparent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Opacity(
            opacity: available ? 1 : .55,
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  height: 62,
                  child: Image.asset(
                    option.asset,
                    fit: BoxFit.contain,
                    semanticLabel: 'Vehículo ${option.displayName}',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              option.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Icon(
                            Icons.person,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          Text(
                            '${option.passengerCapacity}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (option.badge != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        _Badge(label: option.badge!, available: available),
                      ],
                    ],
                  ),
                ),
                // An unavailable tier says so in its badge; repeating it where
                // the fare goes would only add noise.
                if (price != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    price!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.available});

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final ink = available ? AppColors.brandBlue : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.small * .5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(available ? Icons.bolt : Icons.schedule, size: 13, color: ink),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: ink, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
