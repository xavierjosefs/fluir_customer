import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../app/system_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../data/mock/mock_home_map_data.dart';
import '../../domain/models/home_service.dart';
import '../home_providers.dart';
import '../widgets/destination_search_field.dart';
import '../widgets/fluir_map.dart';
import '../widgets/home_header.dart';
import '../widgets/home_services_panel.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({this.mapSurfaceBuilder, super.key});

  final HomeMapSurfaceBuilder? mapSurfaceBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(nearbyVehiclesProvider);
    final services = ref.watch(homeServicesProvider);
    final navigationInset =
        FluirAppShell.navigationHeight + MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.darkContent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FluirMap(
            camera: MockHomeMapData.santoDomingoCamera,
            pickup: MockHomeMapData.pickupLocation,
            vehicles: vehicles,
            surfaceBuilder: mapSurfaceBuilder,
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeHeader(
                    onNotificationsTap: () => _showNotifications(context),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DestinationSearchField(
                    onTap: () => _showDestinationSearch(context),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: navigationInset,
            child: HomeServicesPanel(
              services: services,
              onServiceTap: (service) => _handleServiceTap(context, service),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 40,
              color: AppColors.brandBlue,
            ),
            SizedBox(height: AppSpacing.sm),
            Text('Notificaciones'),
            SizedBox(height: AppSpacing.xs),
            Text('Todavía no tienes notificaciones.'),
          ],
        ),
      ),
    ),
  );

  void _showDestinationSearch(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buscar destino',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                const _DestinationOption(
                  icon: Icons.my_location,
                  label: 'Mi ubicación actual',
                ),
                const _DestinationOption(
                  icon: Icons.home_outlined,
                  label: 'Casa',
                ),
                const _DestinationOption(
                  icon: Icons.business_outlined,
                  label: 'Trabajo',
                ),
                const _DestinationOption(
                  icon: Icons.location_on_outlined,
                  label: 'Centro Olímpico',
                ),
              ],
            ),
          ),
        ),
      );

  void _handleServiceTap(BuildContext context, HomeService service) {
    final isAvailable =
        service.availability == HomeServiceAvailability.available;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isAvailable
                    ? 'Selección de destino y viaje estará disponible en la siguiente fase.'
                    : '${service.title} estará disponible próximamente. Estamos preparando esta experiencia para Fluir.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationOption extends StatelessWidget {
  const _DestinationOption({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppColors.brandBlue),
    title: Text(label),
    onTap: () => Navigator.of(context).pop(),
  );
}
