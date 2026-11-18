import '../entities/verification_enums.dart';

/// THE single place for the decisions spec §21/§23 leaves to the project team.
/// Change values here once business / legal confirm them; nothing else in the
/// app hard-codes a document list, a file limit or a validity period.
class VerificationPolicy {
  const VerificationPolicy._();

  // ---- files (spec §13.3) ---------------------------------------------------
  // Starting policy. PDF needs a file picker package and a Cloudinary preset
  // that accepts it; today only images are supported end to end.
  static const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  static const maxFileBytes = 5 * 1024 * 1024;
  static const maxFilesPerDocumentType = 3;
  static const maxDocumentsPerRequest = 12;

  static String mimeTypeFor(String extension) => switch (extension.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  // ---- evidence per target type ----------------------------------------------
  // TODO(business): confirm the accepted evidence with the product owner / legal.
  static Set<VerificationDocumentType> requiredDocuments(
    VerificationTargetType type, {
    bool isAgency = false,
  }) =>
      switch (type) {
        VerificationTargetType.user => {VerificationDocumentType.identity},
        VerificationTargetType.owner => {
            VerificationDocumentType.identity,
            VerificationDocumentType.ownershipDocument,
          },
        VerificationTargetType.agent => {
            VerificationDocumentType.identity,
            VerificationDocumentType.professionalDocument,
            if (isAgency) VerificationDocumentType.agencyDocument,
          },
        VerificationTargetType.property => {VerificationDocumentType.ownershipDocument},
      };

  /// Why each document is requested (spec §14.3: explain it to the applicant).
  static String whyRequested(VerificationDocumentType t) => switch (t) {
        VerificationDocumentType.identity => 'Lets a reviewer match your name with the information you entered.',
        VerificationDocumentType.ownershipDocument =>
          'Lets a reviewer see that you present yourself as the owner of the property.',
        VerificationDocumentType.professionalDocument => 'Shows your professional activity.',
        VerificationDocumentType.agencyDocument => 'Shows the agency you represent.',
      };

  static String intro(VerificationTargetType t) => switch (t) {
        VerificationTargetType.user =>
          'Confirms your identity with a document. Your email is confirmed separately; your phone number is not yet confirmed by a code.',
        VerificationTargetType.owner => 'Confirms who you are and that you present yourself as the property owner.',
        VerificationTargetType.agent => 'Confirms your identity and professional information.',
        VerificationTargetType.property =>
          'A reviewer checks the listing information, its location, its photos and your ownership evidence.',
      };

  /// What an approved badge honestly says (spec §14.4).
  static String badgeText(VerificationTargetType t) => switch (t) {
        VerificationTargetType.user => 'Identity reviewed',
        VerificationTargetType.owner => 'Owner documents reviewed',
        VerificationTargetType.agent => 'Verified professional',
        VerificationTargetType.property => 'Verified listing',
      };

  // ---- validity (spec §5.3) --------------------------------------------------
  /// Null = approvals never expire. The study gives no duration, so none is
  /// invented here: set one per type when the team decides.
  static Duration? validityFor(VerificationTargetType type) => null;

  static DateTime? expiresAtFor(VerificationTargetType type, DateTime approvedAt) {
    final d = validityFor(type);
    return d == null ? null : approvedAt.add(d);
  }

  // ---- review ------------------------------------------------------------------
  static const rejectionReasonMin = 5;
  static const rejectionReasonMax = 500;
}
