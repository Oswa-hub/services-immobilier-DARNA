import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';

enum AdminFailureType {
  /// Rules refused: not an admin, or a forbidden change (e.g. own role).
  permissionDenied,
  network,

  /// A Firestore index is missing / still building.
  indexMissing,

  /// The document changed meanwhile, or the move is not allowed from its state.
  conflict,

  /// Invalid input (caught before reaching Firestore).
  invalid,
  unknown,
}

/// The only exception thrown by the admin, content (Module 16) and settings
/// (Module 17) repositories. Messages are French, ready for a SnackBar.
class AdminFailure implements Exception {
  const AdminFailure(this.type, [this.detail]);

  final AdminFailureType type;
  final String? detail;

  String get message =>
      detail ??
      switch (type) {
        AdminFailureType.permissionDenied => 'Action refusée : droits administrateur requis.',
        AdminFailureType.network => 'Connexion impossible. Vérifiez votre réseau et réessayez.',
        AdminFailureType.indexMissing => 'Index Firestore manquant ou en cours de création. Réessayez plus tard.',
        AdminFailureType.conflict => 'Cet élément a changé entre-temps. Actualisez puis réessayez.',
        AdminFailureType.invalid => 'Données invalides.',
        AdminFailureType.unknown => 'Une erreur est survenue. Veuillez réessayer.',
      };

  static AdminFailure from(Object e) {
    if (e is AdminFailure) return e;
    if (e is FirebaseException) {
      debugPrint('Admin Firestore error [${e.code}]: ${e.message}');
      return AdminFailure(switch (e.code) {
        'permission-denied' || 'unauthenticated' => AdminFailureType.permissionDenied,
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => AdminFailureType.network,
        'failed-precondition' => AdminFailureType.indexMissing,
        'aborted' || 'not-found' => AdminFailureType.conflict,
        _ => AdminFailureType.unknown,
      });
    }
    debugPrint('Admin unexpected error: $e');
    return const AdminFailure(AdminFailureType.unknown);
  }

  @override
  String toString() => 'AdminFailure($type${detail == null ? '' : ': $detail'})';
}
