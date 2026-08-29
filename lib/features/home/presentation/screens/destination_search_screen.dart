import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/system_ui.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../data/mock/mock_home_map_data.dart';
import '../../domain/models/destination_search_result.dart';
import '../../domain/models/destination_search_state.dart';
import '../controllers/destination_search_controller.dart';

class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(destinationSearchControllerProvider);
    final controller = ref.read(destinationSearchControllerProvider.notifier);

    return AnnotatedRegion(
      value: Theme.of(context).brightness == Brightness.dark
          ? AppSystemUi.lightContent
          : AppSystemUi.darkContent,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _SearchHeader(onBack: () => context.pop()),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: _DestinationTextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  isLoading: state.isLoading,
                  onChanged: controller.queryChanged,
                  onSubmitted: controller.submit,
                  onClear: () {
                    _textController.clear();
                    controller.queryChanged('');
                    _focusNode.requestFocus();
                  },
                ),
              ),
              Expanded(
                child: _SearchContent(
                  state: state,
                  onRetry: controller.retry,
                  onSelect: (destination) => context.pop(destination),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '¿A dónde vas?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    ),
  );
}

class _DestinationTextField extends StatelessWidget {
  const _DestinationTextField({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      textField: true,
      label: 'Buscar dirección o lugar',
      child: TextField(
        key: const ValueKey('destination-search-input'),
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.streetAddress,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Buscar dirección o lugar',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              if (controller.text.isNotEmpty)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Limpiar búsqueda',
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          filled: true,
          fillColor: colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: BorderSide(color: colors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: BorderSide(color: colors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(
              color: AppColors.brandBlue,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchContent extends StatelessWidget {
  const _SearchContent({
    required this.state,
    required this.onRetry,
    required this.onSelect,
  });

  final DestinationSearchState state;
  final VoidCallback onRetry;
  final ValueChanged<DestinationSearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case DestinationSearchStatus.idle:
        return _ShortcutList(onSelect: onSelect);
      case DestinationSearchStatus.typing:
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Escribe al menos 3 caracteres para buscar.'),
              ),
            ),
            Expanded(child: _ShortcutList(onSelect: onSelect)),
          ],
        );
      case DestinationSearchStatus.loading:
        return const _InlineStatus(
          icon: Icons.travel_explore,
          title: 'Buscando destinos…',
          message: 'Estamos consultando ubicaciones en República Dominicana.',
        );
      case DestinationSearchStatus.results:
        return _ResultsList(results: state.results, onSelect: onSelect);
      case DestinationSearchStatus.noResults:
        return const _InlineStatus(
          icon: Icons.location_off_outlined,
          title: 'No encontramos resultados',
          message: 'Prueba con otra dirección o sector.',
        );
      case DestinationSearchStatus.error:
        return _SearchError(
          title: 'No pudimos buscar lugares',
          message:
              state.message ?? 'Revisa tu conexión e inténtalo nuevamente.',
          onRetry: onRetry,
        );
      case DestinationSearchStatus.configurationMissing:
        return _SearchError(
          title: 'Búsqueda no configurada',
          message:
              state.message ??
              'Agrega ACCESS_TOKEN para habilitar la búsqueda de destinos.',
          onRetry: onRetry,
          retryLabel: 'Reintentar',
        );
    }
  }
}

class _ShortcutList extends StatelessWidget {
  const _ShortcutList({required this.onSelect});

  final ValueChanged<DestinationSearchResult> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      AppSpacing.xxl,
    ),
    children: [
      Text('Ubicación', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      _DestinationRow(
        icon: Icons.my_location,
        destination: MockHomeMapData.currentLocationDestination,
        onTap: () => onSelect(MockHomeMapData.currentLocationDestination),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Lugares guardados', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: AppSpacing.xs),
      ...MockHomeMapData.savedDestinations.map(
        (destination) => _DestinationRow(
          icon: destination.id == 'mock-home'
              ? Icons.home_outlined
              : Icons.business_outlined,
          destination: destination,
          onTap: () => onSelect(destination),
        ),
      ),
    ],
  );
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.onSelect});

  final List<DestinationSearchResult> results;
  final ValueChanged<DestinationSearchResult> onSelect;

  @override
  Widget build(BuildContext context) => ListView.separated(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      AppSpacing.xxl,
    ),
    itemCount: results.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final result = results[index];
      return _DestinationRow(
        icon: Icons.location_on_outlined,
        destination: result,
        onTap: () => onSelect(result),
      );
    },
  );
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.icon,
    required this.destination,
    required this.onTap,
  });

  final IconData icon;
  final DestinationSearchResult destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${destination.name}. ${destination.formattedAddress}',
    child: ListTile(
      minTileHeight: 64,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.brandBlue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Icon(icon, color: AppColors.brandBlue),
      ),
      title: Text(destination.name),
      subtitle: Text(
        destination.formattedAddress,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '$title. $message',
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SearchError extends StatelessWidget {
  const _SearchError({
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Reintentar',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: '$title. $message',
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_outlined,
                size: 44,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ),
        ),
      ),
    ),
  );
}
