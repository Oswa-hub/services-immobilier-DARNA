import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/admin_failure.dart';
import '../domain/platform_settings.dart';

abstract class PlatformSettingsRepository {
  /// Live settings; defaults while the document does not exist.
  Stream<PlatformSettings> watch();

  /// Admin only (rules). Writes the audit log in the same batch.
  Future<void> save(PlatformSettings settings, {required String adminId});
}

class FirestorePlatformSettingsRepository implements PlatformSettingsRepository {
  FirestorePlatformSettingsRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('settings').doc('platform');

  @override
  Stream<PlatformSettings> watch() => _doc.snapshots().map((s) {
        final data = s.data();
        final ts = data?['updatedAt'];
        return PlatformSettings.fromMap(data, updatedAt: ts is Timestamp ? ts.toDate() : null);
      }).transform(StreamTransformer<PlatformSettings, PlatformSettings>.fromHandlers(
        handleError: (e, st, sink) => sink.addError(AdminFailure.from(e), st),
      ));

  @override
  Future<void> save(PlatformSettings settings, {required String adminId}) async {
    final errors = settings.validate();
    if (errors.isNotEmpty) throw AdminFailure(AdminFailureType.invalid, errors.values.first);
    try {
      final batch = _db.batch()
        ..set(_doc, {
          ...settings.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': adminId,
        })
        ..set(_db.collection('audit_logs').doc(), {
          'actorId': adminId,
          'actorRole': 'admin',
          'action': 'settings.update',
          'targetType': 'settings',
          'targetId': 'platform',
          'timestamp': FieldValue.serverTimestamp(),
        });
      await batch.commit();
    } catch (e) {
      throw AdminFailure.from(e);
    }
  }
}
