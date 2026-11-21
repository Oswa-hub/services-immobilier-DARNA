import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/search_enums.dart';

/// All user-facing search strings in one place (easy to localise to French later).
class SearchStrings {
  SearchStrings._();

  static const emptyTitle = 'Aucun bien ne correspond à votre recherche';
  static const emptyMessage = 'Modifiez les filtres ou élargissez la zone.';
  static const emptyFeedTitle = 'Aucune annonce pour le moment';
  static const emptyFeedMessage = 'Les nouveaux biens apparaîtront ici bientôt.';
  static const errorTitle = 'Impossible de charger la recherche';
  static const errorFallback = 'Vérifiez votre connexion et réessayez.';
}

extension ListingTabLabel on ListingTab {
  String get label => switch (this) {
        ListingTab.all => 'Toutes',
        ListingTab.buy => 'Acheter',
        ListingTab.rent => 'Louer',
        ListingTab.newBuild => 'Neuf',
      };
}

extension PropertyTypeLabel on PropertyType {
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
}

/// Types offered in the filter panel (everything except the catch-all).
final searchablePropertyTypes = [
  for (final t in PropertyType.values)
    if (t != PropertyType.other) t,
];
