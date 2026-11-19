import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../property_discovery/presentation/widgets/discovery_states.dart';
import '../providers/messaging_providers.dart';
import '../widgets/conversation_tile.dart';

/// Messages tab (Module 11): every conversation of the signed-in user, as a
/// buyer/renter or as an owner/agent, newest first.
/// States: loading, success, empty, error, offline.
class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id ?? '';
    final state = ref.watch(myConversationsProvider);
    final unread = state.value?.unreadCountFor(me) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720), // tablets
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Messages',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(
                    unread == 0
                        ? 'Vos échanges avec les propriétaires et les agents.'
                        : unread == 1
                            ? '1 conversation non lue'
                            : '$unread conversations non lues',
                    style: TextStyle(
                      fontSize: 13,
                      color: unread == 0 ? AppColors.muted : AppColors.accent,
                      fontWeight: unread == 0 ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ]),
              ),
              Expanded(
                child: state.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: const [_Skeleton(), SizedBox(height: 12), _Skeleton(), SizedBox(height: 12), _Skeleton()],
                  ),
                  error: (_, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: DiscoveryErrorState(
                        message: 'Impossible de charger vos conversations.',
                        onRetry: () => ref.invalidate(myConversationsProvider),
                      ),
                    ),
                  ),
                  data: (list) => Column(children: [
                    _OfflineBanner(fromCache: list.fromCache),
                    Expanded(
                      child: list.items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: DiscoveryEmptyState(
                                  icon: Icons.chat_bubble_outline_rounded,
                                  title: 'Aucune conversation',
                                  message: 'Ouvrez une annonce et contactez son propriétaire ou son agent.',
                                  actionLabel: 'Explorer les biens',
                                  onAction: () => context.go(Routes.search),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                              itemCount: list.items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (_, i) => ConversationTile(
                                key: ValueKey(list.items[i].id),
                                conversation: list.items[i],
                                me: me,
                                onTap: () => context.push(Routes.chat(list.items[i].id)),
                              ),
                            ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
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
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: const Row(children: [
        Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.accent),
        SizedBox(width: 10),
        Expanded(
          child: Text('Hors connexion. Conversations enregistrées affichées.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
        ),
      ]),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 84,
        decoration: BoxDecoration(color: const Color(0xFFE9EEF6), borderRadius: BorderRadius.circular(20)),
      );
}
