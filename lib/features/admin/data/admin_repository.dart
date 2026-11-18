import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/admin_failure.dart';
import '../../auth/domain/entities/auth_user.dart';
import '../../properties/data/property_mapper.dart';
import '../../properties/domain/entities/property.dart';
import '../domain/admin_analytics.dart';
import '../domain/admin_models.dart';
import '../domain/admin_policy.dart';

/// Module 15 — everything the admin panel reads and writes. Implementations
/// throw only [AdminFailure]. Access control is enforced by firestore.rules
/// (`isAdmin()`); this layer adds the audit trail to every change.
abstract class AdminRepository {
  Future<AdminKpis> loadKpis();

  Stream<List<AdminUser>> watchUsers({AccountStatus? status, int limit = 200});
  Future<void> setUserStatus(AdminUser user, UserAction action, {required String adminId, String? reason});
  Future<void> setUserRole(AdminUser user, UserRole role, {required String adminId});

  Stream<List<Property>> watchProperties({PropertyStatus? status, int limit = 200});

  /// Moves [property] along [action] if it is STILL in the status the admin saw
  /// (transaction), writes the audit log and, when [notifyOwner], the owner's
  /// in-app notification.
  Future<void> moderate(
    Property property,
    ModerationAction action, {
    required String adminId,
    required int expirationDays,
    required bool notifyOwner,
    String? reason,
  });

  /// Writes one notification per recipient (client fan-out: no Cloud Functions
  /// needed). Returns how many were written.
  Future<int> sendNotification({
    required Audience audience,
    required AdminNotificationType type,
    required String title,
    required String body,
    required String adminId,
  });

  Stream<List<AuditEntry>> watchAuditLogs({int limit = 100});

  Future<AdminAnalytics> loadAnalytics({int sample = 1000});
}

class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository(this._db, {DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _properties => _db.collection('properties');
  CollectionReference<Map<String, dynamic>> get _audit => _db.collection('audit_logs');
  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');

  Stream<T> _guard<T>(Stream<T> s) => s.transform(StreamTransformer<T, T>.fromHandlers(
        handleError: (e, st, sink) => sink.addError(AdminFailure.from(e), st),
      ));

  Map<String, dynamic> _auditEntry({
    required String adminId,
    required String action,
    required String targetType,
    required String targetId,
    String? previous,
    String? next,
    String? reason,
    Map<String, dynamic>? details,
  }) =>
      {
        'actorId': adminId,
        'actorRole': 'admin',
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'previousStatus': ?previous,
        'newStatus': ?next,
        'reason': ?reason,
        'details': ?details,
        'timestamp': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _notification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? propertyId,
  }) =>
      {
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'read': false,
        'readAt': null,
        'propertyId': ?propertyId,
        'createdAt': FieldValue.serverTimestamp(),
      };

  // ---- dashboard -------------------------------------------------------------------

  /// One aggregation per number (billed as 1 read per 1000 documents). A count
  /// that fails (missing rule / index) is null instead of breaking the page.
  @override
  Future<AdminKpis> loadKpis() async {
    Future<int?> count(Query<Map<String, dynamic>> q) async {
      try {
        return (await q.count().get()).count;
      } catch (e) {
        AdminFailure.from(e); // logs
        return null;
      }
    }

    final weekAgo = Timestamp.fromDate(_now().subtract(const Duration(days: 7)));
    final r = await Future.wait([
      count(_users),
      count(_users.where('status', isEqualTo: 'active')),
      count(_users.where('createdAt', isGreaterThanOrEqualTo: weekAgo)),
      count(_properties),
      count(_properties.where('status', isEqualTo: 'published')),
      count(_properties.where('status', isEqualTo: 'pending_review')),
      count(_db.collection('verifications').where('status', isEqualTo: 'pending')),
      count(_db.collection('reports').where('status', isEqualTo: 'open')),
    ]);
    return AdminKpis(
      totalUsers: r[0],
      activeUsers: r[1],
      newUsers7d: r[2],
      totalProperties: r[3],
      publishedProperties: r[4],
      pendingListings: r[5],
      pendingVerifications: r[6],
      openReports: r[7],
    );
  }

  // ---- users -------------------------------------------------------------------

  /// Index: users (status ASC, createdAt DESC) when filtered.
  @override
  Stream<List<AdminUser>> watchUsers({AccountStatus? status, int limit = 200}) {
    Query<Map<String, dynamic>> q = _users;
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return _guard(q.orderBy('createdAt', descending: true).limit(limit).snapshots().map(
          (s) => [for (final d in s.docs) ?AdminUser.tryFromMap(d.id, d.data())],
        ));
  }

  @override
  Future<void> setUserStatus(AdminUser user, UserAction action, {required String adminId, String? reason}) async {
    if (user.id == adminId) throw const AdminFailure(AdminFailureType.invalid, 'Vous ne pouvez pas modifier votre propre compte.');
    if (action.needsReason) {
      final problem = AdminPolicy.checkReason(reason);
      if (problem != null) throw AdminFailure(AdminFailureType.invalid, problem);
    }
    final clean = reason?.trim();
    try {
      final batch = _db.batch()
        ..update(_users.doc(user.id), {
          'status': action.target.name,
          'statusReason': action.needsReason ? clean : null,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
          'statusUpdatedBy': adminId,
        })
        ..set(
          _audit.doc(),
          _auditEntry(
            adminId: adminId,
            action: action.auditAction,
            targetType: 'user',
            targetId: user.id,
            previous: user.status.name,
            next: action.target.name,
            reason: action.needsReason ? clean : null,
          ),
        );
      await batch.commit();
    } catch (e) {
      throw AdminFailure.from(e);
    }
  }

  @override
  Future<void> setUserRole(AdminUser user, UserRole role, {required String adminId}) async {
    if (user.id == adminId) throw const AdminFailure(AdminFailureType.invalid, 'Vous ne pouvez pas modifier votre propre rôle.');
    if (user.role == role) return;
    try {
      final batch = _db.batch()
        ..update(_users.doc(user.id), {'role': role.name})
        ..set(
          _audit.doc(),
          _auditEntry(
            adminId: adminId,
            action: 'user.role',
            targetType: 'user',
            targetId: user.id,
            previous: user.role.name,
            next: role.name,
          ),
        );
      await batch.commit();
    } catch (e) {
      throw AdminFailure.from(e);
    }
  }

  // ---- properties -------------------------------------------------------------------

  /// Index: properties (status ASC, createdAt DESC) when filtered.
  @override
  Stream<List<Property>> watchProperties({PropertyStatus? status, int limit = 200}) {
    Query<Map<String, dynamic>> q = _properties;
    if (status != null) q = q.where('status', isEqualTo: status.wire);
    return _guard(q.orderBy('createdAt', descending: true).limit(limit).snapshots().map(
          (s) => [for (final d in s.docs) ?PropertyMapper.tryFromMap(d.id, d.data())],
        ));
  }

  @override
  Future<void> moderate(
    Property property,
    ModerationAction action, {
    required String adminId,
    required int expirationDays,
    required bool notifyOwner,
    String? reason,
  }) async {
    if (!action.from.contains(property.status)) {
      throw const AdminFailure(AdminFailureType.conflict, 'Action impossible depuis le statut actuel.');
    }
    if (action.needsReason) {
      final problem = AdminPolicy.checkReason(reason);
      if (problem != null) throw AdminFailure(AdminFailureType.invalid, problem);
    }
    final clean = reason?.trim();
    final ref = _properties.doc(property.id);

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final current = snap.data()?['status'];
        if (!snap.exists || current != property.status.wire) {
          throw const AdminFailure(AdminFailureType.conflict);
        }

        final changes = <String, dynamic>{
          'status': action.to.wire,
          'updatedAt': FieldValue.serverTimestamp(),
          'moderatedBy': adminId,
          'moderatedAt': FieldValue.serverTimestamp(),
        };
        switch (action) {
          case ModerationAction.approve:
            changes['rejectionReason'] = null;
            changes['moderationReason'] = null;
            changes['expiresAt'] = Timestamp.fromDate(AdminPolicy.expiryFor(_now(), expirationDays));
            // Keep the first publication date (Module 12 alerts fire only once).
            if (snap.data()?['publishedAt'] == null) changes['publishedAt'] = FieldValue.serverTimestamp();
          case ModerationAction.reject:
            changes['rejectionReason'] = clean;
          case ModerationAction.suspend || ModerationAction.remove:
            changes['moderationReason'] = clean;
          case ModerationAction.restore:
            changes['moderationReason'] = null;
        }
        tx.update(ref, changes);

        tx.set(
          _audit.doc(),
          _auditEntry(
            adminId: adminId,
            action: action.auditAction,
            targetType: 'property',
            targetId: property.id,
            previous: property.status.wire,
            next: action.to.wire,
            reason: action.needsReason ? clean : null,
          ),
        );

        final notice = notifyOwner ? AdminPolicy.ownerNotice(action, property.title, reason: clean) : null;
        if (notice != null) {
          final recipients = {property.ownerId, ?property.agentId};
          for (final uid in recipients) {
            tx.set(
              _notifications.doc(),
              _notification(
                userId: uid,
                type: notice.type,
                title: notice.title,
                body: notice.body,
                propertyId: property.id,
              ),
            );
          }
        }
      });
    } catch (e) {
      throw AdminFailure.from(e);
    }
  }

  // ---- notifications -------------------------------------------------------------------

  @override
  Future<int> sendNotification({
    required Audience audience,
    required AdminNotificationType type,
    required String title,
    required String body,
    required String adminId,
  }) async {
    final t = title.trim();
    final b = body.trim();
    if (t.length < 3 || t.length > 80) {
      throw const AdminFailure(AdminFailureType.invalid, 'Le titre doit contenir 3 à 80 caractères.');
    }
    if (b.length < 3 || b.length > 500) {
      throw const AdminFailure(AdminFailureType.invalid, 'Le message doit contenir 3 à 500 caractères.');
    }
    if (type == AdminNotificationType.warning && audience is! SingleUser) {
      throw const AdminFailure(AdminFailureType.invalid, 'Un avertissement vise un seul utilisateur.');
    }

    try {
      final List<String> recipients;
      switch (audience) {
        case SingleUser(:final userId):
          final snap = await _users.doc(userId).get();
          if (!snap.exists) throw const AdminFailure(AdminFailureType.invalid, 'Utilisateur introuvable.');
          recipients = [userId];
        case UsersWithRole(:final role):
          final snap = await _users.where('status', isEqualTo: 'active').where('role', isEqualTo: role.name).get();
          recipients = [for (final d in snap.docs) d.id];
        case AllUsers():
          final snap = await _users.where('status', isEqualTo: 'active').get();
          recipients = [for (final d in snap.docs) d.id];
      }

      // 450 notifications per batch (Firestore max: 500 writes).
      for (var i = 0; i < recipients.length; i += 450) {
        final batch = _db.batch();
        for (final uid in recipients.skip(i).take(450)) {
          batch.set(_notifications.doc(), _notification(userId: uid, type: type.wire, title: t, body: b));
        }
        await batch.commit();
      }

      await _audit.add(_auditEntry(
        adminId: adminId,
        action: 'notification.send',
        targetType: 'notification',
        targetId: switch (audience) {
          SingleUser(:final userId) => userId,
          UsersWithRole(:final role) => 'role:${role.name}',
          AllUsers() => 'all',
        },
        details: {'type': type.wire, 'title': t, 'recipients': recipients.length},
      ));
      return recipients.length;
    } catch (e) {
      throw AdminFailure.from(e);
    }
  }

  // ---- audit / analytics ----------------------------------------------------------------

  @override
  Stream<List<AuditEntry>> watchAuditLogs({int limit = 100}) => _guard(
        _audit.orderBy('timestamp', descending: true).limit(limit).snapshots().map(
              (s) => [for (final d in s.docs) ?AuditEntry.tryFromMap(d.id, d.data())],
            ),
      );

  @override
  Future<AdminAnalytics> loadAnalytics({int sample = 1000}) async {
    try {
      final results = await Future.wait([
        _properties.orderBy('createdAt', descending: true).limit(sample).get(),
        _users.orderBy('createdAt', descending: true).limit(sample).get(),
      ]);
      return computeAnalytics(
        properties: [for (final d in results[0].docs) ?PropertyMapper.tryFromMap(d.id, d.data())],
        users: [for (final d in results[1].docs) ?AdminUser.tryFromMap(d.id, d.data())],
        now: _now(),
      );
    } catch (e) {
      throw AdminFailure.from(e);
    }
  }
}
