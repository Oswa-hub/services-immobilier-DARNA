enum DiscoveryFailureType { network, permissionDenied, unknown }

/// Error surfaced by the discovery data layer. Never carries raw Firebase text.
class DiscoveryFailure implements Exception {
  const DiscoveryFailure(this.type);
  final DiscoveryFailureType type;

  String get message => switch (type) {
        DiscoveryFailureType.network => 'Impossible de charger les biens. Vérifiez votre connexion et réessayez.',
        DiscoveryFailureType.permissionDenied => 'Vous n\'avez pas accès à ces annonces pour le moment.',
        DiscoveryFailureType.unknown => 'Une erreur est survenue pendant le chargement des biens.',
      };

  @override
  String toString() => 'DiscoveryFailure($type)';
}
