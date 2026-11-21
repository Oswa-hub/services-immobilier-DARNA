import 'dart:typed_data';

import '../../../properties/domain/entities/property.dart';

/// One photo of the form. Pure Dart (no XFile) so the whole module stays
/// unit-testable. Either picked on the device ([bytes], not uploaded yet) or,
/// when editing a listing, already online ([remoteUrl], never uploaded again).
class ListingPhoto {
  const ListingPhoto({required this.id, required this.name, required this.bytes}) : remoteUrl = null;

  /// A photo the listing already has (edit mode).
  ListingPhoto.remote({required this.id, required String url})
      : name = url.split('/').last,
        bytes = Uint8List(0),
        remoteUrl = url;

  final String id;
  final String name;
  final Uint8List bytes;

  /// HTTPS URL of a photo that is already uploaded, or null for a new photo.
  final String? remoteUrl;

  bool get isRemote => remoteUrl != null;
}

/// A coordinate the USER confirmed (map tap or device position). Never invented.
class ListingCoordinates {
  const ListingCoordinates(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is ListingCoordinates && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Everything the form collects. Numbers are kept as the TEXT the user typed and
/// parsed by [ListingValidator], so the field can show exactly what was entered.
class ListingDraft {
  const ListingDraft({
    this.propertyType,
    this.transactionType,
    this.governorate,
    this.city = '',
    this.area = '',
    this.coordinates,
    this.priceText = '',
    this.surfaceText = '',
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.isStudio = false,
    this.isNewBuild = false,
    this.amenities = const {},
    this.photos = const [],
    this.title = '',
    this.description = '',
  });

  final PropertyType? propertyType;
  final TransactionType? transactionType;
  final String? governorate;
  final String city;
  final String area;
  final ListingCoordinates? coordinates;
  final String priceText;
  final String surfaceText;
  final int bedrooms;
  final int bathrooms;
  final bool isStudio;
  final bool isNewBuild;

  /// Amenity ids (see [Amenity]); stored in Firestore as a list.
  final Set<String> amenities;
  final List<ListingPhoto> photos;
  final String title;
  final String description;

  /// The form filled with an existing listing (edit mode, Module 08 B3).
  factory ListingDraft.fromProperty(Property p) {
    String number(num? v) {
      if (v == null) return '';
      return v == v.roundToDouble() ? v.round().toString() : v.toString();
    }

    return ListingDraft(
      propertyType: p.propertyType,
      transactionType: p.transactionType,
      governorate: p.governorate,
      city: p.city ?? '',
      area: p.area ?? '',
      coordinates: (p.latitude != null && p.longitude != null) ? ListingCoordinates(p.latitude!, p.longitude!) : null,
      priceText: number(p.price),
      surfaceText: number(p.surface),
      bedrooms: p.bedrooms ?? 0,
      bathrooms: p.bathrooms ?? 0,
      isStudio: p.isStudio,
      isNewBuild: p.isNewBuild,
      amenities: p.amenities.toSet(),
      photos: [
        for (var i = 0; i < p.images.length; i++) ListingPhoto.remote(id: 'existing-$i', url: p.images[i]),
      ],
      title: p.title,
      description: p.description,
    );
  }

  /// True once the user has typed / chosen anything (used for "discard?" prompts).
  bool get hasContent =>
      propertyType != null ||
      transactionType != null ||
      governorate != null ||
      city.trim().isNotEmpty ||
      area.trim().isNotEmpty ||
      coordinates != null ||
      priceText.trim().isNotEmpty ||
      surfaceText.trim().isNotEmpty ||
      amenities.isNotEmpty ||
      photos.isNotEmpty ||
      title.trim().isNotEmpty ||
      description.trim().isNotEmpty;

  ListingDraft copyWith({
    PropertyType? propertyType,
    TransactionType? transactionType,
    String? governorate,
    String? city,
    String? area,
    ListingCoordinates? coordinates,
    bool clearCoordinates = false,
    String? priceText,
    String? surfaceText,
    int? bedrooms,
    int? bathrooms,
    bool? isStudio,
    bool? isNewBuild,
    Set<String>? amenities,
    List<ListingPhoto>? photos,
    String? title,
    String? description,
  }) =>
      ListingDraft(
        propertyType: propertyType ?? this.propertyType,
        transactionType: transactionType ?? this.transactionType,
        governorate: governorate ?? this.governorate,
        city: city ?? this.city,
        area: area ?? this.area,
        coordinates: clearCoordinates ? null : (coordinates ?? this.coordinates),
        priceText: priceText ?? this.priceText,
        surfaceText: surfaceText ?? this.surfaceText,
        bedrooms: bedrooms ?? this.bedrooms,
        bathrooms: bathrooms ?? this.bathrooms,
        isStudio: isStudio ?? this.isStudio,
        isNewBuild: isNewBuild ?? this.isNewBuild,
        amenities: amenities ?? this.amenities,
        photos: photos ?? this.photos,
        title: title ?? this.title,
        description: description ?? this.description,
      );
}
