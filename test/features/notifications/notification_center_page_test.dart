// Module 12 widget tests: notification center + bell badge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:team_app/app/routes.dart';
import 'package:team_app/core/theme/app_theme.dart';
import 'package:team_app/features/auth/domain/entities/auth_user.dart';
import 'package:team_app/features/auth/providers/auth_provider.dart';
import 'package:team_app/features/notifications/domain/entities/app_notification.dart';
import 'package:team_app/features/notifications/presentation/pages/notification_center_page.dart';
import 'package:team_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:team_app/features/notifications/presentation/widgets/notification_bell.dart';

import 'fakes.dart';

const _user = AuthUser(id: 'u1', email: 'u1@example.com', emailVerified: true);
final _now = DateTime(2026, 11, 17, 20, 0);

/// Pumps the center inside a tiny router so taps can navigate.
Future<List<String>> _pumpCenter(WidgetTester tester, FakeNotificationRepository repo) async {
  final visited = <String>[];
  final router = GoRouter(
    initialLocation: Routes.notifications,
    routes: [
      GoRoute(path: Routes.notifications, builder: (_, _) => NotificationCenterPage(now: _now)),
      GoRoute(path: '/property/:id', builder: (_, s) {
        visited.add(s.uri.path);
        return const Scaffold(body: Text('details'));
      }),
      GoRoute(path: Routes.myListings, builder: (_, s) {
        visited.add(s.uri.path);
        return const Scaffold(body: Text('my listings'));
      }),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(_user),
      notificationRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return visited;
}

void main() {
  testWidgets('empty state', (tester) async {
    await _pumpCenter(tester, FakeNotificationRepository());
    expect(find.text('Aucune notification'), findsOneWidget);
  });

  testWidgets('groups by day and shows unread first-class', (tester) async {
    await _pumpCenter(
      tester,
      FakeNotificationRepository([
        makeNotification(id: 'a', title: 'Annonce approuvée', createdAt: DateTime(2026, 11, 17, 18)),
        makeNotification(
          id: 'b',
          type: NotificationType.priceChanged,
          title: 'Baisse de prix',
          read: true,
          createdAt: DateTime(2026, 11, 16, 9),
        ),
      ]),
    );
    expect(find.text('AUJOURD’HUI'), findsOneWidget);
    expect(find.text('HIER'), findsOneWidget);
    expect(find.text('Annonce approuvée'), findsOneWidget);
    expect(find.text('Baisse de prix'), findsOneWidget);
    expect(find.text('Non lues (1)'), findsOneWidget);
  });

  testWidgets('tap marks read and opens the listing', (tester) async {
    final repo = FakeNotificationRepository([
      makeNotification(id: 'a', title: 'Annonce approuvée', propertyId: 'p1', createdAt: DateTime(2026, 11, 17, 18)),
    ]);
    final visited = await _pumpCenter(tester, repo);

    await tester.tap(find.text('Annonce approuvée'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('markRead:a'));
    expect(visited, contains('/property/p1'));
  });

  testWidgets('an announcement opens its full text', (tester) async {
    await _pumpCenter(
      tester,
      FakeNotificationRepository([
        makeNotification(
          id: 'x',
          type: NotificationType.platformAnnouncement,
          title: 'Maintenance',
          body: 'Service indisponible ce soir de 22h à 23h.',
          propertyId: null,
          createdAt: DateTime(2026, 11, 17, 12),
        ),
      ]),
    );
    await tester.tap(find.text('Maintenance'));
    await tester.pumpAndSettle();
    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets('mark all read + unread filter empty state', (tester) async {
    final repo = FakeNotificationRepository([
      makeNotification(id: 'a', createdAt: DateTime(2026, 11, 17, 18)),
      makeNotification(id: 'b', createdAt: DateTime(2026, 11, 17, 17)),
    ]);
    await _pumpCenter(tester, repo);

    await tester.tap(find.byTooltip('Tout marquer comme lu'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('markAllRead:u1'));

    await tester.tap(find.text('Non lues'));
    await tester.pumpAndSettle();
    expect(find.text('Tout est lu'), findsOneWidget);
  });

  testWidgets('swipe deletes', (tester) async {
    final repo = FakeNotificationRepository([
      makeNotification(id: 'a', title: 'À supprimer', createdAt: DateTime(2026, 11, 17, 18)),
    ]);
    await _pumpCenter(tester, repo);

    await tester.drag(find.text('À supprimer'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('delete:a'));
    expect(find.text('À supprimer'), findsNothing);
  });

  testWidgets('bell shows the live unread badge', (tester) async {
    final repo = FakeNotificationRepository([makeNotification(id: 'a'), makeNotification(id: 'b')]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        notificationRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: Scaffold(body: NotificationBell())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await repo.markAllRead('u1');
    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing);
  });
}
