import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../providers/messaging_providers.dart';
import '../widgets/conversation_tile.dart';

/// `/messages`: every conversation of the signed-in user, newest first.
/// States: loading, success, empty, error, offline (spec §6.1).
class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id ?? '';
    final state = ref.watch(myConversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Messages')),
      body: state.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(20),
          children: const [_Skeleton(), SizedBox(height: 10), _Skeleton(), SizedBox(height: 10), _Skeleton()],
        ),
        error: (_, _) => _Message(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          text: 'We could not load your conversations. Please try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(myConversationsProvider),
        ),
        data: (list) => Column(children: [
          _OfflineBanner(fromCache: list.fromCache),
          Expanded(
            child: list.items.isEmpty
                ? _Message(
                    icon: Icons.chat_bubble_outline_rounded,
                    text: 'You have no conversations yet. Open a listing and contact its owner or agent.',
                    actionLabel: 'Browse properties',
                    onAction: () => context.go(Routes.search),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: list.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => ConversationTile(
                      conversation: list.items[i],
                      me: me,
                      onTap: () => context.push(Routes.chat(list.items[i].id)),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Shown only when the data has come from the cache for more than 2 seconds,
/// so the normal cache-then-server load does not flash a warning.
class _OfflineBanner extends StatefulWidget {
  const _OfflineBanner({required this.fromCache});

  final bool fromCache;

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _OfflineBanner old) {
    super.didUpdateWidget(old);
    if (old.fromCache != widget.fromCache) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (widget.fromCache) {
      _timer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _show = true);
      });
    } else {
      _show = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.fromCache && _show)) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF4CE),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.text),
        SizedBox(width: 8),
        Expanded(child: Text('You are offline. Showing saved conversations.', style: TextStyle(fontSize: 12))),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.iconColor = AppColors.primary, this.actionLabel, this.onAction});

  final IconData icon;
  final Color iconColor;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 84,
        decoration: BoxDecoration(color: AppColors.line.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
      );
}
