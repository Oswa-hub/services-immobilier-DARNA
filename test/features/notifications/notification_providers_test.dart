// Module 12 state: center list / filter / actions / preferences / push
// registration, with in-memory fakes (no Firebase).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:team_app/core/errors/notification_failure.dart';
import 'package:team_app/features/auth/domain/entities/auth_user.dart';
import 'package:team_app/features/auth/providers/auth_provider.dart';
import 'package:team_app/features/notifications/domain/entities/notification_preferences.dart';
import 'package:team_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:team_app/features/notifications/presentation/providers/push_registration.dart';

import 'fakes.dart';

const _user = AuthUser(id: 'u1', email: 'u1@example.com', emailVerified: true);

ProviderContainer _container(FakeNotificationRepository repo, {AuthUser? user = _user}) {
  final c = ProviderContainer(overrides: [
    currentUserProvider.overrideWithValue(user),
    notificationRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  c.listen(notificationsProvider, (_, _) {});
  c.listen(unreadNotificationsCountProvider, (_, _) {});
  return c;
}

void main() {
  group('center', () {
    test('lists only my notifications, live, and counts unread', () async {
      final repo = FakeNotificationRepository([
        makeNotification(id: 'a'),
        makeNotification(id: 'b', read: true),
        makeNotification(id: 'other', userId: 'u2'),
      ]);
      final c = _container(repo);
      await pumpEventQueue();

      expect(c.read(notificationsProvider).value!.map((n) => n.id), ['a', 'b']);
      expect(c.read(unreadBadgeCountProvider), 1);

      repo.push(makeNotification(id: 'new'));
      await pumpEventQueue();
      expect(c.read(notificationsProvider).value!.first.id, 'new');
      expect(c.read(unreadBadgeCountProvider), 2);
    });

    test('unread filter', () async {
      final c = _container(FakeNotificationRepository([
        makeNotification(id: 'a'),
        makeNotification(id: 'b', read: true),
      ]));
      c.listen(visibleNotificationsProvider, (_, _) {});
      await pumpEventQueue();

      c.read(notificationFilterProvider.notifier).select(NotificationFilter.unread);
      expect(c.read(visibleNotificationsProvider).value!.map((n) => n.id), ['a']);

      c.read(notificationFilterProvider.notifier).select(NotificationFilter.all);
      expect(c.read(visibleNotificationsProvider).value!.length, 2);
    });

    test('signed out: empty list, zero badge, nothing read from the repository', () async {
      final repo = FakeNotificationRepository([makeNotification()]);
      final c = _container(repo, user: null);
      await pumpEventQueue();
      expect(c.read(notificationsProvider).value, isEmpty);
      expect(c.read(unreadBadgeCountProvider), 0);
      expect(await c.read(notificationActionsProvider).markAllRead(), isA<NotificationFailure>());
      expect(repo.calls, isEmpty);
    });

    test('markRead / markAllRead / delete', () async {
      final repo = FakeNotificationRepository([
        makeNotification(id: 'a'),
        makeNotification(id: 'b'),
        makeNotification(id: 'c'),
      ]);
      final c = _container(repo);
      await pumpEventQueue();
      final actions = c.read(notificationActionsProvider);

      expect(await actions.markRead('a'), isNull);
      await pumpEventQueue();
      expect(c.read(unreadBadgeCountProvider), 2);

      expect(await actions.markAllRead(), isNull);
      await pumpEventQueue();
      expect(c.read(unreadBadgeCountProvider), 0);

      expect(await actions.delete('b'), isNull);
      await pumpEventQueue();
      expect(c.read(notificationsProvider).value!.map((n) => n.id), ['a', 'c']);
    });

    test('a failing action returns the failure instead of throwing', () async {
      final repo = FakeNotificationRepository([makeNotification(id: 'a')])..failWrites = true;
      final c = _container(repo);
      await pumpEventQueue();
      final failure = await c.read(notificationActionsProvider).delete('a');
      expect(failure?.type, NotificationFailureType.network);
      expect(c.read(notificationsProvider).value!.length, 1);
    });
  });

  group('preferences', () {
    test('loads, saves optimistically', () async {
      final repo = FakeNotificationRepository()..prefs = const NotificationPreferences(newMessages: false);
      final c = _container(repo);
      final loaded = await c.read(notificationPreferencesProvider.future);
      expect(loaded.newMessages, isFalse);

      final next = loaded.copyWith(newMessages: true, emailNotifications: true);
      expect(await c.read(notificationPreferencesProvider.notifier).save(next), isNull);
      expect(c.read(notificationPreferencesProvider).value, next);
      expect(repo.prefs, next);
    });

    test('a failed save restores the previous value', () async {
      final repo = FakeNotificationRepository();
      final c = _container(repo);
      final before = await c.read(notificationPreferencesProvider.future);
      repo.failWrites = true;

      final failure =
          await c.read(notificationPreferencesProvider.notifier).save(before.copyWith(pushNotifications: false));

      expect(failure?.type, NotificationFailureType.network);
      expect(c.read(notificationPreferencesProvider).value, before);
    });
  });

  group('PushRegistrar', () {
    test('registers once, follows token refresh, unregisters', () async {
      final repo = FakeNotificationRepository();
      final push = FakePushMessaging();
      final r = PushRegistrar(messaging: push, repository: repo);
      addTearDown(r.dispose);

      await r.sync(userId: 'u1', enabled: true);
      await r.sync(userId: 'u1', enabled: true); // idempotent
      expect(repo.devices, {'tok-1': 'u1'});
      expect(push.permissionRequests, 1);

      push.refresh.add('tok-2');
      await pumpEventQueue();
      expect(repo.devices, {'tok-2': 'u1'});

      await r.unregister();
      expect(repo.devices, isEmpty);
      expect(r.registeredUserId, isNull);
    });

    test('switching account moves the token; disabling push drops it', () async {
      final repo = FakeNotificationRepository();
      final r = PushRegistrar(messaging: FakePushMessaging(), repository: repo);
      addTearDown(r.dispose);

      await r.sync(userId: 'u1', enabled: true);
      await r.sync(userId: 'u2', enabled: true);
      expect(repo.devices, {'tok-1': 'u2'});
      expect(repo.calls, contains('unregister:u1:tok-1'));

      await r.sync(userId: 'u2', enabled: false);
      expect(repo.devices, isEmpty);
    });

    test('nothing happens when unsupported, denied, or failing', () async {
      final repo = FakeNotificationRepository();

      await PushRegistrar(messaging: FakePushMessaging(isSupported: false), repository: repo)
          .sync(userId: 'u1', enabled: true);
      await PushRegistrar(messaging: FakePushMessaging(granted: false), repository: repo)
          .sync(userId: 'u1', enabled: true);
      await PushRegistrar(messaging: FakePushMessaging(token: null), repository: repo)
          .sync(userId: 'u1', enabled: true);
      expect(repo.devices, isEmpty);

      repo.failWrites = true;
      final r = PushRegistrar(messaging: FakePushMessaging(), repository: repo);
      await r.sync(userId: 'u1', enabled: true); // must not throw
      expect(r.registeredUserId, isNull);
    });

    test('pushRegistrarProvider is overridable through pushMessagingProvider', () async {
      final repo = FakeNotificationRepository();
      final c = ProviderContainer(overrides: [
        notificationRepositoryProvider.overrideWithValue(repo),
        pushMessagingProvider.overrideWithValue(FakePushMessaging()),
      ]);
      addTearDown(c.dispose);
      await c.read(pushRegistrarProvider).sync(userId: 'u1', enabled: true);
      expect(repo.devices, {'tok-1': 'u1'});
    });
  });
}
