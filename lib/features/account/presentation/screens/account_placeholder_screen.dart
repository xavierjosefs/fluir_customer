import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_controller.dart';

class AccountPlaceholderScreen extends ConsumerWidget {
  const AccountPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(themeControllerProvider) == ThemeMode.dark;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          116,
        ),
        children: [
          Text('Cuenta', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.outline),
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.brandBlue.withValues(alpha: .15),
                  foregroundColor: AppColors.brandBlue,
                  child: const Text(
                    'FD',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Federico De la Cruz',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'federico.delacruz@email.com',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '+1 809-555-1234',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: 'PREFERENCIAS',
            child: Column(
              children: [
                _ThemeRow(
                  value: darkMode,
                  onChanged: ref
                      .read(themeControllerProvider.notifier)
                      .setDarkMode,
                ),
                const Divider(height: 1),
                _AccountRow(
                  icon: Icons.notifications_none,
                  title: 'Notificaciones',
                  subtitle: 'Gestiona tus notificaciones',
                  onTap: () => _showInfo(
                    context,
                    'Notificaciones',
                    'Viajes, recordatorios y promociones se configuran localmente.',
                  ),
                ),
                const Divider(height: 1),
                _AccountRow(
                  key: const ValueKey('account-payment-methods-row'),
                  icon: Icons.credit_card_outlined,
                  title: 'Métodos de pago',
                  subtitle: 'Tarjetas guardadas para tus viajes',
                  onTap: () => context.push(AppRoutes.paymentMethods),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: 'CUENTA',
            child: Column(
              children: [
                _AccountRow(
                  icon: Icons.person_outline,
                  title: 'Perfil',
                  subtitle: 'Información personal',
                  onTap: () => _showInfo(
                    context,
                    'Perfil',
                    'Federico De la Cruz\nfederico.delacruz@email.com\n'
                        '+1 809-555-1234',
                  ),
                ),
                const Divider(height: 1),
                _AccountRow(
                  icon: Icons.lock_outline,
                  title: 'Seguridad',
                  subtitle: 'Contraseña y seguridad',
                  onTap: () => _showInfo(
                    context,
                    'Seguridad',
                    'Opciones de seguridad disponibles en esta versión de demostración.',
                  ),
                ),
                const Divider(height: 1),
                _AccountRow(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacidad',
                  subtitle: 'Controla tu información',
                  onTap: () => _showInfo(
                    context,
                    'Privacidad',
                    'Usamos tu ubicación solo para preparar tus viajes.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _Section(
            title: 'AYUDA Y SOPORTE',
            child: Column(
              children: [
                _AccountRow(
                  icon: Icons.help_outline,
                  title: 'Centro de ayuda',
                  subtitle: 'Preguntas frecuentes',
                  onTap: () => _showInfo(
                    context,
                    'Centro de ayuda',
                    'Encuentra respuestas a las preguntas más frecuentes.',
                  ),
                ),
                const Divider(height: 1),
                _AccountRow(
                  icon: Icons.chat_bubble_outline,
                  title: 'Contáctanos',
                  subtitle: 'Estamos aquí para ayudarte',
                  onTap: () => _showInfo(
                    context,
                    'Contáctanos',
                    'Nuestro equipo está disponible para ayudarte.',
                  ),
                ),
                const Divider(height: 1),
                _AccountRow(
                  icon: Icons.info_outline,
                  title: 'Acerca de Fluir',
                  subtitle: 'Versión 1.0.0',
                  onTap: () => _showInfo(
                    context,
                    'Acerca de Fluir',
                    'Fluir Customer · Prototipo 1.0.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text(
              'Cerrar sesión',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  static void _showInfo(BuildContext context, String title, String body) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(body),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  static void _confirmLogout(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: const Text('Podrás volver a ingresar cuando quieras.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.go(AppRoutes.onboarding);
          },
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    ],
  );
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.dark_mode_outlined),
    title: const Text('Modo oscuro'),
    subtitle: const Text('Cambiar entre apariencia clara y oscura'),
    trailing: Switch.adaptive(value: value, onChanged: onChanged),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.brandBlue),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
