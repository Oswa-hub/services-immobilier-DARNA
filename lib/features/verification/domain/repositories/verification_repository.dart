import '../../../properties/domain/entities/property.dart';
import '../entities/verification_record.dart';
import '../entities/verification_submission.dart';

/// Module 13 contract (spec §11). Applicant and administrator operations share
/// one repository; WHO may do WHAT is decided by Firestore rules, not by the UI.
abstract class VerificationRepository {
  // ---- applicant ----
  /// Requests the signed-in user submitted (`getMyVerificationRequests`).
  Stream<List<VerificationRecord>> watchMyVerifications();

  /// One request; null when it does not exist (= `not_submitted`).
  Stream<VerificationRecord?> watchVerification(String verificationId);
  Future<VerificationRecord?> getVerification(String verificationId);

  /// Chronological history. Applicant: own request. Admin: any.
  Stream<List<VerificationHistoryEntry>> watchHistory(String verificationId);

  /// Uploads the files to private storage, then creates the request (first
  /// attempt) or resubmits it (after `rejected` / `expired`). Nothing is
  /// created when an upload fails.
  Future<void> submit(VerificationSubmission submission);

  // ---- administrator ----
  Stream<List<VerificationRecord>> watchByStatus(VerificationStatus status, {int limit = 100});
  Future<void> approve(String verificationId);
  Future<void> reject(String verificationId, String reason);
  Future<void> markExpired(String verificationId);

  /// Short-lived link to ONE private document, minted by the trusted backend.
  Future<Uri> documentLink(String verificationId, String documentId);
}
