import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

class DestinationSearchField extends StatelessWidget {
  const DestinationSearchField({
    required this.onTap,
    this.destinationLabel,
    super.key,
  });

  final VoidCallback onTap;
  final String? destinationLabel;

  @override
  Widget build(BuildContext context) {
    final label = destinationLabel?.trim();
    final visibleLabel = label == null || label.isEmpty
        ? '¿A dónde vas?'
        : label;
    final semanticsLabel = label == null || label.isEmpty
        ? 'Buscar destino'
        : 'Cambiar destino. Destino seleccionado: $label';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: .12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.large),
          child: SizedBox(
            height: 70,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 30,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      visibleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: label == null || label.isEmpty
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: label == null || label.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (label != null && label.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(
                      Icons.edit_location_alt_outlined,
                      color: AppColors.brandBlue,
                      size: 24,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
