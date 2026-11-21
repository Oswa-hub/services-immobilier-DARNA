import '../../../properties/domain/entities/property.dart';

/// Types offered in the form (`other` exists only for legacy documents).
const publishablePropertyTypes = [
  PropertyType.apartment,
  PropertyType.villa,
  PropertyType.house,
  PropertyType.duplex,
  PropertyType.triplex,
  PropertyType.land,
  PropertyType.office,
  PropertyType.commercial,
  PropertyType.industrial,
];

extension PublishPropertyType on PropertyType {
  String get label => switch (this) {
        PropertyType.apartment => 'Appartement',
        PropertyType.villa => 'Villa',
        PropertyType.house => 'Maison',
        PropertyType.duplex => 'Duplex',
        PropertyType.triplex => 'Triplex',
        PropertyType.land => 'Terrain',
        PropertyType.office => 'Bureau',
        PropertyType.commercial => 'Local commercial',
        PropertyType.industrial => 'Local industriel',
        PropertyType.other => 'Autre',
      };

  /// Residential types have bedrooms; land / office / shops do not (spec §3 step 6:
  /// "the interface must handle a non-applicable field clearly").
  bool get usesBedrooms => switch (this) {
        PropertyType.apartment ||
        PropertyType.villa ||
        PropertyType.house ||
        PropertyType.duplex ||
        PropertyType.triplex =>
          true,
        _ => false,
      };

  bool get usesBathrooms => usesBedrooms || this == PropertyType.office || this == PropertyType.commercial;

  /// Bathrooms are mandatory (>= 1) only for residential types.
  bool get requiresBathroom => usesBedrooms;

  /// A studio is an apartment flagged `isStudio`, NOT "0 bedrooms" (see Property).
  bool get allowsStudio => this == PropertyType.apartment;
}

extension PublishTransactionType on TransactionType {
  String get label => this == TransactionType.buy ? 'À vendre' : 'À louer';
}
