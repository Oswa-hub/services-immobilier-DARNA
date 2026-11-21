import '../../../properties/domain/entities/property.dart';

/// What is being verified (spec §4). A request always names both the target
/// and its type: an approved `user` check never proves ownership of a property.
enum VerificationTargetType {
  user,
  owner,
  agent,
  property;

  String get wire => name;

  String get label => switch (this) {
        VerificationTargetType.user => 'Identité',
        VerificationTargetType.owner => 'Propriétaire',
        VerificationTargetType.agent => 'Professionnel',
        VerificationTargetType.property => 'Bien',
      };

  /// Deterministic request id: one request per target and type. A duplicate
  /// pending request is impossible by construction (spec §17.1) and a rejected
  /// request is corrected in place; old attempts stay in `history`.
  String docId(String targetId) => '${wire}_$targetId';

  static VerificationTargetType? tryParse(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

enum VerificationDocumentType {
  identity('identity'),
  ownershipDocument('ownership_document'),
  professionalDocument('professional_document'),
  agencyDocument('agency_document');

  const VerificationDocumentType(this.wire);
  final String wire;

  String get label => switch (this) {
        VerificationDocumentType.identity => 'Pièce d\'identité',
        VerificationDocumentType.ownershipDocument => 'Justificatif de propriété',
        VerificationDocumentType.professionalDocument => 'Justificatif professionnel',
        VerificationDocumentType.agencyDocument => 'Document de l\'agence',
      };

  static VerificationDocumentType? tryParse(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }
}

/// What happened to a request (spec §9.4).
enum VerificationAction {
  submitted,
  resubmitted,
  approved,
  rejected,
  expired;

  String get wire => name;

  static VerificationAction? tryParse(String? v) {
    for (final a in values) {
      if (a.wire == v) return a;
    }
    return null;
  }
}

extension VerificationStatusX on VerificationStatus {
  String get wire => switch (this) {
        VerificationStatus.notSubmitted => 'not_submitted',
        VerificationStatus.pending => 'pending',
        VerificationStatus.approved => 'approved',
        VerificationStatus.rejected => 'rejected',
        VerificationStatus.expired => 'expired',
      };

  /// Spec §12.3 user-facing labels.
  String get label => switch (this) {
        VerificationStatus.notSubmitted => 'Non envoyée',
        VerificationStatus.pending => 'En cours d\'examen',
        VerificationStatus.approved => 'Vérifié',
        VerificationStatus.rejected => 'Corrections demandées',
        VerificationStatus.expired => 'Vérification expirée',
      };

  /// What the applicant should do next, not just a technical status.
  String get nextStep => switch (this) {
        VerificationStatus.notSubmitted => 'Envoyez les informations demandées pour commencer.',
        VerificationStatus.pending => 'Un administrateur examine votre demande. Vous serez notifié.',
        VerificationStatus.approved => 'Cette vérification est valable.',
        VerificationStatus.rejected => 'Lisez le motif, corrigez les informations et renvoyez.',
        VerificationStatus.expired => 'Cette vérification n\'est plus valable. Envoyez une nouvelle demande.',
      };
}
