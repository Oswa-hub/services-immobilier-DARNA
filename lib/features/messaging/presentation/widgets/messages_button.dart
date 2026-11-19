import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/messaging_providers.dart';

/// Entry point to `/messages` with an unread badge (Home header).
class MessagesButton extends ConsumerWidget {
  const MessagesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadConversationsCountProvider);
    return IconButton(
      tooltip: unread > 0 ? 'Messages, $unread unread' : 'Messages',
      onPressed: () => context.push(Routes.messages),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.text),
      ),
    );
  }
}
