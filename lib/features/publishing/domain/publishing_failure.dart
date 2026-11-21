import 'services/listing_validator.dart';

enum PublishingFailureType {
  notAuthenticated,
  notAllowed,
  invalidData,
  uploadFailed,
  network,
  permissionDenied,
  unknown,
}

/// The only exception the publishing module throws to the UI (same convention as
/// PropertyFailure / FavoriteFailure): technical errors never reach the screen.
class PublishingFailure implements Exception {
  const PublishingFailure(
    this.type, {
    this.fieldErrors = const {},
    this.failedPhotoIds = const {},
  });

  final PublishingFailureType type;

  /// Set for [PublishingFailureType.invalidData].
  final Map<ListingField, String> fieldErrors;

  /// Set for [PublishingFailureType.uploadFailed]: which photos to retry.
  final Set<String> failedPhotoIds;

  String get message => switch (type) {
        PublishingFailureType.notAuthenticated => 'Connectez-vous pour publier un bien.',
        PublishingFailureType.notAllowed => 'Votre compte ne peut pas publier d\'annonces.',
        PublishingFailureType.invalidData => 'Certaines informations doivent être corrigées avant l\'envoi.',
        PublishingFailureType.uploadFailed =>
          failedPhotoIds.length > 1
              ? '${failedPhotoIds.length} photos could not be uploaded. Please try again.'
              : 'Une photo n\'a pas pu être envoyée. Réessayez.',
        PublishingFailureType.network => 'Une erreur est survenue. Vérifiez votre connexion et réessayez.',
        PublishingFailureType.permissionDenied => 'Vous n\'avez pas le droit de publier cette annonce.',
        PublishingFailureType.unknown => 'Une erreur est survenue pendant la publication. Réessayez.',
      };

  @override
  String toString() => 'PublishingFailure($type)';
}
