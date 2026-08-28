import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';

class DestinationSearchField extends StatelessWidget {
  const DestinationSearchField({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Buscar destino',
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.large),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.large),
        child: const SizedBox(
          height: 70,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.search, color: AppColors.textSecondary, size: 30),
                SizedBox(width: AppSpacing.md),
                Text(
                  '¿A dónde vas?',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
