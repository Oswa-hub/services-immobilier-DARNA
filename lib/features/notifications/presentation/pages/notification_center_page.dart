import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/notification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/services/notification_grouping.dart';
import '../../domain/services/notification_navigation.dart';
import '../providers/notification_providers.dart';
import '../widgets/notification_tile.dart';

/// Module 12 — Notification Center (`/notifications`).
///
/// Live list (Firestore snapshots) grouped by day, "Toutes / Non lues" filter,
/// tap = mark read + open the related page, swipe = delete, "Tout marquer
/// comme lu". Every list has its empty, loading and error state (spec §63-64).
class NotificationCenterPage extends ConsumerWidget {
  const NotificationCenterPage({super.key, this.now});

  /// Injected in tests for stable grouping.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(notificationFilterProvider);
    final visible = ref.watch(visibleNotificationsProvider);
    final unread = ref.watch(unreadBadgeCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Tout marquer comme lu',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: unread == 0 ? null : () => _markAllRead(context, ref),
          ),
          IconButton(
            tooltip: 'Préférences de notification',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(Routes.notificationSettings),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<NotificationFilter>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: NotificationFilter.all, label: Text('Toutes')),
              ButtonSegment(
                value: NotificationFilter.unread,
                label: Text(unread == 0 ? 'Non lues' : 'Non lues (${unreadBadgeLabel(unread)})'),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (s) => ref.read(notificationFilterProvider.notifier).select(s.first),
          ),
        ),
        Expanded(
          child: visible.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _Message(
              icon: Icons.cloud_off_rounded,
              title: 'Impossible de charger les notifications',
              message: e is NotificationFailure ? e.message : 'Une erreur est survenue. Veuillez réessayer.',
              actionLabel: 'Réessayer',
              onAction: () => ref.invalidate(notificationsProvider),
            ),
            data: (items) => items.isEmpty
                ? (filter == NotificationFilter.unread
                    ? _Message(
                        icon: Icons.mark_email_read_outlined,
                        title: 'Tout est lu',
                        message: 'Vous n’avez aucune notification non lue.',
                        actionLabel: 'Voir toutes les notifications',
                        onAction: () => ref.read(notificationFilterProvider.notifier).select(NotificationFilter.all),
                      )
                    : const _Message(
                        icon: Icons.notifications_none_rounded,
                        title: 'Aucune notification',
                        message: 'Vous serez averti ici de vos annonces, messages, favoris et alertes.',
                      ))
                : _GroupedList(items: items, now: now),
          ),
        ),
      ]),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await ref.read(notificationActionsProvider).markAllRead();
    messenger.showSnackBar(SnackBar(
      content: Text(failure?.message ?? 'Toutes les notifications sont marquées comme lues.'),
    ));
  }
}

class _GroupedList extends ConsumerWidget {
  const _GroupedList({required this.items, this.now});

  final List<AppNotification> items;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = groupNotifications(items, now: now);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final g in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              g.section.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
          ),
          for (final n in g.items)
            Dismissible(
              key: ValueKey('notification-${n.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppColors.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
              confirmDismiss: (_) => _delete(context, ref, n),
              child: Column(children: [
                NotificationTile(notification: n, now: now, onTap: () => _open(context, ref, n)),
                const Divider(height: 1, color: AppColors.line),
              ]),
            ),
        ],
      ],
    );
  }

  Future<bool> _delete(BuildContext context, WidgetRef ref, AppNotification n) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await ref.read(notificationActionsProvider).delete(n.id);
    messenger.showSnackBar(SnackBar(content: Text(failure?.message ?? 'Notification supprimée.')));
    // The live list removes the row itself; on failure it stays.
    return failure == null;
  }

  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    if (!n.read) ref.read(notificationActionsProvider).markRead(n.id);
    final route = routeFor(n);
    if (route != null) {
      context.push(route);
      return;
    }
    // Self-contained (announcement, warning): show the full text.
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 4),
            Text(formatNotificationTime(n.createdAt, now: now),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            Text(n.body, style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.text)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Fermer'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: AppColors.muted),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.35)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}
