import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/verification_failure.dart';
import '../domain/entities/verification_enums.dart';

typedef VerificationRawDoc = ({String id, Map<String, dynamic> data});

List<VerificationRawDoc> _raw(QuerySnapshot<Map<String, dynamic>> s) =>
    [for (final d in s.docs) (id: d.id, data: d.data())];

/// Firestore access of Module 13. No business rule lives here, but every
/// multi-document change is ONE atomic batch: the request, its history entry,
/// the audit record, the notification and (for decisions) the public mirror
/// flag. The Firestore rules use `getAfter()` on those documents, so a status
/// can never change without its history, and a verified flag can never be set
/// without an approved request.
///
/// The current user id ALWAYS comes from Firebase Auth, never from the UI.
class VerificationRemoteDataSource {
  VerificationRemoteDataSource(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get uid {
    final id = _auth.currentUser?.uid;
    if (id == null) throw const VerificationFailure(VerificationFailureType.unauthenticated);
    return id;
  }

  bool get emailVerified => _auth.currentUser?.emailVerified ?? false;

  CollectionReference<Map<String, dynamic>> get _verifications => _db.collection('verifications');
  DocumentReference<Map<String, dynamic>> _ref(String id) => _verifications.doc(id);

  // ---- reads ---------------------------------------------------------------
  /// Rule-provable: filters on `applicantId == uid`. No index needed.
  Stream<List<VerificationRawDoc>> watchMine() =>
      _verifications.where('applicantId', isEqualTo: uid).snapshots().map(_raw);

  Stream<VerificationRawDoc?> watchOne(String id) => _ref(id).snapshots().map((s) {
        final d = s.data();
        return (!s.exists || d == null) ? null : (id: s.id, data: d);
      });

  Future<VerificationRawDoc?> getOne(String id) async {
    final s = await _ref(id).get();
    final d = s.data();
    return (!s.exists || d == null) ? null : (id: s.id, data: d);
  }

  Stream<List<VerificationRawDoc>> watchHistory(String id) =>
      _ref(id).collection('history').orderBy('createdAt').snapshots().map(_raw);

  /// Index: status ASC, submittedAt DESC.
  Stream<List<VerificationRawDoc>> watchByStatus(String status, {required int limit}) => _verifications
      .where('status', isEqualTo: status)
      .orderBy('submittedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_raw);

  // ---- writes: building blocks -------------------------------------------------
  Map<String, dynamic> _history({
    required String action,
    required String actorRole,
    required String previous,
    required String next,
    required int attempt,
    String? reason,
  }) =>
      {
        'action': action,
        'actorId': uid,
        'actorRole': actorRole,
        'previousStatus': previous,
        'newStatus': next,
        'reason': reason,
        'attemptNumber': attempt,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Audit trail (spec §16). Never contains document contents or links.
  Map<String, dynamic> _audit({
    required String action,
    required String actorRole,
    required String verificationId,
    required String targetType,
    required String targetId,
    required String previous,
    required String next,
    String? reason,
  }) =>
      {
        'actorId': uid,
        'actorRole': actorRole,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'verificationId': verificationId,
        'previousStatus': previous,
        'newStatus': next,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      };

  /// Notification text carries NO sensitive detail (spec §15): it only says the
  /// status changed and sends the user to the secure screen.
  Map<String, dynamic> _notification({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String verificationId,
  }) =>
      {
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'targetId': verificationId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// The flag other screens read for badges. Only an administrator, in the same
  /// batch as an approved/rejected/expired request, can change it.
  (DocumentReference<Map<String, dynamic>>, Map<String, dynamic>) _mirror(
    VerificationTargetType type,
    String targetId,
    String status,
  ) =>
      switch (type) {
        VerificationTargetType.user => (_db.collection('users').doc(targetId), {'userVerificationStatus': status}),
        VerificationTargetType.owner => (_db.collection('users').doc(targetId), {'ownerVerificationStatus': status}),
        VerificationTargetType.agent => (
            _db.collection('agent_profiles').doc(targetId),
            {'verificationStatus': status}
          ),
        VerificationTargetType.property => (_db.collection('properties').doc(targetId), {'verificationStatus': status}),
      };

  // ---- applicant writes ----------------------------------------------------------
  Future<void> createRequest({
    required String id,
    required VerificationTargetType type,
    required String targetId,
    required Map<String, dynamic> data,
  }) {
    final ref = _ref(id);
    final batch = _db.batch()
      ..set(ref, data)
      ..set(
        ref.collection('history').doc('1_submitted'),
        _history(
            action: 'submitted', actorRole: 'applicant', previous: 'not_submitted', next: 'pending', attempt: 1),
      )
      ..set(
        _db.collection('audit_logs').doc(),
        _audit(
            action: 'verification.submitted',
            actorRole: 'applicant',
            verificationId: id,
            targetType: type.wire,
            targetId: targetId,
            previous: 'not_submitted',
            next: 'pending'),
      )
      ..set(
        _db.collection('notifications').doc(),
        _notification(
            userId: uid,
            type: 'verificationSubmitted',
            title: 'Demande de vérification reçue',
            body: 'Votre demande est en attente de vérification.',
            verificationId: id),
      );
    return batch.commit();
  }

  Future<void> resubmitRequest({
    required String id,
    required VerificationTargetType type,
    required String targetId,
    required String previousStatus,
    required int attempt,
    required Map<String, dynamic> changes,
  }) {
    final ref = _ref(id);
    final batch = _db.batch()
      ..update(ref, changes)
      ..set(
        ref.collection('history').doc('${attempt}_resubmitted'),
        _history(
            action: 'resubmitted',
            actorRole: 'applicant',
            previous: previousStatus,
            next: 'pending',
            attempt: attempt),
      )
      ..set(
        _db.collection('audit_logs').doc(),
        _audit(
            action: 'verification.resubmitted',
            actorRole: 'applicant',
            verificationId: id,
            targetType: type.wire,
            targetId: targetId,
            previous: previousStatus,
            next: 'pending'),
      )
      ..set(
        _db.collection('notifications').doc(),
        _notification(
            userId: uid,
            type: 'verificationSubmitted',
            title: 'Demande de vérification reçue',
            body: 'Votre demande corrigée est en attente de vérification.',
            verificationId: id),
      );
    return batch.commit();
  }

  // ---- administrator writes ----------------------------------------------------------
  /// approve / reject / expire in ONE atomic batch.
  Future<void> decide({
    required String id,
    required VerificationTargetType type,
    required String targetId,
    required String applicantId,
    required int attempt,
    required String previousStatus,
    required String newStatus, // approved | rejected | expired
    String? reason,
    DateTime? expiresAt,
  }) {
    final ref = _ref(id);
    final isExpire = newStatus == 'expired';

    final changes = <String, dynamic>{
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!isExpire) ...{
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'decision': newStatus,
        'rejectionReason': newStatus == 'rejected' ? reason : null,
        'expiresAt': newStatus == 'approved' && expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
      },
    };

    final (mirrorRef, mirrorData) = _mirror(type, targetId, newStatus);
    final (title, body, notifType) = switch (newStatus) {
      'approved' => ('Vérification acceptée', 'Votre demande de vérification a été acceptée.', 'verificationApproved'),
      'rejected' => (
          'Vérification à corriger',
          'Votre demande de vérification doit être corrigée. Ouvrez l\'application pour lire le motif.',
          'verificationRejected'
        ),
      _ => (
          'Vérification expirée',
          'Une de vos vérifications n\'est plus valable. Ouvrez l\'application pour envoyer une nouvelle demande.',
          'verificationExpired'
        ),
    };

    final batch = _db.batch()
      ..update(ref, changes)
      ..set(
        ref.collection('history').doc('${attempt}_$newStatus'),
        _history(
            action: newStatus,
            actorRole: 'admin',
            previous: previousStatus,
            next: newStatus,
            attempt: attempt,
            reason: reason),
      )
      ..set(
        _db.collection('audit_logs').doc(),
        _audit(
            action: 'verification.$newStatus',
            actorRole: 'admin',
            verificationId: id,
            targetType: type.wire,
            targetId: targetId,
            previous: previousStatus,
            next: newStatus,
            reason: reason),
      )
      ..set(
        _db.collection('notifications').doc(),
        _notification(userId: applicantId, type: notifType, title: title, body: body, verificationId: id),
      )
      ..update(mirrorRef, mirrorData);
    // B2: there is no server function to grant the agent role (Spark plan), so an
    // approved agent verification makes the account an agent in the same batch.
    if (type == VerificationTargetType.agent && newStatus == 'approved') {
      batch.update(_db.collection('users').doc(targetId), {'role': 'agent'});
    }
    return batch.commit();
  }
}
