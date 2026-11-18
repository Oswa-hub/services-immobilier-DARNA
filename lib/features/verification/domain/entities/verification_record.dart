import '../../../properties/domain/entities/property.dart';
import 'verification_enums.dart';

/// Metadata of one uploaded file (spec §9.2). The file lives in PRIVATE
/// Cloudinary storage; only a reference is kept, never a public URL.
class VerificationDocument {
  const VerificationDocument({
    required this.documentId,
    required this.documentType,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.format,
    this.uploadedAt,
  });

  final String documentId;
  final VerificationDocumentType documentType;

  /// Cloudinary `public_id` of an `authenticated` (private) asset.
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String? format;
  final DateTime? uploadedAt;
}

/// `verifications/{targetType}_{targetId}` (spec §9.1).
class VerificationRecord {
  const VerificationRecord({
    required this.id,
    required this.applicantId,
    required this.targetId,
    required this.targetType,
    required this.status,
    this.submittedData = const {},
    this.documents = const [],
    this.reviewedBy,
    this.reviewedAt,
    this.decision,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.expiresAt,
    this.attemptNumber = 1,
  });

  final String id;
  final String applicantId;
  final String targetId;
  final VerificationTargetType targetType;
  final VerificationStatus status;
  final Map<String, dynamic> submittedData;
  final List<VerificationDocument> documents;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? decision;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? expiresAt;
  final int attemptNumber;

  /// An approved verification whose validity ended shows as expired even before
  /// an administrator marks it (spec §5.3). With no validity policy `expiresAt`
  /// is null and nothing expires by itself.
  VerificationStatus effectiveStatus([DateTime? now]) {
    if (status == VerificationStatus.approved &&
        expiresAt != null &&
        !expiresAt!.isAfter(now ?? DateTime.now())) {
      return VerificationStatus.expired;
    }
    return status;
  }
}

/// Append-only audit of one request (`history` sub-collection, spec §9.4).
class VerificationHistoryEntry {
  const VerificationHistoryEntry({
    required this.id,
    required this.action,
    required this.actorId,
    required this.actorRole,
    required this.previousStatus,
    required this.newStatus,
    required this.attemptNumber,
    this.reason,
    this.createdAt,
  });

  final String id;
  final VerificationAction action;
  final String actorId;
  final String actorRole; // applicant | admin
  final VerificationStatus previousStatus;
  final VerificationStatus newStatus;
  final int attemptNumber;
  final String? reason;
  final DateTime? createdAt;
}
