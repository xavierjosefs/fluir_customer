import 'home_coordinate.dart';

class DestinationSearchResult {
  const DestinationSearchResult({
    required this.id,
    required this.name,
    required this.formattedAddress,
    required this.coordinate,
    required this.featureType,
    this.isMock = false,
  });

  final String id;
  final String name;
  final String formattedAddress;
  final HomeCoordinate coordinate;
  final String featureType;
  final bool isMock;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DestinationSearchResult &&
          other.id == id &&
          other.name == name &&
          other.formattedAddress == formattedAddress &&
          other.coordinate == coordinate &&
          other.featureType == featureType &&
          other.isMock == isMock;

  @override
  int get hashCode =>
      Object.hash(id, name, formattedAddress, coordinate, featureType, isMock);
}
