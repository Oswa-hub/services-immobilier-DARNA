import 'package:flutter_test/flutter_test.dart';
import 'package:team_app/features/listings/domain/listing_actions.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';

void main() {
  group('ownerTransitions (Module 09)', () {
    // Lifecycle fixed in 88ae9e9 (Modules 08-10): owners can also withdraw.
    test('a draft can be submitted for review or withdrawn', () {
      expect(ownerTransitions(PropertyStatus.draft), {PropertyStatus.pendingReview, PropertyStatus.removed});
    });

    test('a published listing can only be withdrawn', () {
      expect(ownerTransitions(PropertyStatus.published), {PropertyStatus.removed});
    });

    test('a rejected listing can be edited, resubmitted or withdrawn; a withdrawn one goes back to draft', () {
      expect(ownerTransitions(PropertyStatus.rejected),
          {PropertyStatus.draft, PropertyStatus.pendingReview, PropertyStatus.removed});
      expect(ownerTransitions(PropertyStatus.removed), {PropertyStatus.draft});
    });

    test('pending and expired listings can only be withdrawn; suspended ones are locked', () {
      expect(ownerTransitions(PropertyStatus.pendingReview), {PropertyStatus.removed});
      expect(ownerTransitions(PropertyStatus.expired), {PropertyStatus.removed});
      expect(ownerTransitions(PropertyStatus.suspended), isEmpty);
    });

    test('an owner can never publish directly', () {
      for (final s in PropertyStatus.values) {
        expect(ownerTransitions(s), isNot(contains(PropertyStatus.published)), reason: s.name);
      }
    });
  });

  group('ownerCanDelete', () {
    test('only drafts, rejected and withdrawn listings can be deleted', () {
      expect(ownerCanDelete(PropertyStatus.draft), isTrue);
      expect(ownerCanDelete(PropertyStatus.rejected), isTrue);
      expect(ownerCanDelete(PropertyStatus.removed), isTrue);
      expect(ownerCanDelete(PropertyStatus.published), isFalse);
      expect(ownerCanDelete(PropertyStatus.pendingReview), isFalse);
      expect(ownerCanDelete(PropertyStatus.suspended), isFalse);
      expect(ownerCanDelete(PropertyStatus.expired), isFalse);
    });
  });

  test('every status has a tab in My Listings', () {
    expect(myListingsTabs.toSet(), PropertyStatus.values.toSet());
  });
}