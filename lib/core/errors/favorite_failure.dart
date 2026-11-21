enum FavoriteFailureType {
  /// Firestore rules refused the operation (not signed in, wrong user...).
  permissionDenied,
  network,

  /// Empty user / property id.
  invalidInput,
  unknown,
}

/// The only exception the favorites repository throws (same idea as
/// `PropertyFailure` / `AuthFailure`), so the UI never sees Firebase types.
class FavoriteFailure implements Exception {
  const FavoriteFailure(this.type);
  final FavoriteFailureType type;

  String get message => switch (type) {
        FavoriteFailureType.permissionDenied => 'Impossible de modifier les favoris. Reconnectez-vous.',
        FavoriteFailureType.network => 'Serveur injoignable. Vérifiez votre connexion et réessayez.',
        FavoriteFailureType.invalidInput => 'Ce bien ne peut pas être enregistré.',
        FavoriteFailureType.unknown => 'Une erreur est survenue avec vos favoris.',
      };

  @override
  String toString() => 'FavoriteFailure($type)';
}