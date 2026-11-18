import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/verification_enums.dart';
import '../../domain/entities/verification_record.dart';

DateTime? _date(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => null,
    };

String? _str(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

class VerificationModel {
  const VerificationModel._();

  /// Null for a malformed document (it is skipped, never shown half-parsed).
  static VerificationRecord? tryFromMap(String id, Map<String, dynamic> d) {
    final type = VerificationTargetType.tryParse(_str(d['targetType']));
    final target = _str(d['targetId']);
    final applicant = _str(d['applicantId']);
    if (type == null || target == null || applicant == null) return null;

    final rawDocs = d['documents'];
    final docs = <VerificationDocument>[];
    if (rawDocs is List) {
      for (final e in rawDocs) {
        if (e is! Map) continue;
        final doc = _document(Map<String, dynamic>.from(e));
        if (doc != null) docs.add(doc);
      }
    }
    final data = d['submittedData'];
    return VerificationRecord(
      id: id,
      applicantId: applicant,
      targetId: target,
      targetType: type,
      status: VerificationStatus.parse(_str(d['status'])),
      submittedData: data is Map ? Map<String, dynamic>.from(data) : const {},
      documents: docs,
      reviewedBy: _str(d['reviewedBy']),
      reviewedAt: _date(d['reviewedAt']),
      decision: _str(d['decision']),
      rejectionReason: _str(d['rejectionReason']),
      createdAt: _date(d['createdAt']),
      updatedAt: _date(d['updatedAt']),
      submittedAt: _date(d['submittedAt']),
      expiresAt: _date(d['expiresAt']),
      attemptNumber: _int(d['attemptNumber'], 1),
    );
  }

  static VerificationDocument? _document(Map<String, dynamic> m) {
    final type = VerificationDocumentType.tryParse(_str(m['documentType']));
    final id = _str(m['documentId']);
    final path = _str(m['storagePath']);
    if (type == null || id == null || path == null) return null;
    return VerificationDocument(
      documentId: id,
      documentType: type,
      storagePath: path,
      fileName: _str(m['fileName']) ?? id,
      mimeType: _str(m['mimeType']) ?? 'image/jpeg',
      sizeBytes: _int(m['sizeBytes']),
      format: _str(m['format']),
      uploadedAt: _date(m['uploadedAt']),
    );
  }

  static VerificationHistoryEntry? historyFromMap(String id, Map<String, dynamic> d) {
    final action = VerificationAction.tryParse(_str(d['action']));
    final actor = _str(d['actorId']);
    if (action == null || actor == null) return null;
    return VerificationHistoryEntry(
      id: id,
      action: action,
      actorId: actor,
      actorRole: _str(d['actorRole']) ?? 'applicant',
      previousStatus: VerificationStatus.parse(_str(d['previousStatus'])),
      newStatus: VerificationStatus.parse(_str(d['newStatus'])),
      attemptNumber: _int(d['attemptNumber'], 1),
      reason: _str(d['reason']),
      createdAt: _date(d['createdAt']),
    );
  }

  static Map<String, dynamic> documentToMap(VerificationDocument d) => {
        'documentId': d.documentId,
        'documentType': d.documentType.wire,
        'storagePath': d.storagePath,
        'fileName': d.fileName,
        'mimeType': d.mimeType,
        'sizeBytes': d.sizeBytes,
        'format': d.format ?? '',
        // serverTimestamp() is not allowed inside an array: client time here.
        'uploadedAt': Timestamp.now(),
      };

  /// First submission. Always `pending`; the decision fields stay null: only an
  /// administrator's rule-checked write can fill them.
  static Map<String, dynamic> toCreateMap({
    required String id,
    required String applicantId,
    required VerificationTargetType type,
    required String targetId,
    required Map<String, dynamic> submittedData,
    required List<VerificationDocument> documents,
  }) =>
      {
        'id': id,
        'applicantId': applicantId,
        'targetId': targetId,
        'targetType': type.wire,
        'status': 'pending',
        'submittedData': submittedData,
        'documents': [for (final d in documents) documentToMap(d)],
        'reviewedBy': null,
        'reviewedAt': null,
        'decision': null,
        'rejectionReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'attemptNumber': 1,
      };

  /// Resubmission after `rejected` / `expired`: a new attempt, back to pending.
  /// The earlier decision is already preserved in `history`.
  static Map<String, dynamic> toResubmitMap({
    required int attemptNumber,
    required Map<String, dynamic> submittedData,
    required List<VerificationDocument> documents,
  }) =>
      {
        'status': 'pending',
        'submittedData': submittedData,
        'documents': [for (final d in documents) documentToMap(d)],
        'reviewedBy': null,
        'reviewedAt': null,
        'decision': null,
        'rejectionReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
        'expiresAt': null,
        'attemptNumber': attemptNumber,
      };
}
