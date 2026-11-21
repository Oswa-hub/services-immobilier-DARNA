import '../../domain/usecases/get_current_location.dart';

/// All user-facing map strings in one place (easy to localise to French later).
class MapStrings {
  MapStrings._();

  static const loading = 'Chargement des biens…';
  static const searchArea = 'Rechercher dans cette zone';
  static const emptyTitle = 'Aucun bien dans cette zone';
  static const emptyMessage = 'Déplacez la carte ou modifiez vos filtres.';
  static const errorTitle = 'Impossible de charger les biens de cette zone';
  static const noCoordsTitle = 'Aucun de ces résultats n\'est placé sur la carte';
  static const noCoordsMessage = 'Ils restent disponibles dans la liste.';

  static const explainTitle = 'Afficher les biens près de vous ?';
  static const explainBody =
      'DARNA utilise votre position uniquement pour centrer la carte. Elle n\'est ni enregistrée ni partagée, '
      'et vous pouvez explorer la carte sans elle.';

  static String locationNotice(LocateOutcome o) => switch (o) {
        LocateOutcome.denied => 'Accès à la position refusé. Vous pouvez explorer la carte vous-même.',
        LocateOutcome.deniedForever =>
          'La position est bloquée pour DARNA. Activez-la dans les réglages, ou explorez la carte vous-même.',
        LocateOutcome.serviceDisabled =>
          'Position indisponible. Activez la localisation, ou explorez la carte vous-même.',
        LocateOutcome.error => 'Position introuvable. Réessayez, ou explorez la carte vous-même.',
        LocateOutcome.located => '',
      };
}
