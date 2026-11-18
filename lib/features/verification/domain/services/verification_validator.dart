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
        if (text('fullName').length < 2) e['fullName'] = 'Enter your full name.';
        if (!_phone.hasMatch(normalizePhone(text('phone')))) e['phone'] = 'Enter a valid phone number (8 to 15 digits).';
        if (s.targetType == VerificationTargetType.owner && text('propertyReference').length > 200) {
          e['propertyReference'] = 'Keep this under 200 characters.';
        }
        if (s.targetType == VerificationTargetType.agent && s.isAgency) {
          if (text('agencyName').length < 2) e['agencyName'] = 'Enter the agency name.';
          if (text('agencyAddress').length < 3) e['agencyAddress'] = 'Enter the agency address.';
        }
      case VerificationTargetType.property:
        if (d['locationProvided'] != true) e['property'] = 'The listing has no complete location yet.';
        if (d['listingInformationProvided'] != true) e['property'] = 'The listing information is incomplete.';
        final photos = d['photoCount'];
        if (photos is! int || photos < 1) e['property'] = 'The listing needs at least one photo.';
        if (text('city').isEmpty) e['property'] = 'The listing has no city.';
    }

    // ---- files ----
    final counts = <VerificationDocumentType, int>{};
    for (final f in s.files) {
      counts[f.documentType] = (counts[f.documentType] ?? 0) + 1;
      if (!VerificationPolicy.allowedExtensions.contains(f.extension)) {
        e[f.documentType.wire] = 'This file format is not supported. Use JPG, PNG or WebP.';
      } else if (f.sizeBytes == 0) {
        e[f.documentType.wire] = 'The selected file is empty.';
      } else if (f.sizeBytes > VerificationPolicy.maxFileBytes) {
        e[f.documentType.wire] = 'This file is too large. Choose a smaller file.';
      }
    }
    for (final entry in counts.entries) {
      if (entry.value > VerificationPolicy.maxFilesPerDocumentType) {
        e[entry.key.wire] = 'Add at most ${VerificationPolicy.maxFilesPerDocumentType} files per document type.';
      }
    }
    if (s.files.length > VerificationPolicy.maxDocumentsPerRequest) {
      e['documents'] = 'Too many files in one request.';
    }
    for (final required in VerificationPolicy.requiredDocuments(s.targetType, isAgency: s.isAgency)) {
      if ((counts[required] ?? 0) == 0) {
        e[required.wire] = 'Please upload the required document.';
      }
    }
    return e;
  }
}
