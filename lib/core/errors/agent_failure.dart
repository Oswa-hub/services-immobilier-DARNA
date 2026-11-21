enum AgentFailureType {
  notSignedIn,
  profileNotFound,
  profileAlreadyExists,
  validation,
  saveFailed,
  imageUploadFailed,
  permissionDenied,
  listingsFailed,
  listingNotAllowed,
  verificationUploadFailed,
  verificationNotAllowed,
  network,
  unknown,
}

/// Every failure the Agent module can surface. [message] is the only text a
/// user ever sees: raw Firebase exception messages are never exposed (spec §15.1).
class AgentFailure implements Exception {
  const AgentFailure(this.type, {this.fieldErrors = const {}, this.detail});

  final AgentFailureType type;

  /// Field name -> message, only for [AgentFailureType.validation].
  final Map<String, String> fieldErrors;

  /// Developer-facing hint for the listing / verification guards. Safe to show.
  final String? detail;

  String get message => switch (type) {
        AgentFailureType.notSignedIn => 'Veuillez vous reconnecter.',
        AgentFailureType.profileNotFound => 'Profil professionnel introuvable.',
        AgentFailureType.profileAlreadyExists => 'Vous avez déjà un profil professionnel.',
        AgentFailureType.validation => 'Corrigez les champs indiqués.',
        AgentFailureType.saveFailed => 'Impossible d\'enregistrer vos modifications. Réessayez.',
        AgentFailureType.imageUploadFailed => 'L\'image n\'a pas pu être envoyée. Vérifiez votre connexion et réessayez.',
        AgentFailureType.permissionDenied => 'Vous n\'avez pas le droit de faire cette action.',
        AgentFailureType.listingsFailed => 'Impossible de charger vos annonces. Réessayez.',
        AgentFailureType.listingNotAllowed => detail ?? 'Cette action n\'est pas disponible pour cette annonce.',
        AgentFailureType.verificationUploadFailed => 'Vos documents n\'ont pas été envoyés. Réessayez.',
        AgentFailureType.verificationNotAllowed =>
          detail ?? 'Impossible d\'envoyer une demande de vérification pour le moment.',
        AgentFailureType.network => 'Problème de réseau. Vérifiez votre connexion et réessayez.',
        AgentFailureType.unknown => 'Une erreur est survenue. Réessayez.',
      };

  @override
  String toString() => 'AgentFailure($type${detail == null ? '' : ', $detail'})';
}
