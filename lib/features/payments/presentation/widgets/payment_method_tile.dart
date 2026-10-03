import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/models/payment_method.dart';
import 'payment_method_brand_mark.dart';

/// One saved card: brand, last four digits, expiry and default state.
///
/// Nothing beyond these gateway-provided fields is ever rendered.
class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    required this.method,
    required this.isBusy,
    required this.onSetDefault,
    required this.onRemove,
    super.key,
  });

  final PaymentMethod method;
  final bool isBusy;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      label:
          '${method.displayBrand} terminada en ${method.last4}'
          '${method.isDefault ? ', predeterminada' : ''}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: method.isDefault ? AppColors.brandBlue : colors.outline,
            width: method.isDefault ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            PaymentMethodBrandMark.forMethod(method),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.maskedLabel,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    [
                      if (method.label != null) method.label!,
                      method.isExpired
                          ? 'Venció ${method.formattedExpiry}'
                          : 'Vence ${method.formattedExpiry}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: method.isExpired
                          ? AppColors.error
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  if (method.isDefault) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const _DefaultBadge(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (isBusy)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              _MethodMenu(
                canSetDefault: !method.isDefault,
                onSetDefault: onSetDefault,
                onRemove: onRemove,
                methodLabel: method.maskedLabel,
              ),
          ],
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.xxs / 2,
    ),
    decoration: BoxDecoration(
      color: AppColors.brandBlue.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(AppRadius.small),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 14, color: AppColors.brandBlue),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          'Predeterminada',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.brandBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _MethodMenu extends StatelessWidget {
  const _MethodMenu({
    required this.canSetDefault,
    required this.onSetDefault,
    required this.onRemove,
    required this.methodLabel,
  });

  final bool canSetDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;
  final String methodLabel;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_MethodAction>(
    tooltip: 'Opciones de $methodLabel',
    icon: const Icon(Icons.more_vert),
    onSelected: (action) => switch (action) {
      _MethodAction.setDefault => onSetDefault(),
      _MethodAction.remove => _confirmRemoval(context),
    },
    itemBuilder: (context) => [
      if (canSetDefault)
        const PopupMenuItem(
          value: _MethodAction.setDefault,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.star_outline),
            title: Text('Establecer como predeterminada'),
          ),
        ),
      const PopupMenuItem(
        value: _MethodAction.remove,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.delete_outline, color: AppColors.error),
          title: Text('Eliminar', style: TextStyle(color: AppColors.error)),
        ),
      ),
    ],
  );

  Future<void> _confirmRemoval(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar esta tarjeta?'),
        content: Text(
          'Dejarás de poder pagar con $methodLabel. Puedes volver a '
          'agregarla cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      onRemove();
    }
  }
}

enum _MethodAction { setDefault, remove }
