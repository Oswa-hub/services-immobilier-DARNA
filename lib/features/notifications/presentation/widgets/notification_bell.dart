import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/services/notification_grouping.dart';
import '../providers/notification_providers.dart';

/// Bell with the live unread badge; opens the notification center.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, this.color = AppColors.navy});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadBadgeCountProvider);
    final label = unreadBadgeLabel(count);
    return IconButton(
      tooltip: label == null ? 'Notifications' : 'Notifications, $label non lue${count > 1 ? 's' : ''}',
      onPressed: () => context.push(Routes.notifications),
      icon: Badge(
        isLabelVisible: label != null,
        label: Text(label ?? ''),
        backgroundColor: AppColors.accent,
        child: Icon(
          label == null ? Icons.notifications_none_rounded : Icons.notifications_rounded,
          color: color,
        ),
      ),
    );
  }
}
