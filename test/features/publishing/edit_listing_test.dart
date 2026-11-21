import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_app/features/auth/providers/auth_provider.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';
import 'package:team_app/features/publishing/data/property_write_mapper.dart';
import 'package:team_app/features/publishing/domain/entities/listing_draft.dart';
import 'package:team_app/features/publishing/domain/services/listing_validator.dart' show PublishStep;
import 'package:team_app/features/publishing/domain/usecases/submit_listing.dart';
import 'package:team_app/features/publishing/presentation/providers/publishing_provider.dart';
import 'package:team_app/features/settings/domain/platform_settings.dart';
import 'package:team_app/features/settings/presentation/providers/platform_settings_providers.dart';
import 'test_support.dart';

const _cover = 'https://res.cloudinary.com/demo/image/upload/cover.jpg';
const _second = 'https://res.cloudinary.com/demo/image/upload/second.jpg';

Property listing({
  String ownerId = 'u1',
  String? agentId,
  PropertyStatus status = PropertyStatus.published,
  String? area = 'Centre',
  double? lat = 36.88,
}) =>
    Property(
      id: 'L1',
      ownerId: ownerId,
      agentId: agentId,
      title: 'Bright S+2 apartment in La Marsa',
      description: 'Apartment with balcony and parking, close to the beach.',
      transactionType: TransactionType.rent,
      propertyType: PropertyType.apartment,
      price: 1800,
      currency: 'TND',
      surface: 110.5,
      bedrooms: 2,
      bathrooms: 1,
      governorate: 'Tunis',
      city: 'La Marsa',
      area: area,
      latitude: lat,
      longitude: lat == null ? null : 10.32,
      images: const [_cover, _second],
      amenities: const ['parking'],
      status: status,
      verificationStatus: VerificationStatus.notSubmitted,
    );

void main() {
  group('ListingDraft.fromProperty', () {
    test('fills every field and keeps the photos online', () {
      final d = ListingDraft.fromProperty(listing());
      expect(d.propertyType, PropertyType.apartment);
      expect(d.transactionType, TransactionType.rent);
      expect(d.priceText, '1800');
      expect(d.surfaceText, '110.5');
      expect(d.bedrooms, 2);
      expect(d.area, 'Centre');
      expect(d.coordinates, const ListingCoordinates(36.88, 10.32));
      expect(d.amenities, {'parking'});
      expect([for (final p in d.photos) p.remoteUrl], [_cover, _second]);
      expect(d.photos.every((p) => p.isRemote), isTrue);
    });
  });

  group('SubmitListing in edit mode', () {
    test('keeps online photos, uploads only new ones, updates instead of creating', () async {
      final repo = FakeListingRepository();
      final base = ListingDraft.fromProperty(listing());
      final draft = base.copyWith(photos: [...base.photos, photo('new')], title: 'Bright S+2 near the beach');

      await SubmitListing(repo)(listingId: 'L1', user: owner, draft: draft, uploaded: {}, isEdit: true);

      expect(repo.uploadCalls, ['new']);
      expect(repo.created, isEmpty);
      expect(repo.updated.single['id'], 'L1');
      expect(repo.updated.single['urls'], [_cover, _second, 'https://res.cloudinary.com/demo/image/upload/new.jpg']);
    });
  });

  group('PropertyWriteMapper.editedListing', () {
    test('sends the listing back to moderation and never touches ownership or counters', () {
      final m = PropertyWriteMapper.editedListing(
        draft: ListingDraft.fromProperty(listing()),
        imageUrls: const [_cover],
      );
      expect(m['status'], 'pending_review');
      expect(m['images'], [_cover]);
      for (final k in ['ownerId', 'agentId', 'ownerRole', 'views', 'favoritesCount', 'createdAt', 'publishedAt', 'verificationStatus']) {
        expect(m.containsKey(k), isFalse, reason: k);
      }
    });

    test('optional fields the user cleared are deleted', () {
      final m = PropertyWriteMapper.editedListing(
        draft: ListingDraft.fromProperty(listing(area: null, lat: null)),
        imageUrls: const [_cover],
      );
      expect(m['area'], isA<FieldValue>());
      expect(m['latitude'], isA<FieldValue>());
      expect(m['longitude'], isA<FieldValue>());
    });
  });

  group('PublishingController.startEditing', () {
    ProviderContainer container(FakeListingRepository repo) {
      final c = ProviderContainer(overrides: [
        listingRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(owner),
        platformSettingsProvider.overrideWithValue(PlatformSettings.defaults),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('opens my listing on the preview, then submits an update', () async {
      final repo = FakeListingRepository()..listings['L1'] = listing();
      final c = container(repo);
      final n = c.read(publishingControllerProvider.notifier);

      expect(await n.startEditing('L1'), isNull);
      final s = c.read(publishingControllerProvider);
      expect(s.isEdit, isTrue);
      expect(s.step, PublishStep.preview);
      expect(s.draft.title, 'Bright S+2 apartment in La Marsa');

      await n.submit();
      expect(c.read(publishingControllerProvider).isSuccess, isTrue);
      expect(repo.updated.single['id'], 'L1');
      expect(repo.created, isEmpty);
      expect(repo.uploadCalls, isEmpty);
    });

    test("refuses someone else's listing, a missing one and a removed one", () async {
      final repo = FakeListingRepository()
        ..listings['other'] = listing(ownerId: 'someone')
        ..listings['gone'] = listing(status: PropertyStatus.removed);
      final n = container(repo).read(publishingControllerProvider.notifier);

      expect(await n.startEditing('other'), isNotNull);
      expect(await n.startEditing('missing'), isNotNull);
      expect(await n.startEditing('gone'), isNotNull);
    });

    test('the agent who manages a listing may edit it', () async {
      final repo = FakeListingRepository()..listings['L1'] = listing(ownerId: 'someone', agentId: 'u1');
      final n = container(repo).read(publishingControllerProvider.notifier);
      expect(await n.startEditing('L1'), isNull);
    });
  });
}
