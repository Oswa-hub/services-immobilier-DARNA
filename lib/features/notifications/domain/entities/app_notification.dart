/// Module 12 — one entry of the notification center (`notifications/{id}`).
///
/// Documents are written ONLY by Cloud Functions (functions/src/notifier.js);
/// the type names below mirror `TYPES` in functions/src/notification_rules.js.
/// Change them together.
enum NotificationType {
  listingSubmitted,
  listingApproved,
  listingRejected,
  listingSuspended,
  listingRestored,
  newMessage,
  newInquiry,
  favoriteUpdated,
  priceChanged,
  newMatchingProperty,
  verificationSubmitted,
  verificationApproved,
  verificationRejected,
  accountWarning,
  platformAnnouncement,

  /// Anything this app version does not know yet (shown, never crashes).
  other;

  static NotificationType parse(String? value) =>
      NotificationType.values.firstWhere((t) => t.name == value, orElse: () => NotificationType.other);

  NotificationCategory get category => switch (this) {
        newMessage || newInquiry => NotificationCategory.messages,
        favoriteUpdated || priceChanged => NotificationCategory.favorites,
        newMatchingProperty => NotificationCategory.alerts,
        platformAnnouncement => NotificationCategory.announcements,
        _ => NotificationCategory.account,
      };
}

/// One preference switch per category; [account] is mandatory.
enum NotificationCategory { account, messages, favorites, alerts, announcements }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.propertyId,
    this.conversationId,
    this.createdAt,
    this.data = const {},
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final bool read;
  final String? propertyId;
  final String? conversationId;

  /// Null while the server timestamp is pending (just-created document).
  final DateTime? createdAt;

  /// Extra values sent by the server (e.g. oldPrice / newPrice).
  final Map<String, dynamic> data;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        userId: userId,
        type: type,
        title: title,
        body: body,
        read: read ?? this.read,
        propertyId: propertyId,
        conversationId: conversationId,
        createdAt: createdAt,
        data: data,
      );
}
