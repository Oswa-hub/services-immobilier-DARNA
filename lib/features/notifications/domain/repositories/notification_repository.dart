import '../entities/app_notification.dart';
import '../entities/notification_preferences.dart';

/// Module 12 data contract. Implementations throw only `NotificationFailure`.
/// Override `notificationRepositoryProvider` with a fake in tests.
abstract class NotificationRepository {
  /// The user's notifications, live, newest first.
  Stream<List<AppNotification>> watchNotifications(String userId, {int limit = 50});

  /// Live number of unread notifications, capped at [cap] (badge shows "99+").
  Stream<int> watchUnreadCount(String userId, {int cap = 100});

  Future<void> markRead(String notificationId);

  /// Marks every unread notification of [userId] read. Returns how many changed.
  Future<int> markAllRead(String userId);

  Future<void> delete(String notificationId);

  Future<NotificationPreferences> loadPreferences(String userId);
  Future<void> savePreferences(String userId, NotificationPreferences preferences);

  /// Push token of this device (`users/{uid}/devices/{token}`).
  Future<void> registerDevice({required String userId, required String token, required String platform});
  Future<void> unregisterDevice({required String userId, required String token});
}
