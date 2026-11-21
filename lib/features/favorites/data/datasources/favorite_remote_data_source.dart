import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

typedef RawFavorite = ({String id, Map<String, dynamic> data});

/// The only favorites class that talks to Firestore.
///
/// The document id is deterministic: `{userId}_{propertyId}`. This makes
/// "add twice" impossible (no duplicates), makes `exists` / `remove` a direct
/// document access (no query) and lets the security rules check ownership.
///
/// No `orderBy` on purpose: `where(userId) + orderBy(createdAt)` would need a
/// composite index. The repository sorts the (small) list in memory instead.
class FavoriteRemoteDataSource {
  FavoriteRemoteDataSource(this._db);

  final FirebaseFirestore _db;

  /// Firestore write futures only complete once the SERVER acknowledged. When the
  /// phone is offline they stay pending (the write itself is queued and applied
  /// later), so we stop waiting after this delay instead of freezing the heart.
  static const _writeTimeout = Duration(seconds: 6);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('favorites');

  static String docId({required String userId, required String propertyId}) => '${userId}_$propertyId';

  /// The favorite and the listing's public `favoritesCount` change in ONE batch
  /// (I1; rules: counterBump accepts +1 / -1 only together with it).
  Future<void> add({required String userId, required String propertyId}) {
    final write = (_db.batch()
          ..set(_col.doc(docId(userId: userId, propertyId: propertyId)), {
            'userId': userId,
            'propertyId': propertyId,
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..update(_db.collection('properties').doc(propertyId), {'favoritesCount': FieldValue.increment(1)}))
        .commit();
    return write.timeout(_writeTimeout, onTimeout: () {});
  }

  Future<void> remove({required String userId, required String propertyId}) async {
    final ref = _col.doc(docId(userId: userId, propertyId: propertyId));
    try {
      // Only an existing favorite of a listing still online lowers the counter.
      final snap = await ref.get().timeout(_writeTimeout);
      if (!snap.exists) return;
      await (_db.batch()
            ..delete(ref)
            ..update(_db.collection('properties').doc(propertyId), {'favoritesCount': FieldValue.increment(-1)}))
          .commit()
          .timeout(_writeTimeout);
    } on FirebaseException catch (e) {
      // The listing left the market (counter locked) or is gone: the favorite is
      // still removed on its own.
      if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
      await ref.delete().timeout(_writeTimeout, onTimeout: () {});
    } on TimeoutException {
      // Offline: delete alone; Firestore sends it when the connection returns.
      await ref.delete().timeout(_writeTimeout, onTimeout: () {});
    }
  }

  Future<bool> exists({required String userId, required String propertyId}) async {
    final snap = await _col.doc(docId(userId: userId, propertyId: propertyId)).get();
    return snap.exists;
  }

  Future<List<RawFavorite>> getForUser(String userId) async {
    final snap = await _col.where('userId', isEqualTo: userId).get();
    return [for (final d in snap.docs) (id: d.id, data: d.data())];
  }

  Stream<List<RawFavorite>> watchForUser(String userId) => _col
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => [for (final d in s.docs) (id: d.id, data: d.data())]);
}