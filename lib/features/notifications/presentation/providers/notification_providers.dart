import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/notification_failure.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/notification_remote_data_source.dart';
import '../../data/notification_repository_impl.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';

/// Override in tests with a fake.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(NotificationRemoteDataSource(ref.watch(firestoreProvider))),
);

/// The signed-in user's notifications, live, newest first. Follows the user
/// (logout / other account) by itself.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return Stream.value(const <AppNotification>[]);
  return ref.watch(notificationRepositoryProvider).watchNotifications(userId);
});

/// Live unread count for the bell badge (capped at 100 -> "99+").
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return Stream.value(0);
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(userId);
});

/// Plain int for widgets: 0 while loading, on error or signed out.
final unreadBadgeCountProvider = Provider<int>(
  (ref) => ref.watch(unreadNotificationsCountProvider).maybeWhen(data: (n) => n, orElse: () => 0),
);

// ---- Center filter ----------------------------------------------------------

enum NotificationFilter { all, unread }

final notificationFilterProvider =
    NotifierProvider<NotificationFilterController, NotificationFilter>(NotificationFilterController.new);

class NotificationFilterController extends Notifier<NotificationFilter> {
  @override
  NotificationFilter build() => NotificationFilter.all;

  void select(NotificationFilter filter) => state = filter;
}

/// What the center shows, after the filter.
final visibleNotificationsProvider = Provider<AsyncValue<List<AppNotification>>>((ref) {
  final filter = ref.watch(notificationFilterProvider);
  return ref.watch(notificationsProvider).whenData(
        (items) => filter == NotificationFilter.unread ? [for (final n in items) if (!n.read) n] : items,
      );
});

// ---- Actions ----------------------------------------------------------------

final notificationActionsProvider = Provider<NotificationActions>(NotificationActions.new);

/// User actions of the center. They never throw: a failure is returned so the
/// UI can show its (French) message.
class NotificationActions {
  NotificationActions(this._ref);

  final Ref _ref;
  final Set<String> _inFlight = {};

  NotificationRepository get _repo => _ref.read(notificationRepositoryProvider);

  Future<NotificationFailure?> markRead(String notificationId) async {
    if (!_inFlight.add(notificationId)) return null; // double tap
    try {
      await _repo.markRead(notificationId);
      return null;
    } on NotificationFailure catch (f) {
      return f;
    } finally {
      _inFlight.remove(notificationId);
    }
  }

  /// Returns the failure, or null on success.
  Future<NotificationFailure?> markAllRead() async {
    final userId = _ref.read(currentUserProvider)?.id;
    if (userId == null) return const NotificationFailure(NotificationFailureType.permissionDenied);
    try {
      await _repo.markAllRead(userId);
      return null;
    } on NotificationFailure catch (f) {
      return f;
    }
  }

  Future<NotificationFailure?> delete(String notificationId) async {
    try {
      await _repo.delete(notificationId);
      return null;
    } on NotificationFailure catch (f) {
      return f;
    }
  }
}

// ---- Preferences ------------------------------------------------------------

final notificationPreferencesProvider =
    AsyncNotifierProvider<NotificationPreferencesController, NotificationPreferences>(
  NotificationPreferencesController.new,
);

class NotificationPreferencesController extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    if (userId == null) return NotificationPreferences.defaults;
    return ref.watch(notificationRepositoryProvider).loadPreferences(userId);
  }

  /// Applies [next] at once (optimistic) and saves it. On failure the previous
  /// value comes back and the failure is returned.
  Future<NotificationFailure?> save(NotificationPreferences next) async {
    final userId = ref.read(currentUserProvider)?.id;
    final previous = state.value;
    if (userId == null || previous == null) {
      return const NotificationFailure(NotificationFailureType.permissionDenied);
    }
    if (next == previous) return null;
    state = AsyncData(next);
    try {
      await ref.read(notificationRepositoryProvider).savePreferences(userId, next);
      return null;
    } on NotificationFailure catch (f) {
      state = AsyncData(previous);
      return f;
    }
  }
}
