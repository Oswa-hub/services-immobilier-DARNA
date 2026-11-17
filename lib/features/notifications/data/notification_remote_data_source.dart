import 'package:cloud_firestore/cloud_firestore.dart';

typedef RawNotification = ({String id, Map<String, dynamic> data});

/// Thin Firestore access for Module 12. Rules (firestore.rules) allow the
/// recipient to read, mark read (`read`, `readAt`) and delete; never create.
class NotificationRemoteDataSource {
  NotificationRemoteDataSource(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('notifications');
  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  static List<RawNotification> _raw(QuerySnapshot<Map<String, dynamic>> s) =>
      [for (final d in s.docs) (id: d.id, data: d.data())];

  /// Index: notifications (userId ASC, createdAt DESC).
  Stream<List<RawNotification>> watchForUser(String userId, {required int limit}) => _col
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_raw);

  /// Two equality filters: served by single-field indexes.
  Stream<int> watchUnreadCount(String userId, {required int cap}) => _col
      .where('userId', isEqualTo: userId)
      .where('read', isEqualTo: false)
      .limit(cap)
      .snapshots()
      .map((s) => s.size);

  Future<void> markRead(String id) =>
      _col.doc(id).update({'read': true, 'readAt': FieldValue.serverTimestamp()});

  /// Batches of 400 (Firestore limit is 500 writes per batch).
  Future<int> markAllRead(String userId) async {
    var total = 0;
    while (true) {
      final page = await _col
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .limit(400)
          .get();
      if (page.docs.isEmpty) return total;
      final batch = _db.batch();
      for (final d in page.docs) {
        batch.update(d.reference, {'read': true, 'readAt': FieldValue.serverTimestamp()});
      }
      await batch.commit();
      total += page.docs.length;
      if (page.docs.length < 400) return total;
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<Map<String, dynamic>?> readPreferences(String userId) async {
    final snap = await _user(userId).get();
    final raw = snap.data()?['notificationPreferences'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  /// `notificationPreferences` is one of the fields a user may update on their profile.
  Future<void> writePreferences(String userId, Map<String, bool> prefs) =>
      _user(userId).update({'notificationPreferences': prefs});

  Future<void> upsertDevice({required String userId, required String token, required String platform}) =>
      _user(userId).collection('devices').doc(token).set({
        'token': token,
        'platform': platform,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteDevice({required String userId, required String token}) =>
      _user(userId).collection('devices').doc(token).delete();
}
