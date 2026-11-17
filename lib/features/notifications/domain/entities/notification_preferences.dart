import 'app_notification.dart';

/// `users/{uid}.notificationPreferences` (rules already let the user edit it).
///
/// Keys and defaults mirror `DEFAULT_PREFERENCES` in
/// functions/src/notification_rules.js — the server decides delivery from them.
class NotificationPreferences {
  const NotificationPreferences({
    this.newMessages = true,
    this.favoriteUpdates = true,
    this.propertyAlerts = true,
    this.announcements = true,
    this.pushNotifications = true,
    this.emailNotifications = false,
  });

  /// Messages and inquiries.
  final bool newMessages;

  /// Price changes / saved listing no longer available.
  final bool favoriteUpdates;

  /// New listings in the preferred governorate.
  final bool propertyAlerts;

  /// Platform announcements.
  final bool announcements;

  /// Master switch for push (FCM) on this account's devices.
  final bool pushNotifications;

  /// Master switch for transactional emails.
  final bool emailNotifications;

  static const defaults = NotificationPreferences();

  /// Missing or non-boolean values take the default (same as the server).
  factory NotificationPreferences.fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    bool read(String key, bool fallback) => m[key] is bool ? m[key] as bool : fallback;
    return NotificationPreferences(
      newMessages: read('newMessages', defaults.newMessages),
      favoriteUpdates: read('favoriteUpdates', defaults.favoriteUpdates),
      propertyAlerts: read('propertyAlerts', defaults.propertyAlerts),
      announcements: read('announcements', defaults.announcements),
      pushNotifications: read('pushNotifications', defaults.pushNotifications),
      emailNotifications: read('emailNotifications', defaults.emailNotifications),
    );
  }

  Map<String, bool> toMap() => {
        'newMessages': newMessages,
        'favoriteUpdates': favoriteUpdates,
        'propertyAlerts': propertyAlerts,
        'announcements': announcements,
        'pushNotifications': pushNotifications,
        'emailNotifications': emailNotifications,
      };

  /// Is this category received at all? Account notifications always are.
  bool allows(NotificationCategory category) => switch (category) {
        NotificationCategory.account => true,
        NotificationCategory.messages => newMessages,
        NotificationCategory.favorites => favoriteUpdates,
        NotificationCategory.alerts => propertyAlerts,
        NotificationCategory.announcements => announcements,
      };

  NotificationPreferences copyWith({
    bool? newMessages,
    bool? favoriteUpdates,
    bool? propertyAlerts,
    bool? announcements,
    bool? pushNotifications,
    bool? emailNotifications,
  }) =>
      NotificationPreferences(
        newMessages: newMessages ?? this.newMessages,
        favoriteUpdates: favoriteUpdates ?? this.favoriteUpdates,
        propertyAlerts: propertyAlerts ?? this.propertyAlerts,
        announcements: announcements ?? this.announcements,
        pushNotifications: pushNotifications ?? this.pushNotifications,
        emailNotifications: emailNotifications ?? this.emailNotifications,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.newMessages == newMessages &&
      other.favoriteUpdates == favoriteUpdates &&
      other.propertyAlerts == propertyAlerts &&
      other.announcements == announcements &&
      other.pushNotifications == pushNotifications &&
      other.emailNotifications == emailNotifications;

  @override
  int get hashCode => Object.hash(
      newMessages, favoriteUpdates, propertyAlerts, announcements, pushNotifications, emailNotifications);
}
