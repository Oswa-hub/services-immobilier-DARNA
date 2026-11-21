/// Spec §11.3 error codes.
enum VerificationFailureType {
  unauthenticated,
  permissionDenied,
  notFound,
  invalidTargetType,
  validationFailed,
  invalidStatusTransition,
  alreadyReviewed,
  documentUploadFailed,
  documentAccessFailed,
  network,
  unknown,
}

/// The only text a user ever sees. Raw Firebase / server messages are never
/// exposed (spec §18).
class VerificationFailure implements Exception {
  const VerificationFailure(this.type, {this.fieldErrors = const {}, this.detail});

  final VerificationFailureType type;

  /// Field key -> message, only for [VerificationFailureType.validationFailed].
  final Map<String, String> fieldErrors;

  /// Safe, human-readable hint (never a raw exception message).
  final String? detail;

  String get message => switch (type) {
        VerificationFailureType.unauthenticated => 'Veuillez vous reconnecter.',
        VerificationFailureType.permissionDenied => 'Vous n\'avez pas le droit de faire cette action.',
        VerificationFailureType.notFound => 'Cette demande de vérification est introuvable.',
        VerificationFailureType.invalidTargetType => 'Ce type de vérification n\'est pas pris en charge.',
        VerificationFailureType.validationFailed => detail ?? 'Veuillez remplir tous les champs obligatoires.',
        VerificationFailureType.invalidStatusTransition =>
          detail ?? 'Cette action n\'est pas possible dans le statut actuel.',
        VerificationFailureType.alreadyReviewed => 'Cette demande a déjà été traitée. Actualisez la page.',
        VerificationFailureType.documentUploadFailed => 'Le document n\'a pas pu être envoyé. Réessayez.',
        VerificationFailureType.documentAccessFailed => 'Impossible d\'ouvrir le document. Réessayez.',
        VerificationFailureType.network => 'Serveur injoignable. Vérifiez votre connexion et réessayez.',
        VerificationFailureType.unknown => 'Une erreur est survenue. Réessayez.',
      };

  @override
  String toString() => 'VerificationFailure($type${detail == null ? '' : ', $detail'})';
}
