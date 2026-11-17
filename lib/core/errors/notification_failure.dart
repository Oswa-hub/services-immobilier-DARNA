enum NotificationFailureType {
  /// Firestore rules refused the operation (signed out, not the recipient...).
  permissionDenied,
  network,

  /// A required Firestore index is still building / missing.
  indexMissing,
  unknown,
}

/// The only exception the notification repository throws, so the UI never
/// sees Firebase types (same idea as `FavoriteFailure`).
class NotificationFailure implements Exception {
  const NotificationFailure(this.type);
  final NotificationFailureType type;

  String get message => switch (type) {
        NotificationFailureType.permissionDenied => 'Session expirée. Veuillez vous reconnecter.',
        NotificationFailureType.network => 'Connexion impossible. Vérifiez votre réseau et réessayez.',
        NotificationFailureType.indexMissing => 'Les notifications sont en cours de préparation. Réessayez dans un instant.',
        NotificationFailureType.unknown => 'Une erreur est survenue. Veuillez réessayer.',
      };

  @override
  String toString() => 'NotificationFailure($type)';
}
