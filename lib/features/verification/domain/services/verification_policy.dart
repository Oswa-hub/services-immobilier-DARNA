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
        VerificationDocumentType.identity => 'Permet de rapprocher votre nom des informations saisies.',
        VerificationDocumentType.ownershipDocument =>
          'Montre que vous vous présentez comme propriétaire du bien.',
        VerificationDocumentType.professionalDocument => 'Montre votre activité professionnelle.',
        VerificationDocumentType.agencyDocument => 'Montre l\'agence que vous représentez.',
      };

  static String intro(VerificationTargetType t) => switch (t) {
        VerificationTargetType.user =>
          'Confirme votre identité par un document. Votre e-mail est confirmé à part ; votre téléphone n\'est pas encore confirmé par code.',
        VerificationTargetType.owner => 'Confirme votre identité et que vous vous présentez comme propriétaire.',
        VerificationTargetType.agent => 'Confirme votre identité et vos informations professionnelles.',
        VerificationTargetType.property =>
          'Notre équipe contrôle les informations de l\'annonce, sa localisation, ses photos et vos justificatifs de propriété.',
      };

  /// What an approved badge honestly says (spec §14.4).
  static String badgeText(VerificationTargetType t) => switch (t) {
        VerificationTargetType.user => 'Identité vérifiée',
        VerificationTargetType.owner => 'Propriétaire vérifié',
        VerificationTargetType.agent => 'Professionnel vérifié',
        VerificationTargetType.property => 'Annonce vérifiée',
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
