/// Canonical amenity identifiers. The enum NAME is what is stored in Firestore
/// (`amenities: ["pool", "seaView"]`) and what search filters on, so publishing
/// (Module 08), search (Module 04) and details (Module 05) all agree.
enum Amenity {
  parking('Parking'),
  pool('Piscine'),
  elevator('Ascenseur'),
  garden('Jardin'),
  seaView('Vue sur mer'),
  centralHeating('Chauffage central'),
  airConditioning('Climatisation'),
  security('Sécurité'),
  terrace('Terrasse'),
  balcony('Balcon');

  const Amenity(this.label);

  final String label;

  /// Value stored in Firestore.
  String get id => name;

  static Amenity? tryParse(String? v) {
    for (final a in Amenity.values) {
      if (a.name == v) return a;
    }
    return null;
  }
}
