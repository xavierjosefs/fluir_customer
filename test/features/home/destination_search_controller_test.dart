import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluir_customer/features/home/data/repositories/mapbox_geocoding_repository.dart';
import 'package:fluir_customer/features/home/domain/models/destination_search_result.dart';
import 'package:fluir_customer/features/home/domain/models/destination_search_state.dart';
import 'package:fluir_customer/features/home/domain/models/home_coordinate.dart';
import 'package:fluir_customer/features/home/presentation/controllers/destination_search_controller.dart';

void main() {
  test('queries shorter than three characters do not call geocoding', () async {
    final repository = _FakeGeocodingRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      destinationSearchControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    container
        .read(destinationSearchControllerProvider.notifier)
        .queryChanged('Av');
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(repository.queries, isEmpty);
    expect(
      container.read(destinationSearchControllerProvider).status,
      DestinationSearchStatus.typing,
    );
  });

  test('submitted query returns real repository results', () async {
    final repository = _FakeGeocodingRepository(
      results: const [
        DestinationSearchResult(
          id: 'address.1',
          name: 'Avenida 27 de Febrero',
          formattedAddress: 'Santo Domingo, República Dominicana',
          coordinate: HomeCoordinate(latitude: 18.47, longitude: -69.93),
          featureType: 'street',
        ),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      destinationSearchControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(destinationSearchControllerProvider.notifier)
        .submit('27 de Febrero');

    final state = container.read(destinationSearchControllerProvider);
    expect(repository.queries, ['27 de Febrero']);
    expect(state.status, DestinationSearchStatus.results);
    expect(state.results.single.name, 'Avenida 27 de Febrero');
  });

  test('empty results and failures expose recoverable states', () async {
    final emptyRepository = _FakeGeocodingRepository();
    final emptyContainer = _container(emptyRepository);
    addTearDown(emptyContainer.dispose);
    final emptySubscription = emptyContainer.listen(
      destinationSearchControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(emptySubscription.close);

    await emptyContainer
        .read(destinationSearchControllerProvider.notifier)
        .submit('Sector que no existe');
    expect(
      emptyContainer.read(destinationSearchControllerProvider).status,
      DestinationSearchStatus.noResults,
    );

    final failingRepository = _FakeGeocodingRepository(shouldFail: true);
    final failingContainer = _container(failingRepository);
    addTearDown(failingContainer.dispose);
    final failingSubscription = failingContainer.listen(
      destinationSearchControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(failingSubscription.close);

    await failingContainer
        .read(destinationSearchControllerProvider.notifier)
        .submit('Santo Domingo');
    expect(
      failingContainer.read(destinationSearchControllerProvider).status,
      DestinationSearchStatus.error,
    );
  });

  test('repeated current query does not issue a duplicate request', () async {
    final repository = _FakeGeocodingRepository(
      results: const [
        DestinationSearchResult(
          id: 'place.sd',
          name: 'Santo Domingo',
          formattedAddress: 'Distrito Nacional, República Dominicana',
          coordinate: HomeCoordinate(latitude: 18.48, longitude: -69.93),
          featureType: 'place',
        ),
      ],
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      destinationSearchControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      destinationSearchControllerProvider.notifier,
    );

    await controller.submit('Santo Domingo');
    await controller.submit('Santo Domingo');

    expect(repository.queries, ['Santo Domingo']);
    expect(
      container.read(destinationSearchControllerProvider).status,
      DestinationSearchStatus.results,
    );
  });

  test('stale geocoding results cannot replace a newer query', () async {
    final repository = _ControlledGeocodingRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(
      destinationSearchControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    final controller = container.read(
      destinationSearchControllerProvider.notifier,
    );

    final first = controller.submit('Santo Domingo');
    final second = controller.submit('Santiago');

    repository.complete(
      'Santiago',
      const DestinationSearchResult(
        id: 'place.santiago',
        name: 'Santiago',
        formattedAddress: 'Santiago, República Dominicana',
        coordinate: HomeCoordinate(latitude: 19.45, longitude: -70.69),
        featureType: 'place',
      ),
    );
    await second;
    expect(
      container.read(destinationSearchControllerProvider).results.single.name,
      'Santiago',
    );

    repository.complete(
      'Santo Domingo',
      const DestinationSearchResult(
        id: 'place.santo-domingo',
        name: 'Santo Domingo',
        formattedAddress: 'Distrito Nacional, República Dominicana',
        coordinate: HomeCoordinate(latitude: 18.48, longitude: -69.93),
        featureType: 'place',
      ),
    );
    await first;

    expect(
      container.read(destinationSearchControllerProvider).results.single.name,
      'Santiago',
    );
  });

  test('missing token prevents a network repository call', () async {
    final repository = _FakeGeocodingRepository();
    final container = ProviderContainer(
      overrides: [
        mapboxAccessTokenProvider.overrideWithValue(''),
        destinationGeocodingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      destinationSearchControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container
        .read(destinationSearchControllerProvider.notifier)
        .submit('Santo Domingo');

    expect(repository.queries, isEmpty);
    expect(
      container.read(destinationSearchControllerProvider).status,
      DestinationSearchStatus.configurationMissing,
    );
  });
}

ProviderContainer _container(DestinationGeocodingRepository repository) =>
    ProviderContainer(
      overrides: [
        mapboxAccessTokenProvider.overrideWithValue('pk.test'),
        destinationGeocodingRepositoryProvider.overrideWithValue(repository),
      ],
    );

class _FakeGeocodingRepository implements DestinationGeocodingRepository {
  _FakeGeocodingRepository({this.results = const [], this.shouldFail = false});

  final List<DestinationSearchResult> results;
  final bool shouldFail;
  final List<String> queries = [];

  @override
  Future<List<DestinationSearchResult>> search({
    required String query,
    required String accessToken,
    HomeCoordinate? proximity,
  }) async {
    queries.add(query);
    if (shouldFail) {
      throw const MapboxGeocodingException('offline');
    }
    return results;
  }
}

class _ControlledGeocodingRepository implements DestinationGeocodingRepository {
  final Map<String, Completer<List<DestinationSearchResult>>> _pending = {};

  @override
  Future<List<DestinationSearchResult>> search({
    required String query,
    required String accessToken,
    HomeCoordinate? proximity,
  }) {
    final completer = Completer<List<DestinationSearchResult>>();
    _pending[query] = completer;
    return completer.future;
  }

  void complete(String query, DestinationSearchResult result) {
    _pending[query]!.complete([result]);
  }
}
