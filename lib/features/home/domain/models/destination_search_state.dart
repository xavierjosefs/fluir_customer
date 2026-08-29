import 'destination_search_result.dart';

enum DestinationSearchStatus {
  idle,
  typing,
  loading,
  results,
  noResults,
  error,
  configurationMissing,
}

class DestinationSearchState {
  const DestinationSearchState({
    this.query = '',
    this.status = DestinationSearchStatus.idle,
    this.results = const [],
    this.message,
  });

  final String query;
  final DestinationSearchStatus status;
  final List<DestinationSearchResult> results;
  final String? message;

  bool get isLoading => status == DestinationSearchStatus.loading;

  DestinationSearchState copyWith({
    String? query,
    DestinationSearchStatus? status,
    List<DestinationSearchResult>? results,
    String? message,
    bool clearMessage = false,
  }) => DestinationSearchState(
    query: query ?? this.query,
    status: status ?? this.status,
    results: results ?? this.results,
    message: clearMessage ? null : message ?? this.message,
  );
}
