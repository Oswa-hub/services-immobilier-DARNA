import '../../../properties/domain/entities/property.dart';
import '../entities/verification_enums.dart';
import 'verification_policy.dart';

/// Allowed transitions (spec §5.1). The Firestore rules enforce the same table;
/// this class lets the UI hide impossible actions and the repository fail fast.
///
///   not_submitted -> pending            (submit)
///   pending       -> approved|rejected  (admin)
///   rejected      -> pending            (resubmit)
///   expired       -> pending            (resubmit)
///   approved      -> expired            (admin / validity ended)
class VerificationStateMachine {
  const VerificationStateMachine._();

  static bool canSubmit(VerificationStatus s) =>
      s == VerificationStatus.notSubmitted || s == VerificationStatus.rejected || s == VerificationStatus.expired;

  static bool canReview(VerificationStatus s) => s == VerificationStatus.pending;

  static bool canExpire(VerificationStatus s) => s == VerificationStatus.approved;

  static bool isAllowed(VerificationStatus from, VerificationStatus to) => switch (from) {
        VerificationStatus.notSubmitted => to == VerificationStatus.pending,
        VerificationStatus.pending => to == VerificationStatus.approved || to == VerificationStatus.rejected,
        VerificationStatus.rejected => to == VerificationStatus.pending,
        VerificationStatus.expired => to == VerificationStatus.pending,
        VerificationStatus.approved => to == VerificationStatus.expired,
      };

  /// The history action for a move from [from] to [to].
  static VerificationAction? actionFor(VerificationStatus from, VerificationStatus to) {
    if (!isAllowed(from, to)) return null;
    return switch (to) {
      VerificationStatus.pending =>
        from == VerificationStatus.notSubmitted ? VerificationAction.submitted : VerificationAction.resubmitted,
      VerificationStatus.approved => VerificationAction.approved,
      VerificationStatus.rejected => VerificationAction.rejected,
      VerificationStatus.expired => VerificationAction.expired,
      VerificationStatus.notSubmitted => null,
    };
  }

  /// A rejection needs a meaningful reason (spec §17.2).
  static String? validateRejectionReason(String? reason) {
    final r = reason?.trim() ?? '';
    if (r.length < VerificationPolicy.rejectionReasonMin) {
      return 'Please explain what must be corrected (at least ${VerificationPolicy.rejectionReasonMin} characters).';
    }
    if (r.length > VerificationPolicy.rejectionReasonMax) {
      return 'The reason is too long (max ${VerificationPolicy.rejectionReasonMax} characters).';
    }
    return null;
  }
}
