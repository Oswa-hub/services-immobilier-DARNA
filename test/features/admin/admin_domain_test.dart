// Modules 15 / 16 / 17 — pure logic (no Firebase).
// Run: flutter test test/features/admin
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter_test/flutter_test.dart';

import 'package:team_app/features/admin/domain/admin_analytics.dart';
import 'package:team_app/features/admin/domain/admin_models.dart';
import 'package:team_app/features/admin/domain/admin_policy.dart';
import 'package:team_app/features/auth/domain/entities/auth_user.dart';
import 'package:team_app/features/content/domain/catalog.dart';
import 'package:team_app/features/properties/domain/entities/amenity.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';
import 'package:team_app/features/settings/domain/platform_settings.dart';

Property _p(
  String id, {
  PropertyStatus status = PropertyStatus.published,
  TransactionType tx = TransactionType.buy,
  PropertyType type = PropertyType.apartment,
  num price = 100000,
  String governorate = 'Tunis',
  DateTime? createdAt,
  int views = 0,
  int favorites = 0,
}) =>
    Property(
      id: id,
      ownerId: 'o1',
      title: 'Bien $id',
      transactionType: tx,
      propertyType: type,
      price: price,
      currency: 'TND',
      governorate: governorate,
      status: status,
      verificationStatus: VerificationStatus.notSubmitted,
      createdAt: createdAt,
      views: views,
      favoritesCount: favorites,
    );

void main() {
  // ---------------------------------------------------------------- Module 15
  group('AdminPolicy — users', () {
    const target = AdminUser(id: 'u1', email: 'u1@x.tn');

    test('never on your own account', () {
      expect(AdminPolicy.userActions(target, actorId: 'u1'), isEmpty);
      expect(AdminPolicy.canChangeRole(target, actorId: 'u1'), isFalse);
    });

    test('offers only real changes', () {
      expect(AdminPolicy.userActions(target, actorId: 'admin'),
          [UserAction.suspend, UserAction.ban, UserAction.delete]);
      const suspended = AdminUser(id: 'u2', email: 'x', status: AccountStatus.suspended);
      expect(AdminPolicy.userActions(suspended, actorId: 'admin'),
          [UserAction.restore, UserAction.ban, UserAction.delete]);
    });

    test('deleted accounts keep their role', () {
      const deleted = AdminUser(id: 'u3', email: 'x', status: AccountStatus.deleted);
      expect(AdminPolicy.canChangeRole(deleted, actorId: 'admin'), isFalse);
    });
  });

  group('AdminPolicy — listings', () {
    test('actions follow the listing lifecycle', () {
      expect(AdminPolicy.moderationActions(PropertyStatus.pendingReview),
          [ModerationAction.approve, ModerationAction.reject, ModerationAction.remove]);
      expect(AdminPolicy.moderationActions(PropertyStatus.published),
          [ModerationAction.suspend, ModerationAction.remove]);
      expect(AdminPolicy.moderationActions(PropertyStatus.suspended),
          [ModerationAction.restore, ModerationAction.remove]);
      expect(AdminPolicy.moderationActions(PropertyStatus.draft), isEmpty);
      expect(AdminPolicy.moderationActions(PropertyStatus.removed), isEmpty);
    });

    test('targets', () {
      expect(ModerationAction.approve.to, PropertyStatus.published);
      expect(ModerationAction.reject.to, PropertyStatus.rejected);
      expect(ModerationAction.reject.needsReason, isTrue);
      expect(ModerationAction.approve.needsReason, isFalse);
    });

    test('reason checks', () {
      expect(AdminPolicy.checkReason(null), isNotNull);
      expect(AdminPolicy.checkReason('  abc '), isNotNull);
      expect(AdminPolicy.checkReason('Photos floues'), isNull);
      expect(AdminPolicy.checkReason('x' * 501), isNotNull);
    });

    test('expiry uses the platform setting', () {
      expect(AdminPolicy.expiryFor(DateTime.utc(2026, 1, 1), 90), DateTime.utc(2026, 4, 1));
    });

    test('owner notices (French) match Module 12 types', () {
      final approved = AdminPolicy.ownerNotice(ModerationAction.approve, 'Villa')!;
      expect(approved.type, 'listingApproved');
      expect(approved.body, '« Villa » est maintenant en ligne.');
      final rejected = AdminPolicy.ownerNotice(ModerationAction.reject, 'Villa', reason: 'Photos floues')!;
      expect(rejected.type, 'listingRejected');
      expect(rejected.body, contains('Photos floues'));
      expect(AdminPolicy.ownerNotice(ModerationAction.remove, 'Villa'), isNull);
    });
  });

  group('Admin models', () {
    test('AdminUser.tryFromMap', () {
      final u = AdminUser.tryFromMap('u1', {
        'email': 'sami@x.tn',
        'name': ' Sami ',
        'role': 'agent',
        'status': 'banned',
        'verified': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
      })!;
      expect(u.displayName, 'Sami');
      expect(u.role, UserRole.agent);
      expect(u.status, AccountStatus.banned);
      expect(u.verified, isTrue);
      expect(u.createdAt, DateTime(2026, 5, 1));
      expect(AdminUser.tryFromMap('u2', {'name': 'x'}), isNull);
      expect(AdminUser.tryFromMap('u3', {'email': 'a@b.c'})!.displayName, 'a@b.c');
    });

    test('AuditEntry reads both app (actorId) and Functions (adminId) entries', () {
      expect(AuditEntry.tryFromMap('a', {'action': 'user.ban', 'actorId': 'x'})!.actorId, 'x');
      expect(AuditEntry.tryFromMap('b', {'action': 'notification.send', 'adminId': 'y'})!.actorId, 'y');
      expect(AuditEntry.tryFromMap('c', {'actorId': 'x'}), isNull);
    });
  });

  group('computeAnalytics', () {
    final now = DateTime(2026, 11, 17);
    final a = computeAnalytics(
      now: now,
      properties: [
        _p('1', governorate: 'Tunis', price: 100000, createdAt: DateTime(2026, 11, 2), views: 10, favorites: 2),
        _p('2', governorate: 'Tunis', price: 300000, createdAt: DateTime(2026, 10, 5), views: 5),
        _p('3', governorate: 'Sousse', tx: TransactionType.rent, price: 1200, type: PropertyType.villa,
            createdAt: DateTime(2026, 11, 10)),
        _p('4', status: PropertyStatus.pendingReview, governorate: 'Sfax', createdAt: DateTime(2025, 1, 1)),
      ],
      users: [
        AdminUser(id: 'u1', email: 'a', createdAt: DateTime(2026, 11, 1)),
        AdminUser(id: 'u2', email: 'b', createdAt: DateTime(2026, 6, 30)),
        const AdminUser(id: 'u3', email: 'c'),
      ],
    );

    test('distributions count published listings only', () {
      expect(a.byGovernorate.map((e) => '${e.key}:${e.value}'), ['Tunis:2', 'Sousse:1']);
      expect(a.byType.first.key, 'apartment');
      expect({for (final e in a.byStatus) e.key: e.value}, {'published': 3, 'pending_review': 1});
    });

    test('average price per transaction', () {
      expect(a.averagePrice['buy'], 200000);
      expect(a.averagePrice['rent'], 1200);
    });

    test('6 month growth, oldest first, out-of-range dates ignored', () {
      expect(a.listingGrowth.map((e) => e.key), ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11']);
      expect(a.listingGrowth.last.value, 2);
      expect(a.listingGrowth[4].value, 1);
      expect(a.userGrowth.first.value, 1); // June
      expect(a.userGrowth.last.value, 1);
    });

    test('totals', () {
      expect(a.totalViews, 15);
      expect(a.totalFavorites, 2);
      expect(a.sampledProperties, 4);
    });

    test('month keys across the year boundary', () {
      expect(monthKey(DateTime(2026, 1 - 1)), '2025-12');
    });
  });

  // ---------------------------------------------------------------- Module 16
  group('Catalog', () {
    test('slugify', () {
      expect(slugify('Vue mer & piscine'), 'vue_mer_piscine');
      expect(slugify('  Prix trompeur !! '), 'prix_trompeur');
      expect(slugify('Ëlégance Œuvre'), 'elegance_oeuvre');
    });

    test('defaults: built-in lists mirror the code enums', () {
      expect(CatalogKey.amenities.defaults.map((i) => i.id), Amenity.values.map((a) => a.id));
      expect(CatalogKey.propertyTypes.defaults.first.label, 'Appartement');
      expect(CatalogKey.reportReasons.defaults, isNotEmpty);
      expect(CatalogKey.tags.defaults, isEmpty);
    });

    test('add / rename / toggle / move / remove on a free list', () {
      var l = CatalogEditor.add(CatalogKey.tags, const [], 'Vue mer');
      l = CatalogEditor.add(CatalogKey.tags, l, 'Neuf');
      expect(l.map((i) => i.id), ['vue_mer', 'neuf']);
      expect(() => CatalogEditor.add(CatalogKey.tags, l, 'vue MER'), throwsA(isA<CatalogEditException>()));
      expect(() => CatalogEditor.add(CatalogKey.tags, l, '   '), throwsA(isA<CatalogEditException>()));

      l = CatalogEditor.rename(l, 'neuf', 'Neuf / récent');
      expect(l.last.label, 'Neuf / récent');
      expect(l.last.id, 'neuf'); // ids never change

      l = CatalogEditor.toggle(l, 'vue_mer');
      expect(l.first.active, isFalse);

      l = CatalogEditor.move(l, 'neuf', -1);
      expect(l.map((i) => i.id), ['neuf', 'vue_mer']);
      expect(l.map((i) => i.order), [0, 1]);
      expect(CatalogEditor.move(l, 'neuf', -5).first.id, 'neuf'); // clamped

      l = CatalogEditor.remove(CatalogKey.tags, l, 'neuf');
      expect(l.single.id, 'vue_mer');
      expect(l.single.order, 0);
    });

    test('built-in lists: rename / hide only', () {
      final l = CatalogKey.amenities.defaults;
      expect(() => CatalogEditor.add(CatalogKey.amenities, l, 'Sauna'), throwsA(isA<CatalogEditException>()));
      expect(() => CatalogEditor.remove(CatalogKey.amenities, l, 'pool'), throwsA(isA<CatalogEditException>()));
      final renamed = CatalogEditor.rename(l, 'pool', 'Piscine');
      expect(renamed.firstWhere((i) => i.id == 'pool').label, 'Piscine');
    });

    test('reconcile keeps admin order and labels, restores missing ids, drops unknown ones', () {
      final stored = [
        const CatalogItem(id: 'seaView', label: 'Vue sur mer', order: 0),
        const CatalogItem(id: 'sauna', label: 'Sauna', order: 1), // not in the app
        const CatalogItem(id: 'pool', label: 'Piscine', active: false, order: 2),
      ];
      final r = CatalogEditor.reconcile(CatalogKey.amenities, stored);
      expect(r.take(2).map((i) => i.label), ['Vue sur mer', 'Piscine']);
      expect(r.any((i) => i.id == 'sauna'), isFalse);
      expect(r.length, Amenity.values.length);
      expect(r.map((i) => i.order), List.generate(r.length, (i) => i));
    });

    test('CatalogItem.tryFromMap', () {
      expect(CatalogItem.tryFromMap({'id': 'a', 'label': 'A', 'order': 3})!.active, isTrue);
      expect(CatalogItem.tryFromMap({'id': '', 'label': 'A'}), isNull);
      expect(CatalogItem.tryFromMap('nope'), isNull);
    });
  });

  // ---------------------------------------------------------------- Module 17
  group('PlatformSettings', () {
    test('defaults when missing or malformed', () {
      expect(PlatformSettings.fromMap(null).maxImages, 10);
      final s = PlatformSettings.fromMap({'maxImages': 'six', 'supportedCurrencies': [], 'termsText': 3});
      expect(s.maxImages, 10);
      expect(s.supportedCurrencies, ['TND']);
      expect(s.termsText, '');
      expect(s.serverNotifications, isFalse);
    });

    test('round trip', () {
      const s = PlatformSettings(maxImages: 6, listingExpirationDays: 30, contactEmail: 'contact@immofind.tn');
      final back = PlatformSettings.fromMap(s.toMap());
      expect(back.maxImages, 6);
      expect(back.listingExpirationDays, 30);
      expect(back.contactEmail, 'contact@immofind.tn');
    });

    test('validate mirrors the rules', () {
      expect(PlatformSettings.defaults.validate(), isEmpty);
      final bad = const PlatformSettings(
        maxImages: 11,
        maxImageSizeMb: 0,
        listingExpirationDays: 3,
        supportedCurrencies: [],
        contactEmail: 'nope',
      ).validate();
      expect(bad.keys,
          containsAll(['maxImages', 'maxImageSizeMb', 'listingExpirationDays', 'supportedCurrencies', 'contactEmail']));
    });

    test('effective limits never exceed the hard caps', () {
      expect(const PlatformSettings(maxImages: 50).effectiveMaxImages, 10);
      expect(const PlatformSettings(maxImages: 4).effectiveMaxImages, 4);
      expect(const PlatformSettings(maxImageSizeMb: 2).effectiveMaxImageBytes, 2 * 1024 * 1024);
    });
  });
}
