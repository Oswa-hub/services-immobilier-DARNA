import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/services/notification_grouping.dart';

({IconData icon, Color color}) notificationVisual(NotificationType type) => switch (type) {
      NotificationType.listingApproved ||
      NotificationType.listingRestored ||
      NotificationType.verificationApproved =>
        (icon: Icons.check_circle_outline_rounded, color: AppColors.success),
      NotificationType.listingRejected ||
      NotificationType.verificationRejected =>
        (icon: Icons.highlight_off_rounded, color: AppColors.error),
      NotificationType.listingSuspended ||
      NotificationType.accountWarning =>
        (icon: Icons.warning_amber_rounded, color: AppColors.error),
      NotificationType.listingSubmitted ||
      NotificationType.verificationSubmitted =>
        (icon: Icons.hourglass_top_rounded, color: AppColors.muted),
      NotificationType.newMessage ||
      NotificationType.newInquiry =>
        (icon: Icons.chat_bubble_outline_rounded, color: AppColors.primary),
      NotificationType.priceChanged => (icon: Icons.sell_outlined, color: AppColors.accent),
      NotificationType.favoriteUpdated => (icon: Icons.favorite_border_rounded, color: AppColors.accent),
      NotificationType.newMatchingProperty => (icon: Icons.home_work_outlined, color: AppColors.primary),
      NotificationType.platformAnnouncement => (icon: Icons.campaign_outlined, color: AppColors.primary),
      NotificationType.reportUpdated => (icon: Icons.flag_outlined, color: AppColors.primary),
      NotificationType.other => (icon: Icons.notifications_none_rounded, color: AppColors.muted),
    };

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.notification, required this.onTap, this.now});

  final AppNotification notification;
  final VoidCallback onTap;

  /// Injected in tests for stable relative times.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final visual = notificationVisual(n.type);
    return Semantics(
      button: true,
      label: '${n.read ? '' : 'Non lue. '}${n.title}. ${n.body}',
      excludeSemantics: true,
      child: Material(
        color: n.read ? Colors.white : AppColors.chip,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: visual.color.withValues(alpha: 0.12),
                child: Icon(visual.icon, color: visual.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatNotificationTime(n.createdAt, now: now),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ]),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.3, color: AppColors.muted),
                    ),
                  ],
                ]),
              ),
              if (!n.read) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 9, color: AppColors.accent),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
