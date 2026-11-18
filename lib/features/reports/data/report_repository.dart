import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/report_failure.dart';
import '../domain/report.dart';

/// A user I blocked (`users/{me}/blocked/{otherId}`).
typedef BlockedUser = ({String id, String name, DateTime? since});

/// Module 14 data access. Throws only [ReportFailure].
abstract class ReportRepository {
  // ---- users ----------------------------------------------------------------------
  Future<void> submit({
    required String reporterId,
    required ReportTarget target,
    required String reasonId,
    required String reasonLabel,
    required String description,
  });

  Stream<List<Report>> watchMine(String reporterId);

  Future<void> block({required String me, required String otherId, required String otherName});
  Future<void> unblock({required String me, required String otherId});
  Stream<List<BlockedUser>> watchBlocked(String me);

  // ---- admin (rules: isAdmin) ----------------------------------------------------------
  Stream<List<Report>> watchAll({ReportStatus? status, int limit = 300});
  Future<void> assign(Report report, {required String adminId});
  Future<void> startInvestigation(Report report, {required String adminId});

  /// investigating → resolved | rejected, with the note shown to the reporter.
  Future<void> close(
    Report report, {
    required ReportStatus to,
    required String note,
    required ResolutionAction action,
    required String adminId,
    required bool notifyReporter,
  });
}

class FirestoreReportRepository implements ReportRepository {
  FirestoreReportRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _reports => _db.collection('reports');
  CollectionReference<Map<String, dynamic>> _blocked(String me) => _db.collection('users').doc(me).collection('blocked');

  Stream<T> _guard<T>(Stream<T> s) => s.transform(StreamTransformer<T, T>.fromHandlers(
        handleError: (e, st, sink) => sink.addError(ReportFailure.from(e), st),
      ));

  /// Notification texts are limited to 1000 characters by the rules.
  static String _cap(String s, [int max = 990]) => s.length <= max ? s : '${s.substring(0, max - 1)}…';

  static List<Report> _parse(QuerySnapshot<Map<String, dynamic>> s) =>
      [for (final d in s.docs) ?Report.tryFromMap(d.id, d.data())];

  // ---- users ----------------------------------------------------------------------

  @override
  Future<void> submit({
    required String reporterId,
    required ReportTarget target,
    required String reasonId,
    required String reasonLabel,
    required String description,
  }) async {
    final problem = ReportPolicy.checkSubmission(
      reporterId: reporterId,
      target: target,
      reason: reasonId,
      description: description,
    );
    if (problem != null) throw ReportFailure(ReportFailureType.invalid, problem);

    final ref = _reports.doc(target.reportIdFor(reporterId));
    try {
      // The rules let a user read their own report id even before it exists.
      if ((await ref.get()).exists) throw const ReportFailure(ReportFailureType.duplicate);
      await ref.set({
        'reporterId': reporterId,
        'targetType': target.type.name,
        'targetId': target.id,
        'targetLabel': target.label,
        'targetOwnerId': ?target.ownerId,
        'conversationId': ?target.conversationId,
        'propertyId': ?target.propertyId,
        'reason': reasonId,
        'reasonLabel': reasonLabel,
        'description': description.trim(),
        'status': ReportStatus.open.name,
        'priority': ReportPolicy.priorityFor(reasonId, target.type).name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ReportFailure.from(e);
    }
  }

  /// Index: reports (reporterId ASC, createdAt DESC).
  @override
  Stream<List<Report>> watchMine(String reporterId) => _guard(
        _reports.where('reporterId', isEqualTo: reporterId).orderBy('createdAt', descending: true).snapshots().map(_parse),
      );

  @override
  Future<void> block({required String me, required String otherId, required String otherName}) async {
    if (otherId.isEmpty || otherId == me || otherId.contains('/')) {
      throw const ReportFailure(ReportFailureType.invalid, 'Utilisateur invalide.');
    }
    try {
      await _blocked(me).doc(otherId).set({
        'name': otherName.length > 80 ? otherName.substring(0, 80) : otherName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ReportFailure.from(e);
    }
  }

  @override
  Future<void> unblock({required String me, required String otherId}) async {
    try {
      await _blocked(me).doc(otherId).delete();
    } catch (e) {
      throw ReportFailure.from(e);
    }
  }

  @override
  Stream<List<BlockedUser>> watchBlocked(String me) => _guard(_blocked(me).snapshots().map((s) => [
        for (final d in s.docs)
          (
            id: d.id,
            name: d.data()['name'] is String ? d.data()['name'] as String : d.id,
            since: d.data()['createdAt'] is Timestamp ? (d.data()['createdAt'] as Timestamp).toDate() : null,
          ),
      ]));

  // ---- admin --------------------------------------------------------------------------

  /// Index: reports (status ASC, createdAt DESC) when filtered.
  @override
  Stream<List<Report>> watchAll({ReportStatus? status, int limit = 300}) {
    Query<Map<String, dynamic>> q = _reports;
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return _guard(q.orderBy('createdAt', descending: true).limit(limit).snapshots().map(_parse));
  }

  Map<String, dynamic> _audit(String adminId, String action, Report r, {String? next, String? reason}) => {
        'actorId': adminId,
        'actorRole': 'admin',
        'action': action,
        'targetType': 'report',
        'targetId': r.id,
        'previousStatus': r.status.name,
        'newStatus': ?next,
        'reason': ?reason,
        'timestamp': FieldValue.serverTimestamp(),
      };

  @override
  Future<void> assign(Report report, {required String adminId}) async {
    if (report.status.isClosed) throw const ReportFailure(ReportFailureType.conflict);
    try {
      final batch = _db.batch()
        ..update(_reports.doc(report.id), {'assignedTo': adminId, 'updatedAt': FieldValue.serverTimestamp()})
        ..set(_db.collection('audit_logs').doc(), _audit(adminId, 'report.assign', report));
      await batch.commit();
    } catch (e) {
      throw ReportFailure.from(e);
    }
  }

  /// Moves only if the report is still in [expected] (another admin may act too).
  Future<void> _transition(
    Report report,
    ReportStatus expected,
    Map<String, dynamic> changes,
    Map<String, dynamic> audit, {
    Map<String, dynamic>? notification,
  }) async {
    final ref = _reports.doc(report.id);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists || snap.data()?['status'] != expected.name) {
          throw const ReportFailure(ReportFailureType.conflict);
        }
        tx.update(ref, changes);
        tx.set(_db.collection('audit_logs').doc(), audit);
        if (notification != null) tx.set(_db.collection('notifications').doc(), notification);
      });
    } catch (e) {
      throw ReportFailure.from(e);
    }
  }

  @override
  Future<void> startInvestigation(Report report, {required String adminId}) {
    if (!ReportPolicy.canTransition(report.status, ReportStatus.investigating)) {
      throw const ReportFailure(ReportFailureType.conflict);
    }
    return _transition(
      report,
      ReportStatus.open,
      {
        'status': ReportStatus.investigating.name,
        'assignedTo': report.assignedTo ?? adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      _audit(adminId, 'report.investigate', report, next: ReportStatus.investigating.name),
    );
  }

  @override
  Future<void> close(
    Report report, {
    required ReportStatus to,
    required String note,
    required ResolutionAction action,
    required String adminId,
    required bool notifyReporter,
  }) {
    if (!ReportPolicy.canTransition(report.status, to)) throw const ReportFailure(ReportFailureType.conflict);
    final problem = ReportPolicy.checkResolution(note);
    if (problem != null) throw ReportFailure(ReportFailureType.invalid, problem);
    final clean = note.trim();
    final resolved = to == ReportStatus.resolved;

    return _transition(
      report,
      ReportStatus.investigating,
      {
        'status': to.name,
        'resolution': clean,
        'resolutionAction': resolved ? action.name : ResolutionAction.none.name,
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      _audit(adminId, resolved ? 'report.resolve' : 'report.reject', report, next: to.name, reason: clean),
      notification: notifyReporter
          ? {
              'userId': report.reporterId,
              'type': 'reportUpdated',
              'title': resolved ? 'Signalement traité' : 'Signalement examiné',
              'body': _cap(resolved
                  ? 'Merci : votre signalement « ${_cap(report.target.label, 80)} » a été traité. $clean'
                  : 'Votre signalement « ${_cap(report.target.label, 80)} » a été examiné sans suite : $clean'),
              'read': false,
              'readAt': null,
              'propertyId': ?report.target.propertyId,
              'createdAt': FieldValue.serverTimestamp(),
            }
          : null,
    );
  }
}
