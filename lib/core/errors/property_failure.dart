enum PropertyFailureType {
  /// Document does not exist.
  notFound,

  /// Exists but must not be shown (not published / malformed / no permission).
  unavailable,
  network,
  unknown,
}

class PropertyFailure implements Exception {
  const PropertyFailure(this.type);
  final PropertyFailureType type;

  String get message => switch (type) {
        PropertyFailureType.notFound ||
        PropertyFailureType.unavailable =>
          'Ce bien n\'est plus disponible.',
        PropertyFailureType.network => 'Impossible de charger ce bien. Vérifiez votre connexion et réessayez.',
        PropertyFailureType.unknown => 'Impossible de charger ce bien.',
      };

  @override
  String toString() => 'PropertyFailure($type)';
}
