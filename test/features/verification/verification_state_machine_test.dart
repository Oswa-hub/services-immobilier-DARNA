import 'package:flutter_test/flutter_test.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';
import 'package:team_app/features/verification/domain/entities/verification_enums.dart';
import 'package:team_app/features/verification/domain/services/verification_state_machine.dart';

void main() {
  const s = VerificationStatus.values;

  group('transitions (spec §5.1)', () {
    test('allowed moves', () {
      expect(VerificationStateMachine.isAllowed(VerificationStatus.notSubmitted, VerificationStatus.pending), isTrue);
      expect(VerificationStateMachine.isAllowed(VerificationStatus.pending, VerificationStatus.approved), isTrue);
      expect(VerificationStateMachine.isAllowed(VerificationStatus.pending, VerificationStatus.rejected), isTrue);
      expect(VerificationStateMachine.isAllowed(VerificationStatus.rejected, VerificationStatus.pending), isTrue);
      expect(VerificationStateMachine.isAllowed(VerificationStatus.expired, VerificationStatus.pending), isTrue);
      expect(VerificationStateMachine.isAllowed(VerificationStatus.approved, VerificationStatus.expired), isTrue);
    });

    test('an applicant can never jump straight to approved', () {
      for (final from in s) {
        if (from == VerificationStatus.pending) continue;
        expect(VerificationStateMachine.isAllowed(from, VerificationStatus.approved), isFalse, reason: '$from -> approved');
      }
    });

    test('approved and rejected cannot be decided again', () {
      expect(VerificationStateMachine.canReview(VerificationStatus.approved), isFalse);
      expect(VerificationStateMachine.canReview(VerificationStatus.rejected), isFalse);
      expect(VerificationStateMachine.canReview(VerificationStatus.pending), isTrue);
    });

    test('submit is allowed only from not_submitted, rejected, expired', () {
      expect(VerificationStateMachine.canSubmit(VerificationStatus.notSubmitted), isTrue);
      expect(VerificationStateMachine.canSubmit(VerificationStatus.rejected), isTrue);
      expect(VerificationStateMachine.canSubmit(VerificationStatus.expired), isTrue);
      expect(VerificationStateMachine.canSubmit(VerificationStatus.pending), isFalse);
      expect(VerificationStateMachine.canSubmit(VerificationStatus.approved), isFalse);
    });

    test('history action', () {
      expect(VerificationStateMachine.actionFor(VerificationStatus.notSubmitted, VerificationStatus.pending),
          VerificationAction.submitted);
      expect(VerificationStateMachine.actionFor(VerificationStatus.rejected, VerificationStatus.pending),
          VerificationAction.resubmitted);
      expect(VerificationStateMachine.actionFor(VerificationStatus.pending, VerificationStatus.approved),
          VerificationAction.approved);
      expect(VerificationStateMachine.actionFor(VerificationStatus.approved, VerificationStatus.pending), isNull);
    });
  });

  group('rejection reason (spec §17.2)', () {
    test('required and bounded', () {
      expect(VerificationStateMachine.validateRejectionReason(null), isNotNull);
      expect(VerificationStateMachine.validateRejectionReason('   '), isNotNull);
      expect(VerificationStateMachine.validateRejectionReason('abc'), isNotNull);
      expect(VerificationStateMachine.validateRejectionReason('Document is unreadable'), isNull);
      expect(VerificationStateMachine.validateRejectionReason('x' * 501), isNotNull);
    });
  });
}
