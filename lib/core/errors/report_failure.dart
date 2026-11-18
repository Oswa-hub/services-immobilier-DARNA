import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';

enum ReportFailureType { duplicate, invalid, permissionDenied, network, indexMissing, conflict, unknown }

/// The only exception the reports repository throws (Module 14).
class ReportFailure implements Exception {
  const ReportFailure(this.type, [this.detail]);

  final ReportFailureType type;
  final String? detail;

  String get message =>
      detail ??
      switch (type) {
        ReportFailureType.duplicate => 'Vous avez déjà signalé cet élément. Notre équipe l’examine.',
        ReportFailureType.invalid => 'Signalement invalide.',
        ReportFailureType.permissionDenied => 'Action refusée. Reconnectez-vous puis réessayez.',
        ReportFailureType.network => 'Connexion impossible. Vérifiez votre réseau et réessayez.',
        ReportFailureType.indexMissing => 'Index Firestore manquant ou en cours de création. Réessayez plus tard.',
        ReportFailureType.conflict => 'Ce signalement a changé entre-temps. Actualisez puis réessayez.',
        ReportFailureType.unknown => 'Une erreur est survenue. Veuillez réessayer.',
      };

  static ReportFailure from(Object e) {
    if (e is ReportFailure) return e;
    if (e is FirebaseException) {
      debugPrint('Reports Firestore error [${e.code}]: ${e.message}');
      return ReportFailure(switch (e.code) {
        'permission-denied' || 'unauthenticated' => ReportFailureType.permissionDenied,
        'unavailable' || 'deadline-exceeded' || 'network-request-failed' => ReportFailureType.network,
        'failed-precondition' => ReportFailureType.indexMissing,
        'aborted' || 'not-found' => ReportFailureType.conflict,
        'already-exists' => ReportFailureType.duplicate,
        _ => ReportFailureType.unknown,
      });
    }
    debugPrint('Reports unexpected error: $e');
    return const ReportFailure(ReportFailureType.unknown);
  }

  @override
  String toString() => 'ReportFailure($type)';
}
