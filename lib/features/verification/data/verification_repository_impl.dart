import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/errors/verification_failure.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../properties/domain/entities/property.dart';
import '../domain/entities/verification_enums.dart';
import '../domain/entities/verification_record.dart';
import '../domain/entities/verification_submission.dart';
import '../domain/repositories/verification_repository.dart';
import '../domain/services/verification_policy.dart';
import '../domain/services/verification_state_machine.dart';
import '../domain/services/verification_validator.dart';
import 'models/verification_model.dart';
import 'verification_document_link_service.dart';
import 'verification_remote_data_source.dart';

class VerificationRepositoryImpl implements VerificationRepository {
  VerificationRepositoryImpl(this._ds, this._cloudinary, this._links);

  final VerificationRemoteDataSource _ds;
  final CloudinaryService _cloudinary;
  final VerificationDocumentLinkService _links;

  // ---- error mapping (spec §18: never show raw exceptions) ----------------------
  static VerificationFailure toFailure(Object e, [VerificationFailureType fallback = VerificationFailureType.unknown]) {
    if (e is VerificationFailure) return e;
    if (e is CloudinaryUploadException) return const VerificationFailure(VerificationFailureType.documentUploadFailed);
    if (e is FirebaseException) {
      debugPrint('Verification Firebase error [${e.code}]: ${e.message}');
      return VerificationFailure(switch (e.code) {
        'permission-denied' => VerificationFailureType.permissionDenied,
        'unauthenticated' => VerificationFailureType.unauthenticated,
        'not-found' => VerificationFailureType.notFound,
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => VerificationFailureType.network,
        _ => fallback,
      });
    }
    debugPrint('Verification unexpected error: $e');
    return VerificationFailure(fallback);
  }

  Stream<T> _guardStream<T>(Stream<T> source) => source.transform(
        StreamTransformer<T, T>.fromHandlers(handleError: (e, st, sink) => sink.addError(toFailure(e), st)),
      );

  // ---- reads ----------------------------------------------------------------------
  @override
  Stream<List<VerificationRecord>> watchMyVerifications() => _guardStream(
        _ds.watchMine().map((docs) => [for (final d in docs) ?VerificationModel.tryFromMap(d.id, d.data)]),
      );

  @override
  Stream<VerificationRecord?> watchVerification(String id) => _guardStream(
        _ds.watchOne(id).map((d) => d == null ? null : VerificationModel.tryFromMap(d.id, d.data)),
      );

  @override
  Future<VerificationRecord?> getVerification(String id) async {
    try {
      final d = await _ds.getOne(id);
      return d == null ? null : VerificationModel.tryFromMap(d.id, d.data);
    } catch (e) {
      throw toFailure(e);
    }
  }

  @override
  Stream<List<VerificationHistoryEntry>> watchHistory(String id) => _guardStream(
        _ds.watchHistory(id).map((docs) => [for (final d in docs) ?VerificationModel.historyFromMap(d.id, d.data)]),
      );

  @override
  Stream<List<VerificationRecord>> watchByStatus(VerificationStatus status, {int limit = 100}) => _guardStream(
        _ds
            .watchByStatus(status.wire, limit: limit)
            .map((docs) => [for (final d in docs) ?VerificationModel.tryFromMap(d.id, d.data)]),
      );

  // ---- applicant: submit / resubmit ---------------------------------------------------
  @override
  Future<void> submit(VerificationSubmission s) async {
    try {
      final uid = _ds.uid;

      // 1. Local validation: nothing is uploaded for an invalid form.
      final errors = VerificationValidator.validate(s);
      if (errors.isNotEmpty) {
        throw VerificationFailure(VerificationFailureType.validationFailed, fieldErrors: errors);
      }

      // 2. A user / owner / agent request is always about the caller's own account.
      if (s.targetType != VerificationTargetType.property && s.targetId != uid) {
        throw const VerificationFailure(VerificationFailureType.permissionDenied);
      }

      // 3. The state machine decides whether a (re)submission is allowed.
      final id = s.targetType.docId(s.targetId);
      final existing = await _ds.getOne(id);
      final current = existing == null ? null : VerificationModel.tryFromMap(existing.id, existing.data);
      final status = current?.status ?? VerificationStatus.notSubmitted;
      if (!VerificationStateMachine.canSubmit(status)) {
        throw VerificationFailure(
          VerificationFailureType.invalidStatusTransition,
          detail: status == VerificationStatus.pending
              ? 'A request is already under review.'
              : 'This target is already verified.',
        );
      }
      final attempt = (current?.attemptNumber ?? 0) + 1;

      // 4. Upload to PRIVATE storage first. If any file fails NOTHING is created
      //    (spec §13.4). Orphaned uploads are purged by a backend retention job.
      final docs = <VerificationDocument>[];
      for (var i = 0; i < s.files.length; i++) {
        final f = s.files[i];
        final up = await _cloudinary.uploadPrivateDocumentDetailed(
          f.bytes,
          filename: f.fileName,
          folder: 'verification/$uid/$id',
        );
        docs.add(VerificationDocument(
          documentId: 'a${attempt}_${f.documentType.wire}_${i + 1}',
          documentType: f.documentType,
          storagePath: up.publicId,
          fileName: f.fileName,
          mimeType: f.mimeType,
          sizeBytes: f.sizeBytes,
          format: up.format.isEmpty ? f.extension : up.format,
        ));
      }

      final data = _sanitize(s);

      // 5. One atomic batch: request + history + audit + notification.
      if (current == null) {
        await _ds.createRequest(
          id: id,
          type: s.targetType,
          targetId: s.targetId,
          data: VerificationModel.toCreateMap(
            id: id,
            applicantId: uid,
            type: s.targetType,
            targetId: s.targetId,
            submittedData: data,
            documents: docs,
          ),
        );
      } else {
        await _ds.resubmitRequest(
          id: id,
          type: s.targetType,
          targetId: s.targetId,
          previousStatus: status.wire,
          attempt: attempt,
          changes: VerificationModel.toResubmitMap(attemptNumber: attempt, submittedData: data, documents: docs),
        );
      }
    } catch (e) {
      if (e is VerificationFailure && e.type == VerificationFailureType.validationFailed) rethrow;
      throw toFailure(e, VerificationFailureType.documentUploadFailed);
    }
  }

  /// Only plain values, trimmed. `emailConfirmed` comes from Firebase Auth, never
  /// from the form, and `phoneConfirmed` stays false: no phone code is sent yet,
  /// so the app must not claim the number was confirmed (spec §2.2, §4.1).
  Map<String, dynamic> _sanitize(VerificationSubmission s) {
    final out = <String, dynamic>{};
    s.submittedData.forEach((k, v) {
      if (v is String) {
        out[k] = k == 'phone' ? normalizePhone(v.trim()) : v.trim();
      } else if (v is bool || v is int || v is double) {
        out[k] = v;
      }
    });
    if (s.targetType == VerificationTargetType.user) {
      out['emailConfirmed'] = _ds.emailVerified;
      out['phoneConfirmed'] = false;
    }
    return out;
  }

  // ---- administrator ------------------------------------------------------------------------
  Future<VerificationRecord> _loadForDecision(String id) async {
    final r = await getVerification(id);
    if (r == null) throw const VerificationFailure(VerificationFailureType.notFound);
    return r;
  }

  Future<void> _decide(
    String id, {
    required VerificationStatus to,
    String? reason,
  }) async {
    final r = await _loadForDecision(id);
    if (r.applicantId == _ds.uid) {
      // An administrator can never decide their own request.
      throw const VerificationFailure(VerificationFailureType.permissionDenied);
    }
    if (to == VerificationStatus.expired) {
      if (!VerificationStateMachine.canExpire(r.status)) {
        throw const VerificationFailure(VerificationFailureType.invalidStatusTransition);
      }
    } else if (!VerificationStateMachine.canReview(r.status)) {
      throw const VerificationFailure(VerificationFailureType.alreadyReviewed);
    }
    try {
      await _ds.decide(
        id: id,
        type: r.targetType,
        targetId: r.targetId,
        applicantId: r.applicantId,
        attempt: r.attemptNumber,
        previousStatus: r.status.wire,
        newStatus: to.wire,
        reason: reason,
        expiresAt: to == VerificationStatus.approved
            ? VerificationPolicy.expiresAtFor(r.targetType, DateTime.now())
            : null,
      );
    } catch (e) {
      final failure = toFailure(e);
      if (failure.type == VerificationFailureType.permissionDenied) {
        // Most likely another reviewer decided first (rules check the live status).
        final fresh = await getVerification(id).catchError((_) => null);
        if (fresh != null && fresh.status != r.status) {
          throw const VerificationFailure(VerificationFailureType.alreadyReviewed);
        }
      }
      throw failure;
    }
  }

  @override
  Future<void> approve(String id) => _decide(id, to: VerificationStatus.approved);

  @override
  Future<void> reject(String id, String reason) {
    final problem = VerificationStateMachine.validateRejectionReason(reason);
    if (problem != null) {
      throw VerificationFailure(VerificationFailureType.validationFailed,
          detail: problem, fieldErrors: {'reason': problem});
    }
    return _decide(id, to: VerificationStatus.rejected, reason: reason.trim());
  }

  @override
  Future<void> markExpired(String id) => _decide(id, to: VerificationStatus.expired);

  @override
  Future<Uri> documentLink(String verificationId, String documentId) =>
      _links.link(verificationId: verificationId, documentId: documentId);
}
