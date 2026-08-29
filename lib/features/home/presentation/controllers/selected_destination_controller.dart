import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/destination_search_result.dart';

final selectedDestinationProvider =
    NotifierProvider<SelectedDestinationController, DestinationSearchResult?>(
      SelectedDestinationController.new,
    );

class SelectedDestinationController extends Notifier<DestinationSearchResult?> {
  @override
  DestinationSearchResult? build() => null;

  void select(DestinationSearchResult destination) => state = destination;

  void clear() => state = null;
}
