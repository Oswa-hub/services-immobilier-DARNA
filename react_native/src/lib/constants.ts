// Same values as the Flutter app and the Firestore rules (validListingContent).

export const GOVERNORATES = [
  'Tunis', 'Ariana', 'Ben Arous', 'Manouba', 'Nabeul', 'Zaghouan', 'Bizerte', 'Béja', 'Jendouba',
  'Le Kef', 'Siliana', 'Sousse', 'Monastir', 'Mahdia', 'Sfax', 'Kairouan', 'Kasserine', 'Sidi Bouzid',
  'Gabès', 'Médenine', 'Tataouine', 'Gafsa', 'Tozeur', 'Kébili',
] as const;

export type TransactionType = 'buy' | 'rent';
export const TRANSACTION_LABELS: Record<TransactionType, string> = { buy: 'À vendre', rent: 'À louer' };

export const PROPERTY_TYPES = {
  apartment: 'Appartement',
  villa: 'Villa',
  house: 'Maison',
  duplex: 'Duplex',
  triplex: 'Triplex',
  land: 'Terrain',
  office: 'Bureau',
  commercial: 'Local commercial',
  industrial: 'Local industriel',
} as const;
export type PropertyType = keyof typeof PROPERTY_TYPES;

export const AMENITIES = {
  parking: 'Parking',
  pool: 'Piscine',
  elevator: 'Ascenseur',
  garden: 'Jardin',
  seaView: 'Vue sur mer',
  centralHeating: 'Chauffage central',
  airConditioning: 'Climatisation',
  security: 'Sécurité',
  terrace: 'Terrasse',
  balcony: 'Balcon',
} as const;
export type Amenity = keyof typeof AMENITIES;

export const MAX_IMAGES = 10;

/** Bounds accepted by the rules for latitude / longitude (Tunisia). */
export const TUNISIA_BOUNDS = { minLat: 30, maxLat: 37.6, minLng: 7.4, maxLng: 11.7 };
export const TUNISIA_REGION = { latitude: 34.5, longitude: 9.6, latitudeDelta: 7.5, longitudeDelta: 5 };
