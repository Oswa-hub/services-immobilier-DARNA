import 'package:flutter_test/flutter_test.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';
import 'package:team_app/features/verification/domain/entities/verification_enums.dart';
import 'package:team_app/features/verification/domain/entities/verification_record.dart';
import 'package:team_app/features/verification/domain/services/verification_policy.dart';

VerificationRecord record(VerificationStatus s, {DateTime? expiresAt}) => VerificationRecord(
      id: 'agent_u1',
      applicantId: 'u1',
      targetId: 'u1',
      targetType: VerificationTargetType.agent,
      status: s,
      expiresAt: expiresAt,
    );

void main() {
  test('no validity policy is invented (spec §5.3)', () {
    for (final t in VerificationTargetType.values) {
      expect(VerificationPolicy.validityFor(t), isNull);
      expect(VerificationPolicy.expiresAtFor(t, DateTime(2026)), isNull);
    }
  });

  test('deterministic request id: one request per target and type', () {
    expect(VerificationTargetType.property.docId('P1'), 'property_P1');
    expect(VerificationTargetType.owner.docId('u1'), isNot(VerificationTargetType.user.docId('u1')));
  });

  test('effective status', () {
    final now = DateTime(2026, 6, 1);
    expect(record(VerificationStatus.approved).effectiveStatus(now), VerificationStatus.approved);
    expect(record(VerificationStatus.approved, expiresAt: DateTime(2026, 5, 1)).effectiveStatus(now), VerificationStatus.expired);
    expect(record(VerificationStatus.approved, expiresAt: DateTime(2027)).effectiveStatus(now), VerificationStatus.approved);
    expect(record(VerificationStatus.pending, expiresAt: DateTime(2026, 5, 1)).effectiveStatus(now), VerificationStatus.pending);
  });

  test('status wire values round-trip with VerificationStatus.parse', () {
    for (final s in VerificationStatus.values) {
      expect(VerificationStatus.parse(s.wire), s);
    }
  });
}
