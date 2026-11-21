import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/agent_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../properties/domain/entities/property.dart';
import '../providers/agent_providers.dart';
import '../widgets/agent_gate.dart';
import '../widgets/agent_states.dart';
import '../widgets/listing_actions.dart';

/// `/agent/listings`: My professional listings, filtered by lifecycle status.
class AgentListingsPage extends StatelessWidget {
  const AgentListingsPage({super.key});

  static const _tabs = <(String, PropertyStatus?)>[
    ('Toutes', null),
    ('Brouillons', PropertyStatus.draft),
    ('En attente', PropertyStatus.pendingReview),
    ('Publiées', PropertyStatus.published),
    ('Refusées', PropertyStatus.rejected),
    ('Suspendues', PropertyStatus.suspended),
    ('Expirées', PropertyStatus.expired),
  ];

  @override
  Widget build(BuildContext context) => AgentGate(
        title: 'Mes annonces',
        builder: (context, ref, profile) {
          final listings = ref.watch(agentListingsProvider);
          return DefaultTabController(
            length: _tabs.length,
            child: Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                title: const Text('Mes annonces'),
                bottom: TabBar(isScrollable: true, tabs: [
                  for (final t in _tabs)
                    Tab(
                      text: listings.value == null
                          ? t.$1
                          : '${t.$1} (${t.$2 == null ? listings.value!.length : listings.value!.where((p) => p.status == t.$2).length})',
                    ),
                ]),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => context.push(Routes.publish),
                icon: const Icon(Icons.add_home_work_outlined),
                label: const Text('Publier un bien'),
              ),
              body: listings.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(20),
                  children: const [SkeletonBox(height: 120), SizedBox(height: 12), SkeletonBox(height: 120), SizedBox(height: 12), SkeletonBox(height: 120)],
                ),
                error: (e, _) => AgentErrorView(
                  message: e is AgentFailure ? e.message : const AgentFailure(AgentFailureType.listingsFailed).message,
                  onRetry: () => ref.invalidate(agentListingsProvider),
                ),
                data: (all) => TabBarView(children: [
                  for (final t in _tabs) _ListingList(all: all, status: t.$2),
                ]),
              ),
            ),
          );
        },
      );
}

class _ListingList extends ConsumerStatefulWidget {
  const _ListingList({required this.all, required this.status});

  final List<Property> all;
  final PropertyStatus? status;

  @override
  ConsumerState<_ListingList> createState() => _ListingListState();
}

class _ListingListState extends ConsumerState<_ListingList> {
  static const _pageSize = 20;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final items = widget.status == null ? widget.all : widget.all.where((p) => p.status == widget.status).toList();
    final stats = ref.watch(agentListingStatsProvider).value ?? const {};

    Future<void> refresh() async {
      ref.invalidate(agentListingsProvider);
      try {
        await ref.read(agentListingsProvider.future);
      } catch (_) {}
    }

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(children: [
          SizedBox(
            height: 380,
            child: AgentEmptyView(
              icon: Icons.home_work_outlined,
              message: widget.status == null
                  ? 'Vous n\'avez encore publié aucun bien. Créez votre première annonce pour commencer.'
                  : 'Aucune annonce dans ce statut.',
              actionLabel: widget.status == null ? 'Publier un bien' : null,
              onAction: widget.status == null ? () => context.push(Routes.publish) : null,
            ),
          ),
        ]),
      );
    }

    final visible = items.take(_shown).toList();
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        itemCount: visible.length + (items.length > _shown ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == visible.length) {
            return OutlinedButton(
              onPressed: () => setState(() => _shown += _pageSize),
              child: Text('Voir plus (${items.length - _shown} restantes)'),
            );
          }
          final p = visible[i];
          return ListingActions.card(context, ref, p, stats: stats[p.id]);
        },
      ),
    );
  }
}
