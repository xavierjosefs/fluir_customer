import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_environment.dart';
import '../../data/repositories/mapbox_geocoding_repository.dart';
import '../../domain/models/destination_search_state.dart';
import 'home_location_controller.dart';

final mapboxAccessTokenProvider = Provider<String>(
  (ref) => AppEnvironment.mapboxAccessToken,
);

final destinationGeocodingRepositoryProvider =
    Provider<DestinationGeocodingRepository>((ref) {
      final repository = MapboxGeocodingRepository();
      ref.onDispose(repository.dispose);
      return repository;
    });

final destinationSearchControllerProvider =
    NotifierProvider.autoDispose<
      DestinationSearchController,
      DestinationSearchState
    >(DestinationSearchController.new);

class DestinationSearchController extends Notifier<DestinationSearchState> {
  static const minimumQueryLength = 3;
  static const debounceDuration = Duration(milliseconds: 400);

  Timer? _debounce;
  int _requestGeneration = 0;
  String? _activeQuery;
  String? _lastCompletedQuery;

  @override
  DestinationSearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _requestGeneration++;
    });
    return const DestinationSearchState();
  }

  void queryChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();
    _requestGeneration++;

    if (query.isEmpty) {
      _activeQuery = null;
      state = const DestinationSearchState();
      return;
    }

    if (query.length < minimumQueryLength) {
      _activeQuery = null;
      state = DestinationSearchState(
        query: query,
        status: DestinationSearchStatus.typing,
      );
      return;
    }

    if (_hasCurrentResultFor(query)) {
      return;
    }

    state = DestinationSearchState(
      query: query,
      status: DestinationSearchStatus.typing,
    );
    _debounce = Timer(debounceDuration, () => unawaited(_search(query)));
  }

  Future<void> submit(String value) async {
    final query = value.trim();
    _debounce?.cancel();
    _requestGeneration++;
    if (query.isEmpty) {
      state = const DestinationSearchState();
      return;
    }
    if (_hasCurrentResultFor(query)) {
      return;
    }
    await _search(query);
  }

  Future<void> retry() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      return;
    }
    _requestGeneration++;
    await _search(query);
  }

  Future<void> _search(String query) async {
    final accessToken = ref.read(mapboxAccessTokenProvider);
    if (accessToken.isEmpty) {
      state = DestinationSearchState(
        query: query,
        status: DestinationSearchStatus.configurationMissing,
        message: 'Agrega ACCESS_TOKEN para habilitar la búsqueda de destinos.',
      );
      return;
    }

    if (_activeQuery == query && state.isLoading) {
      return;
    }

    _activeQuery = query;
    final requestGeneration = ++_requestGeneration;
    state = DestinationSearchState(
      query: query,
      status: DestinationSearchStatus.loading,
    );

    try {
      final results = await ref
          .read(destinationGeocodingRepositoryProvider)
          .search(
            query: query,
            accessToken: accessToken,
            proximity: ref.read(homeLocationControllerProvider).coordinate,
          );
      if (requestGeneration != _requestGeneration) {
        return;
      }
      state = DestinationSearchState(
        query: query,
        status: results.isEmpty
            ? DestinationSearchStatus.noResults
            : DestinationSearchStatus.results,
        results: results,
      );
      _lastCompletedQuery = query;
    } catch (_) {
      if (requestGeneration != _requestGeneration) {
        return;
      }
      state = DestinationSearchState(
        query: query,
        status: DestinationSearchStatus.error,
        message: 'Revisa tu conexión e inténtalo nuevamente.',
      );
    } finally {
      if (_activeQuery == query && requestGeneration == _requestGeneration) {
        _activeQuery = null;
      }
    }
  }

  bool _hasCurrentResultFor(String query) =>
      _lastCompletedQuery == query &&
      (state.status == DestinationSearchStatus.results ||
          state.status == DestinationSearchStatus.noResults);
}
