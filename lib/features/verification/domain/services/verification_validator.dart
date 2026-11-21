import '../entities/verification_enums.dart';
import '../entities/verification_submission.dart';
import 'verification_policy.dart';

final _phone = RegExp(r'^\+?[0-9]{8,15}$');

/// spaces, dashes, dots and brackets removed (`+216 20 111 222` -> `+21620111222`).
String normalizePhone(String raw) => raw.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');

/// Client-side validation (spec §17.1). The backend (Firestore rules) checks
/// again: this only gives the applicant fast, readable feedback.
class VerificationValidator {
  const VerificationValidator._();

  /// Field key -> message. Empty = valid. The key `documents` / `property` /
  /// `<documentType>` carries document-level errors.
  static Map<String, String> validate(VerificationSubmission s) {
    final e = <String, String>{};
    final d = s.submittedData;

    String text(String k) => (d[k] is String ? d[k] as String : '').trim();

    // ---- fields ----
    switch (s.targetType) {
      case VerificationTargetType.user:
      case VerificationTargetType.owner:
      case VerificationTargetType.agent:
        if (text('fullName').length < 2) e['fullName'] = 'Saisissez votre nom complet.';
        if (!_phone.hasMatch(normalizePhone(text('phone')))) e['phone'] = 'Saisissez un numéro valide (8 à 15 chiffres).';
        if (s.targetType == VerificationTargetType.owner && text('propertyReference').length > 200) {
          e['propertyReference'] = '200 caractères maximum.';
        }
        if (s.targetType == VerificationTargetType.agent && s.isAgency) {
          if (text('agencyName').length < 2) e['agencyName'] = 'Saisissez le nom de l\'agence.';
          if (text('agencyAddress').length < 3) e['agencyAddress'] = 'Saisissez l\'adresse de l\'agence.';
        }
      case VerificationTargetType.property:
        if (d['locationProvided'] != true) e['property'] = 'L\'annonce n\'a pas encore de localisation complète.';
        if (d['listingInformationProvided'] != true) e['property'] = 'Les informations de l\'annonce sont incomplètes.';
        final photos = d['photoCount'];
        if (photos is! int || photos < 1) e['property'] = 'L\'annonce doit avoir au moins une photo.';
        if (text('city').isEmpty) e['property'] = 'L\'annonce n\'a pas de ville.';
    }

    // ---- files ----
    final counts = <VerificationDocumentType, int>{};
    for (final f in s.files) {
      counts[f.documentType] = (counts[f.documentType] ?? 0) + 1;
      if (!VerificationPolicy.allowedExtensions.contains(f.extension)) {
        e[f.documentType.wire] = 'Format non pris en charge. Utilisez JPG, PNG ou WebP.';
      } else if (f.sizeBytes == 0) {
        e[f.documentType.wire] = 'Le fichier choisi est vide.';
      } else if (f.sizeBytes > VerificationPolicy.maxFileBytes) {
        e[f.documentType.wire] = 'Ce fichier est trop volumineux. Choisissez un fichier plus petit.';
      }
    }
    for (final entry in counts.entries) {
      if (entry.value > VerificationPolicy.maxFilesPerDocumentType) {
        e[entry.key.wire] = '${VerificationPolicy.maxFilesPerDocumentType} fichiers maximum par type de document.';
      }
    }
    if (s.files.length > VerificationPolicy.maxDocumentsPerRequest) {
      e['documents'] = 'Trop de fichiers dans une demande.';
    }
    for (final required in VerificationPolicy.requiredDocuments(s.targetType, isAgency: s.isAgency)) {
      if ((counts[required] ?? 0) == 0) {
        e[required.wire] = 'Ajoutez le document demandé.';
      }
    }
    return e;
  }
}
