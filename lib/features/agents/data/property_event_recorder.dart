import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../properties/domain/entities/property.dart';

/// Records analytics EVENTS (spec §14.4: `property_view`) and, on the Spark plan
/// (no Cloud Function), bumps the listing's public `views` counter itself: once
/// per listing per app session (I1; rules: counterBump).
/// Failures are swallowed: tracking must never break a screen.
class PropertyEventRecorder {
  PropertyEventRecorder(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Listings already counted in this session.
  static final Set<String> _counted = {};

  Future<void> recordView(Property p) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // The professional or owner opening their own listing is not a view.
    if (uid == p.ownerId || uid == p.agentId) return;
    try {
      await _db.collection('property_events').add({
        'type': 'property_view',
        'propertyId': p.id,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    if (p.status != PropertyStatus.published || !_counted.add(p.id)) return;
    try {
      await _db.collection('properties').doc(p.id).update({'views': FieldValue.increment(1)});
    } catch (_) {
      _counted.remove(p.id);
    }
  }
}

final propertyEventRecorderProvider = Provider<PropertyEventRecorder>(
  (ref) => PropertyEventRecorder(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider)),
);
