import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/admin_failure.dart';
import '../domain/catalog.dart';

abstract class CatalogRepository {
  /// Live list; [CatalogKey.defaults] while the document does not exist.
  Stream<List<CatalogItem>> watch(CatalogKey key);

  /// Admin only (rules). Replaces the whole list and writes an audit entry.
  Future<void> save(CatalogKey key, List<CatalogItem> items, {required String adminId});
}

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<CatalogItem>> watch(CatalogKey key) => _db
      .collection('catalog')
      .doc(key.docId)
      .snapshots()
      .map((s) {
        final raw = s.data()?['items'];
        if (!s.exists || raw is! List) return CatalogEditor.reconcile(key, key.defaults);
        return CatalogEditor.reconcile(key, [for (final r in raw) ?CatalogItem.tryFromMap(r)]);
      })
      .transform(StreamTransformer<List<CatalogItem>, List<CatalogItem>>.fromHandlers(
        handleError: (e, st, sink) => sink.addError(AdminFailure.from(e), st),
      ));

  @override
  Future<void> save(CatalogKey key, List<CatalogItem> items, {required String adminId}) async {
    if (items.length > CatalogEditor.maxItems) {
      throw const AdminFailure(AdminFailureType.invalid, 'Liste trop longue.');
    }
    try {
      final batch = _db.batch()
        ..set(_db.collection('catalog').doc(key.docId), {
          'items': [for (final i in CatalogEditor.sorted(items)) i.toMap()],
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': adminId,
        })
        ..set(_db.collection('audit_logs').doc(), {
          'actorId': adminId,
          'actorRole': 'admin',
          'action': 'content.update',
          'targetType': 'catalog',
          'targetId': key.docId,
          'details': {'items': items.length},
          'timestamp': FieldValue.serverTimestamp(),
        });
      await batch.commit();
    } catch (e) {
      throw AdminFailure.from(e);
    }
  }
}
