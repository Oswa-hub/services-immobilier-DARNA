import '../../../../core/constants/tunisia_governorates.dart';
import '../../../../core/utils/validators.dart';
import '../entities/agent_profile.dart';

/// Pure validation of the professional profile (spec §10.1). The same rules
/// drive the Flutter form (usability) and the use cases (defence in depth).
/// Firestore rules and Cloud Functions must repeat them (spec §10.1, §12).
class AgentProfileValidator {
  AgentProfileValidator._();

  static const nameMin = 3;
  static const nameMax = 80;
  static const descriptionMin = 20;
  static const descriptionMax = 600;
  static const addressMax = 160;
  static const websiteMax = 200;
  static const maxYears = 60;
  static const maxServiceAreas = 10;
  static const maxLanguages = 6;

  static const supportedLanguages = ['Arabe', 'Français', 'Anglais', 'Italien', 'Allemand', 'Espagnol'];

  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Le nom professionnel est obligatoire';
    if (t.length < nameMin) return 'Nom trop court';
    if (t.length > nameMax) return '$nameMax caractères maximum';
    return null;
  }

  /// Required only for agency profiles.
  static String? agencyName(String? v, {required bool isAgency}) {
    final t = v?.trim() ?? '';
    if (!isAgency) return null;
    if (t.isEmpty) return 'Le nom de l\'agence est obligatoire';
    if (t.length > nameMax) return 'Nom de l\'agence : $nameMax caractères maximum';
    return null;
  }

  static String? phone(String? v) => Validators.phone(v);
  static String? email(String? v) => Validators.email(v);

  static String? description(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Une description courte est obligatoire';
    if (t.length < descriptionMin) return 'Au moins $descriptionMin caractères';
    if (t.length > descriptionMax) return 'Description : $descriptionMax caractères maximum';
    return null;
  }

  /// Must be one of the supported locations, never free text.
  static String? city(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Choisissez votre ville';
    if (!tunisiaGovernorates.contains(t)) return 'Choisissez une localisation proposée';
    return null;
  }

  static String? address(String? v) {
    final t = v?.trim() ?? '';
    if (t.length > addressMax) return 'Adresse : $addressMax caractères maximum';
    return null;
  }

  /// Optional. Accepts http(s) URLs only (blocks `javascript:` and friends).
  static String? website(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    if (t.length > websiteMax) return 'Adresse du site trop longue';
    final uri = Uri.tryParse(t);
    final ok = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.contains('.');
    return ok ? null : 'Saisissez une adresse valide (https://...)';
  }

  static String? years(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n < 0 || n > maxYears) return 'Saisissez un nombre entre 0 et $maxYears';
    return null;
  }

  /// Image rules (format and size) shared with the upload service.
  static const allowedImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const maxImageBytes = 2 * 1024 * 1024;

  static String? image({required String fileName, required int bytes}) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!allowedImageExtensions.contains(ext)) return 'Seules les images JPG, PNG et WebP sont acceptées.';
    if (bytes <= 0) return 'L\'image choisie est vide.';
    if (bytes > maxImageBytes) return 'L\'image doit faire moins de 2 Mo.';
    return null;
  }

  /// Field name -> message for every invalid field. Empty map == valid.
  static Map<String, String> validate(AgentProfile p) {
    final errors = <String, String>{
      'professionalName': ?name(p.professionalName),
      'agencyName': ?agencyName(p.agencyName, isAgency: p.isAgency),
      'phone': ?phone(p.phone),
      'publicEmail': ?email(p.publicEmail),
      'description': ?description(p.description),
      'city': ?city(p.city),
      'address': ?address(p.address),
      'website': ?website(p.website),
      if (p.yearsOfExperience != null && (p.yearsOfExperience! < 0 || p.yearsOfExperience! > maxYears))
        'yearsOfExperience': 'Saisissez un nombre entre 0 et $maxYears',
      if (p.serviceAreas.length > maxServiceAreas || p.serviceAreas.any((a) => !tunisiaGovernorates.contains(a)))
        'serviceAreas': 'Choisissez jusqu\'à $maxServiceAreas zones',
      if (p.languages.length > maxLanguages) 'languages': '$maxLanguages langues maximum',
    };
    return errors;
  }
}
