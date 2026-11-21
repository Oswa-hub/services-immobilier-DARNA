import '../../../../core/constants/tunisia_governorates.dart';
import '../../../properties/domain/entities/amenity.dart';
import '../entities/listing_draft.dart';
import '../entities/property_type_rules.dart';
import '../publishing_config.dart';

enum ListingField {
  propertyType,
  transactionType,
  governorate,
  city,
  area,
  coordinates,
  price,
  surface,
  bedrooms,
  bathrooms,
  amenities,
  photos,
  title,
  description,
}

/// The wizard screens. The spec's 11 steps are grouped into 7 screens; every
/// field of the reference journey is still collected.
enum PublishStep {
  type('Type de bien', {ListingField.propertyType, ListingField.transactionType}),
  location('Localisation', {ListingField.governorate, ListingField.city, ListingField.area, ListingField.coordinates}),
  details('Prix et détails', {ListingField.price, ListingField.surface, ListingField.bedrooms, ListingField.bathrooms}),
  amenities('Équipements', {ListingField.amenities}),
  photos('Photos', {ListingField.photos}),
  description('Titre et description', {ListingField.title, ListingField.description}),
  preview('Aperçu', {});

  const PublishStep(this.label, this.fields);
  final String label;
  final Set<ListingField> fields;

  PublishStep? get next => index + 1 < PublishStep.values.length ? PublishStep.values[index + 1] : null;
  PublishStep? get previous => index > 0 ? PublishStep.values[index - 1] : null;
}

/// Pure validation (unit-tested). The UI uses it to guide the user; the Firestore
/// rules repeat the essential checks because the client is never trusted.
class ListingValidator {
  ListingValidator._();

  static final _digits = RegExp(r'^\d+$');
  static final _decimal = RegExp(r'^\d+([.,]\d+)?$');
  static final _spaces = RegExp(r'[\s\u00A0\u202F]');

  /// Whole TND amount, or null when [raw] is not a plain whole number.
  static int? parsePrice(String? raw) {
    final s = (raw ?? '').replaceAll(_spaces, '');
    return _digits.hasMatch(s) ? int.tryParse(s) : null;
  }

  /// `120`, `120.5` or `120,5`. Anything ambiguous ("1,200.5", "12a") is rejected.
  static double? parseSurface(String? raw) {
    final s = (raw ?? '').replaceAll(_spaces, '');
    if (!_decimal.hasMatch(s)) return null;
    final v = double.tryParse(s.replaceAll(',', '.'));
    return (v == null || v.isNaN || v.isInfinite) ? null : v;
  }

  static Map<ListingField, String> validate(ListingDraft d) {
    final e = <ListingField, String>{};
    final type = d.propertyType;

    if (type == null || !publishablePropertyTypes.contains(type)) {
      e[ListingField.propertyType] = 'Choisissez un type de bien.';
    }
    if (d.transactionType == null) {
      e[ListingField.transactionType] = 'Indiquez si le bien est à vendre ou à louer.';
    }

    final gov = d.governorate;
    if (gov == null || !tunisiaGovernorates.contains(gov)) {
      e[ListingField.governorate] = 'Choisissez le gouvernorat du bien.';
    }
    final city = d.city.trim();
    if (city.isEmpty) {
      e[ListingField.city] = 'Saisissez la ville.';
    } else if (city.length > PublishingConfig.cityMax) {
      e[ListingField.city] = 'Nom de ville trop long.';
    }
    if (d.area.trim().length > PublishingConfig.areaMax) {
      e[ListingField.area] = 'Nom de quartier trop long.';
    }
    final c = d.coordinates;
    if (c != null &&
        !(c.latitude >= PublishingConfig.minLat &&
            c.latitude <= PublishingConfig.maxLat &&
            c.longitude >= PublishingConfig.minLng &&
            c.longitude <= PublishingConfig.maxLng)) {
      e[ListingField.coordinates] = 'Le repère est hors de Tunisie. Déplacez-le.';
    }

    final price = parsePrice(d.priceText);
    if (price == null) {
      e[ListingField.price] = d.priceText.trim().isEmpty
          ? 'Saisissez le prix en TND.'
          : 'Saisissez un prix entier (chiffres uniquement).';
    } else if (price <= 0) {
      e[ListingField.price] = 'Le prix doit être supérieur à zéro.';
    } else if (price > PublishingConfig.maxPrice) {
      e[ListingField.price] = 'Ce prix semble trop élevé. Vérifiez-le.';
    }

    final surface = parseSurface(d.surfaceText);
    if (surface == null) {
      e[ListingField.surface] = 'Saisissez une surface valide en m².';
    } else if (surface <= 0) {
      e[ListingField.surface] = 'La surface doit être supérieure à zéro.';
    } else if (surface > PublishingConfig.maxSurface) {
      e[ListingField.surface] = 'Cette surface semble trop grande. Vérifiez-la.';
    }

    if (type != null) {
      if (type.usesBedrooms && !(type.allowsStudio && d.isStudio)) {
        if (d.bedrooms < 1) {
          e[ListingField.bedrooms] = type.allowsStudio
              ? 'Indiquez le nombre de chambres, ou cochez « studio ».'
              : 'Indiquez le nombre de chambres.';
        } else if (d.bedrooms > PublishingConfig.maxRooms) {
          e[ListingField.bedrooms] = 'Ce nombre de chambres semble trop élevé.';
        }
      }
      if (type.usesBathrooms) {
        if (type.requiresBathroom && d.bathrooms < 1) {
          e[ListingField.bathrooms] = 'Indiquez au moins une salle de bain.';
        } else if (d.bathrooms < 0 || d.bathrooms > PublishingConfig.maxRooms) {
          e[ListingField.bathrooms] = 'Ce nombre de salles de bain semble incorrect.';
        }
      }
    }

    if (d.amenities.any((a) => Amenity.tryParse(a) == null)) {
      e[ListingField.amenities] = 'Un des équipements choisis n\'est pas pris en charge.';
    }

    if (d.photos.length < PublishingConfig.minPhotos) {
      e[ListingField.photos] = 'Ajoutez au moins une photo du bien.';
    } else if (d.photos.length > PublishingConfig.maxPhotos) {
      e[ListingField.photos] = 'Vous pouvez ajouter jusqu\'à ${PublishingConfig.maxPhotos} photos.';
    }

    final title = d.title.trim();
    if (title.isEmpty) {
      e[ListingField.title] = 'Saisissez un titre pour votre annonce.';
    } else if (title.length < PublishingConfig.titleMin) {
      e[ListingField.title] = 'Titre trop court (au moins ${PublishingConfig.titleMin} caractères).';
    } else if (title.length > PublishingConfig.titleMax) {
      e[ListingField.title] = 'Titre trop long (${PublishingConfig.titleMax} caractères maximum).';
    }

    final description = d.description.trim();
    if (description.isEmpty) {
      e[ListingField.description] = 'Ajoutez une description.';
    } else if (description.length < PublishingConfig.descriptionMin) {
      e[ListingField.description] =
          'Description trop courte (au moins ${PublishingConfig.descriptionMin} caractères).';
    } else if (description.length > PublishingConfig.descriptionMax) {
      e[ListingField.description] = 'Description trop longue (${PublishingConfig.descriptionMax} caractères maximum).';
    }

    return e;
  }

  /// Errors of one wizard screen. The preview screen checks everything.
  static Map<ListingField, String> validateStep(PublishStep step, ListingDraft d) {
    final all = validate(d);
    if (step == PublishStep.preview) return all;
    return {for (final e in all.entries) if (step.fields.contains(e.key)) e.key: e.value};
  }
}
