import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/agent_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/agent_dashboard_stats.dart';
import '../providers/agent_providers.dart';
import '../widgets/agent_formatters.dart';
import '../widgets/agent_gate.dart';
import '../widgets/agent_stat_card.dart';
import '../widgets/agent_states.dart';

/// `/agent/statistics` (spec §5.7). Numbers come from trusted counters scoped to
/// the signed-in agent. Charts over time need event history: later iteration.
class AgentStatisticsPage extends StatelessWidget {
  const AgentStatisticsPage({super.key});

  @override
  Widget build(BuildContext context) => AgentGate(
        title: 'Statistiques',
        builder: (context, ref, profile) {
          final stats = ref.watch(agentDashboardStatsProvider);
          final listings = ref.watch(agentListingsProvider).value ?? const <Property>[];
          final perListing = ref.watch(agentListingStatsProvider).value ?? const <String, PropertyStats>{};

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Statistiques')),
            body: stats.when(
              loading: () => const AgentLoading(),
              error: (e, _) => AgentErrorView(
                message: e is AgentFailure ? e.message : const AgentFailure(AgentFailureType.listingsFailed).message,
                onRetry: () => ref.invalidate(agentListingsProvider),
              ),
              data: (s) {
                if (!s.hasListings || !s.hasActivity) {
                  return const AgentEmptyView(
                    icon: Icons.bar_chart_rounded,
                    message: 'Les statistiques apparaîtront quand des utilisateurs consulteront vos biens publiés.',
                  );
                }
                final ranked = [
                  for (final p in listings)
                    if (p.status != PropertyStatus.removed) p,
                ]..sort((a, b) => (perListing[b.id]?.views ?? b.views).compareTo(perListing[a.id]?.views ?? a.views));

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      children: [
                        AgentStatGrid(cards: [
                          AgentStatCard(icon: Icons.visibility_outlined, label: 'Vues', value: s.views),
                          AgentStatCard(icon: Icons.favorite_border, label: 'Favoris', value: s.favorites),
                          AgentStatCard(icon: Icons.chat_bubble_outline_rounded, label: 'Demandes', value: s.contacts),
                          AgentStatCard(icon: Icons.check_circle_outline, label: 'Annonces publiées', value: s.published),
                          if (s.shares > 0) AgentStatCard(icon: Icons.share_outlined, label: 'Partages', value: s.shares),
                        ]),
                        const SectionTitle('Biens par statut'),
                        AgentCard(
                          child: Column(children: [
                            _StatusBar('Publiées', s.published, s.totalListings),
                            _StatusBar('En attente', s.pending, s.totalListings),
                            _StatusBar('Brouillons', s.drafts, s.totalListings),
                            _StatusBar('Refusées', s.rejected, s.totalListings),
                            _StatusBar('Suspendues', s.suspended, s.totalListings),
                            _StatusBar('Expirées', s.expired, s.totalListings),
                          ]),
                        ),
                        const SectionTitle('Performances des annonces'),
                        for (final p in ranked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AgentCard(
                              onTap: () => context.push(Routes.agentListing(p.id)),
                              child: Row(children: [
                                Expanded(
                                  child: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 10),
                                _Mini(Icons.visibility_outlined, perListing[p.id]?.views ?? p.views),
                                _Mini(Icons.favorite_border, perListing[p.id]?.favorites ?? p.favoritesCount),
                                _Mini(Icons.chat_bubble_outline_rounded, perListing[p.id]?.contacts ?? 0),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar(this.label, this.value, this.total);

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : value / total,
                minHeight: 8,
                semanticsLabel: label,
                semanticsValue: '$value of $total',
              ),
            ),
          ),
          SizedBox(width: 34, child: Text('$value', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.icon, this.value);

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: AppColors.muted),
          const SizedBox(width: 3),
          Text(formatCount(value), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      );
}
