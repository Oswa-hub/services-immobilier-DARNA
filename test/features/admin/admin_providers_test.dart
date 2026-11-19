// Modules 15 / 16 / 17 — providers and widgets with in-memory fakes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_app/core/errors/admin_failure.dart';
import 'package:team_app/features/admin/data/admin_repository.dart';
import 'package:team_app/features/admin/domain/admin_models.dart';
import 'package:team_app/features/admin/domain/admin_policy.dart';
import 'package:team_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:team_app/features/auth/domain/entities/auth_user.dart';
import 'package:team_app/features/auth/providers/auth_provider.dart';
import 'package:team_app/features/content/data/catalog_repository.dart';
import 'package:team_app/features/content/domain/catalog.dart';
import 'package:team_app/features/content/presentation/pages/admin_content_page.dart';
import 'package:team_app/features/content/presentation/providers/catalog_providers.dart';
import 'package:team_app/features/properties/domain/entities/amenity.dart';
import 'package:team_app/features/properties/domain/entities/property.dart';
import 'package:team_app/features/settings/domain/platform_settings.dart';
import 'package:team_app/features/settings/presentation/pages/legal_pages.dart';
import 'package:team_app/features/settings/presentation/providers/platform_settings_providers.dart';

import '../../support_properties.dart';

const _admin = AuthUser(id: 'admin', email: 'admin@x.tn', role: UserRole.admin, emailVerified: true);
const _user = AuthUser(id: 'u1', email: 'u1@x.tn', emailVerified: true);

class FakeAdminRepository implements AdminRepository {
  final calls = <String>[];
  ({int expirationDays, bool notifyOwner, String? reason})? lastModeration;
  AdminFailure? failWith;

  void _check() {
    if (failWith != null) throw failWith!;
  }

  @override
  Future<AdminKpis> loadKpis() async => const AdminKpis(totalUsers: 3);

  @override
  Stream<List<AdminUser>> watchUsers({AccountStatus? status, int limit = 200}) => Stream.value(const []);

  @override
  Future<void> setUserStatus(AdminUser user, UserAction action, {required String adminId, String? reason}) async {
    calls.add('status:${user.id}:${action.name}:$adminId');
    _check();
  }

  @override
  Future<void> setUserRole(AdminUser user, UserRole role, {required String adminId}) async {
    calls.add('role:${user.id}:${role.name}');
    _check();
  }

  @override
  Stream<List<Property>> watchProperties({PropertyStatus? status, int limit = 200}) => Stream.value(const []);

  @override
  Future<void> moderate(Property property, ModerationAction action,
      {required String adminId, required int expirationDays, required bool notifyOwner, String? reason}) async {
    calls.add('moderate:${property.id}:${action.name}');
    lastModeration = (expirationDays: expirationDays, notifyOwner: notifyOwner, reason: reason);
    _check();
  }

  @override
  Future<int> sendNotification({
    required Audience audience,
    required AdminNotificationType type,
    required String title,
    required String body,
    required String adminId,
  }) async {
    calls.add('send:${type.wire}');
    _check();
    return 7;
  }

  Property? property;
  AdminUser? user;

  @override
  Future<Property?> loadProperty(String id) async => property;

  @override
  Future<AdminUser?> loadUser(String id) async => user;

  @override
  Stream<List<AuditEntry>> watchAuditLogs({int limit = 100}) => Stream.value(const []);

  @override
  Future<AdminAnalytics> loadAnalytics({int sample = 1000}) => throw UnimplementedError();
}

class FakeCatalogRepository implements CatalogRepository {
  final saved = <CatalogKey, List<CatalogItem>>{};
  final _controllers = <CatalogKey, StreamController<List<CatalogItem>>>{};

  @override
  Stream<List<CatalogItem>> watch(CatalogKey key) async* {
    yield saved[key] ?? CatalogEditor.reconcile(key, key.defaults);
    yield* (_controllers[key] ??= StreamController.broadcast()).stream;
  }

  @override
  Future<void> save(CatalogKey key, List<CatalogItem> items, {required String adminId}) async {
    saved[key] = items;
    _controllers[key]?.add(items);
  }
}

ProviderContainer _container({
  AuthUser? user = _admin,
  PlatformSettings settings = PlatformSettings.defaults,
  required FakeAdminRepository repo,
}) {
  final c = ProviderContainer(overrides: [
    currentUserProvider.overrideWithValue(user),
    adminRepositoryProvider.overrideWithValue(repo),
    platformSettingsProvider.overrideWithValue(settings),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('AdminActions (Module 15)', () {
    test('moderation uses the platform settings', () async {
      final repo = FakeAdminRepository();
      final c = _container(repo: repo, settings: const PlatformSettings(listingExpirationDays: 30));
      final failure = await c.read(adminActionsProvider).moderate(
            makeProperty(id: 'p1', status: PropertyStatus.pendingReview),
            ModerationAction.approve,
          );
      expect(failure, isNull);
      expect(repo.calls, ['moderate:p1:approve']);
      expect(repo.lastModeration!.expirationDays, 30);
      expect(repo.lastModeration!.notifyOwner, isTrue); // Spark plan: the app notifies
    });

    test('no duplicate notice once Cloud Functions send them', () async {
      final repo = FakeAdminRepository();
      final c = _container(repo: repo, settings: const PlatformSettings(serverNotifications: true));
      await c.read(adminActionsProvider).moderate(makeProperty(), ModerationAction.suspend, reason: 'Fausse annonce');
      expect(repo.lastModeration!.notifyOwner, isFalse);
      expect(repo.lastModeration!.reason, 'Fausse annonce');
    });

    test('non-admins cannot act', () async {
      final repo = FakeAdminRepository();
      final c = _container(repo: repo, user: _user);
      final failure = await c.read(adminActionsProvider).setUserStatus(
            const AdminUser(id: 'u2', email: 'x'),
            UserAction.ban,
            reason: 'Spam répété',
          );
      expect(failure?.type, AdminFailureType.permissionDenied);
      expect(repo.calls, isEmpty);
    });

    test('a repository failure is returned, not thrown', () async {
      final repo = FakeAdminRepository()..failWith = const AdminFailure(AdminFailureType.conflict);
      final c = _container(repo: repo);
      final failure = await c.read(adminActionsProvider).setUserRole(const AdminUser(id: 'u2', email: 'x'), UserRole.agent);
      expect(failure?.type, AdminFailureType.conflict);
    });

    test('announcements respect the setting; single-user warnings still go out', () async {
      final repo = FakeAdminRepository();
      final c = _container(repo: repo, settings: const PlatformSettings(announcementsEnabled: false));
      final actions = c.read(adminActionsProvider);

      final (n1, f1) = await actions.sendNotification(
          audience: const AllUsers(), type: AdminNotificationType.announcement, title: 'Info', body: 'Bonjour à tous');
      expect(n1, 0);
      expect(f1?.type, AdminFailureType.invalid);

      final (n2, f2) = await actions.sendNotification(
          audience: const SingleUser('u2'), type: AdminNotificationType.warning, title: 'Attention', body: 'Dernier avertissement');
      expect(f2, isNull);
      expect(n2, 7);
      expect(repo.calls, ['send:accountWarning']);
    });

    test('dashboard reads nothing for a non-admin', () async {
      final c = _container(repo: FakeAdminRepository(), user: _user);
      c.listen(adminKpisProvider, (_, _) {}); // keep the autoDispose provider alive
      expect((await c.read(adminKpisProvider.future)).totalUsers, isNull);
    });
  });

  group('Catalog providers (Module 16)', () {
    test('amenity options follow admin order, labels and visibility', () async {
      final repo = FakeCatalogRepository();
      final items = CatalogEditor.toggle(
        CatalogEditor.move(CatalogEditor.rename(CatalogKey.amenities.defaults, 'pool', 'Piscine'), 'pool', -10),
        'parking',
      );
      repo.saved[CatalogKey.amenities] = items;
      final c = ProviderContainer(overrides: [catalogRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      c.listen(catalogStreamProvider(CatalogKey.amenities), (_, _) {});
      await pumpEventQueue();

      final options = c.read(amenityOptionsProvider);
      expect(options.first.amenity, Amenity.pool);
      expect(options.first.label, 'Piscine');
      expect(options.any((o) => o.amenity == Amenity.parking), isFalse); // hidden
    });

    test('defaults while nothing is stored', () {
      final c = ProviderContainer(overrides: [catalogRepositoryProvider.overrideWithValue(FakeCatalogRepository())]);
      addTearDown(c.dispose);
      expect(c.read(catalogProvider(CatalogKey.reportReasons)), isNotEmpty);
    });

    testWidgets('editor: add an item, then save', (tester) async {
      final repo = FakeCatalogRepository();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(_admin),
          catalogRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: Scaffold(body: CatalogEditorView(catalogKey: CatalogKey.tags))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Aucun élément.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Vue mer');
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      expect(find.text('Vue mer'), findsOneWidget);
      expect(repo.saved[CatalogKey.tags], isNull); // not saved yet

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(repo.saved[CatalogKey.tags]!.single.id, 'vue_mer');
    });
  });

  group('Legal pages (Module 17)', () {
    testWidgets('show the admin text, or an empty state', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [platformSettingsProvider.overrideWithValue(const PlatformSettings(termsText: 'Article 1 — Objet'))],
        child: const MaterialApp(home: LegalPage(document: LegalDocument.terms)),
      ));
      expect(find.text('Article 1 — Objet'), findsOneWidget);

      await tester.pumpWidget(ProviderScope(
        overrides: [platformSettingsProvider.overrideWithValue(PlatformSettings.defaults)],
        child: const MaterialApp(home: LegalPage(document: LegalDocument.privacy)),
      ));
      expect(find.text('Ce document n’est pas encore disponible.'), findsOneWidget);
    });

    testWidgets('contact page lists what is filled in', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          platformSettingsProvider.overrideWithValue(const PlatformSettings(contactEmail: 'contact@immofind.tn')),
        ],
        child: const MaterialApp(home: ContactPage()),
      ));
      expect(find.text('contact@immofind.tn'), findsOneWidget);
      expect(find.text('Téléphone'), findsNothing);
    });
  });
}
