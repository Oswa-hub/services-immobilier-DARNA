import 'package:flutter_test/flutter_test.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';

Property listing({PropertyStatus status = PropertyStatus.published, DateTime? expiresAt}) => Property(
      id: 'p1',
      ownerId: 'o1',
      title: 'Villa',
      transactionType: TransactionType.buy,
      propertyType: PropertyType.villa,
      price: 1,
      currency: 'TND',
      governorate: 'Tunis',
      status: status,
      verificationStatus: VerificationStatus.notSubmitted,
      expiresAt: expiresAt,
    );

void main() {
  final past = DateTime.now().subtract(const Duration(days: 1));
  final future = DateTime.now().add(const Duration(days: 1));

  test('a published listing past its expiry date is hidden (I2)', () {
    expect(listing(expiresAt: past).isExpired, isTrue);
    expect(listing(expiresAt: past).isPublic, isFalse);
  });

  test('no expiry date, or a future one: still public', () {
    expect(listing().isPublic, isTrue);
    expect(listing(expiresAt: future).isPublic, isTrue);
  });

  test('only a published listing can be expired', () {
    expect(listing(status: PropertyStatus.draft, expiresAt: past).isExpired, isFalse);
  });
}
