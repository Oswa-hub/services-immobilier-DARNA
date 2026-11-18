import '../../../../app/routes.dart';
import '../entities/app_notification.dart';

/// Where tapping a notification (in the center or a push) leads, or null when
/// the notification is self-contained (announcement, warning): the UI then
/// shows its full text instead. Pure; unit-tested.
String? routeForNotification({
  required NotificationType type,
  String? propertyId,
  String? conversationId,
}) {
  final hasProperty = propertyId != null && propertyId.isNotEmpty;
  if (conversationId != null && conversationId.isNotEmpty) return Routes.chat(conversationId);

  return switch (type) {
    // The listing is visible: open it.
    NotificationType.listingApproved ||
    NotificationType.listingRestored ||
    NotificationType.priceChanged ||
    NotificationType.newMatchingProperty =>
      hasProperty ? Routes.propertyDetails(propertyId) : Routes.myListings,
    // A saved listing that left the market: details page shows "no longer available".
    NotificationType.favoriteUpdated => hasProperty ? Routes.propertyDetails(propertyId) : Routes.favorites,
    // Not public (pending / rejected / suspended): the owner manages it from My Listings.
    NotificationType.listingSubmitted ||
    NotificationType.listingRejected ||
    NotificationType.listingSuspended =>
      Routes.myListings,
    NotificationType.verificationSubmitted ||
    NotificationType.verificationApproved ||
    NotificationType.verificationRejected =>
      hasProperty ? Routes.myListings : Routes.agentVerification,
    NotificationType.newMessage || NotificationType.newInquiry => Routes.messages,
    NotificationType.reportUpdated => Routes.myReports,
    NotificationType.accountWarning || NotificationType.platformAnnouncement || NotificationType.other => null,
  };
}

String? routeFor(AppNotification n) =>
    routeForNotification(type: n.type, propertyId: n.propertyId, conversationId: n.conversationId);
