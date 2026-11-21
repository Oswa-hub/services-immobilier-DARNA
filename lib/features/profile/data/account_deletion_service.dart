import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../properties/domain/entities/property.dart';
import '../../properties/domain/listing_lifecycle.dart';

/// Why an account could not be deleted.
enum AccountDeletionProblem {
  /// Firebase asks for a fresh sign-in before deleting an account.
  recentLoginRequired,

  /// Network or unexpected error: nothing important was lost, try again.
  failed,
}

/// Deletes the signed-in account (Google Play requires it in the app).
///
/// Order matters: the sign-in age is checked FIRST, so a refusal from Firebase
/// Auth never leaves an account with its data half removed. Then, best effort:
/// listings withdrawn, favorites removed, professional profile hidden, profile
/// document deleted; finally the Firebase Auth account itself.
/// Conversations stay for the other participant (their history).
class AccountDeletionService {
  AccountDeletionService(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Firebase refuses `delete()` when the last sign-in is older than ~5 minutes.
  static const recentLogin = Duration(minutes: 4);

  bool get signedInRecently {
    final last = _auth.currentUser?.metadata.lastSignInTime;
    return last != null && DateTime.now().difference(last) < recentLogin;
  }

  /// Null on success.
  Future<AccountDeletionProblem?> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return AccountDeletionProblem.failed;
    if (!signedInRecently) return AccountDeletionProblem.recentLoginRequired;
    final uid = user.uid;

    Future<void> quietly(Future<void> Function() step) async {
      try {
        await step();
      } catch (e) {
        debugPrint('Account deletion step skipped: $e');
      }
    }

    // 1. Listings: withdrawn (status removed) so nobody contacts a deleted account.
    await quietly(() async {
      final mine = await _db.collection('properties').where('ownerId', isEqualTo: uid).get();
      for (final d in mine.docs) {
        final found = PropertyStatus.values.where((s) => s.wire == d.data()['status']);
        if (found.isEmpty || !(ownerLifecycle[found.first]?.contains(PropertyStatus.removed) ?? false)) continue;
        await quietly(() => d.reference.update({'status': PropertyStatus.removed.wire, 'updatedAt': FieldValue.serverTimestamp()}));
      }
    });

    // 2. Favorites.
    await quietly(() async {
      final favs = await _db.collection('favorites').where('userId', isEqualTo: uid).get();
      for (final d in favs.docs) {
        await quietly(() => d.reference.delete());
      }
    });

    // 3. Professional profile: hidden from the public.
    await quietly(() => _db.collection('agent_profiles').doc(uid).update({
          'isPublic': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }));

    // 4. Profile document, then the sign-in account.
    await quietly(() => _db.collection('users').doc(uid).delete());
    try {
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return AccountDeletionProblem.recentLoginRequired;
      return AccountDeletionProblem.failed;
    } catch (_) {
      return AccountDeletionProblem.failed;
    }
  }
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(ref.watch(firestoreProvider), ref.watch(firebaseAuthProvider)),
);
