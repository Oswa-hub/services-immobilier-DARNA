import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/agent_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/entities/agent_profile.dart';
import '../../domain/entities/verification_request.dart';
import '../../domain/services/profile_completion.dart';
import '../providers/agent_providers.dart';
import '../widgets/agent_gate.dart';
import '../widgets/agent_header.dart';
import '../widgets/agent_stat_card.dart';
import '../widgets/agent_states.dart';
import '../widgets/inquiry_tile.dart';
import '../widgets/notification_tile.dart';
import '../widgets/verification_status_card.dart';

/// `/agent`: the starting point of a professional account (spec §5.2).
class AgentDashboardPage extends StatelessWidget {
  const AgentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => AgentGate(
        title: 'Espace agent',
        builder: (context, ref, profile) => _Dashboard(profile: profile),
      );
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.profile});

  final AgentProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(agentDashboardStatsProvider);
    final request = ref.watch(agentVerificationProvider).value;
    final status = effectiveVerificationStatus(profile.verificationStatus, request);
    final completion = ProfileCompletion.of(profile);
    final me = ref.watch(currentUserProvider)?.id ?? '';
    final inquiries = ref.watch(agentInquiriesProvider);
    final notifications = ref.watch(agentNotificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Espace agent')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(agentListingsProvider);
          ref.invalidate(agentListingStatsProvider);
          ref.invalidate(agentVerificationProvider);
          ref.invalidate(agentInquiriesProvider);
          ref.invalidate(agentNotificationsProvider);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Row(children: [
                  AgentAvatar(name: profile.displayName, imageUrl: profile.profileImageUrl, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Bienvenue, ${profile.displayName}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                  ),
                ]),
                const SizedBox(height: 16),
                _CompletionCard(completion: completion, onTap: () => context.push(Routes.agentProfileEdit)),
                const SizedBox(height: 12),
                VerificationStatusCard(
                  status: status,
                  request: request,
                  onTap: () => context.push(Routes.agentVerification),
                ),
                const SectionTitle('Performances'),
                stats.when(
                  loading: () => const Column(children: [
                    Row(children: [Expanded(child: SkeletonBox(height: 92)), SizedBox(width: 10), Expanded(child: SkeletonBox(height: 92))]),
                    SizedBox(height: 10),
                    Row(children: [Expanded(child: SkeletonBox(height: 92)), SizedBox(width: 10), Expanded(child: SkeletonBox(height: 92))]),
                  ]),
                  error: (e, _) => AgentErrorView(
                    message: e is AgentFailure ? e.message : const AgentFailure(AgentFailureType.listingsFailed).message,
                    onRetry: () => ref.invalidate(agentListingsProvider),
                  ),
                  data: (s) => !s.hasListings
                      ? AgentCard(
                          child: Column(children: [
                            const Text(
                              'Vous n\'avez encore publié aucun bien. Créez votre première annonce pour commencer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => context.push(Routes.publish),
                              icon: const Icon(Icons.add_home_work_outlined),
                              label: const Text('Publier un bien'),
                            ),
                          ]),
                        )
                      : AgentStatGrid(cards: [
                          AgentStatCard(icon: Icons.home_work_outlined, label: 'Annonces', value: s.totalListings, onTap: () => context.push(Routes.agentListings)),
                          AgentStatCard(icon: Icons.check_circle_outline, label: 'Publiées', value: s.published, onTap: () => context.push(Routes.agentListings)),
                          AgentStatCard(icon: Icons.hourglass_top_rounded, label: 'En attente', value: s.pending, onTap: () => context.push(Routes.agentListings)),
                          AgentStatCard(icon: Icons.visibility_outlined, label: 'Vues', value: s.views, onTap: () => context.push(Routes.agentStatistics)),
                          AgentStatCard(icon: Icons.chat_bubble_outline_rounded, label: 'Demandes', value: s.contacts, onTap: () => context.push(Routes.agentInquiries)),
                          AgentStatCard(icon: Icons.favorite_border, label: 'Favoris', value: s.favorites, onTap: () => context.push(Routes.agentStatistics)),
                        ]),
                ),
                const SectionTitle('Actions rapides'),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: () => context.push(Routes.publish),
                    icon: const Icon(Icons.add_home_work_outlined),
                    label: const Text('Publier un bien'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.agentProfileEdit),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Modifier le profil'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.agentListings),
                    icon: const Icon(Icons.list_alt_rounded),
                    label: const Text('Mes annonces'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.agentStatistics),
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: const Text('Statistiques'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.agentProfile),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Profil public'),
                  ),
                ]),
                SectionTitle('Messages récents',
                    trailing: TextButton(onPressed: () => context.push(Routes.agentInquiries), child: const Text('Tout voir'))),
                inquiries.when(
                  loading: () => const SkeletonBox(height: 70),
                  error: (_, _) => const Text('Impossible de charger vos messages.', style: TextStyle(color: AppColors.muted)),
                  data: (items) => items.isEmpty
                      ? const Text('Vous n\'avez encore aucune demande. Les nouveaux messages sur vos biens apparaîtront ici.',
                          style: TextStyle(color: AppColors.muted, height: 1.4))
                      : Column(children: [
                          for (final c in items.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InquiryTile(conversation: c, me: me, onTap: () => context.push(Routes.chat(c.id))),
                            ),
                        ]),
                ),
                const SectionTitle('Activité récente'),
                notifications.when(
                  loading: () => const SkeletonBox(height: 70),
                  error: (_, _) => const Text('Impossible de charger votre activité.', style: TextStyle(color: AppColors.muted)),
                  data: (items) => items.isEmpty
                      ? const Text('Rien de nouveau pour le moment.', style: TextStyle(color: AppColors.muted))
                      : Column(children: [
                          for (final n in items.take(5))
                            NotificationTile(
                              notification: n,
                              onTap: () {
                                if (!n.read) ref.read(agentRepositoryProvider).markNotificationRead(n.id).ignore();
                                final route = routeForNotification(n);
                                if (route != null) context.push(route);
                              },
                            ),
                        ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.completion, required this.onTap});

  final ProfileCompletion completion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AgentCard(
        onTap: completion.isComplete ? null : onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Profil complété', style: TextStyle(fontWeight: FontWeight.w800))),
            Text('${completion.percent}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completion.percent / 100,
              minHeight: 8,
              semanticsLabel: 'Profil complété',
              semanticsValue: '${completion.percent}%',
            ),
          ),
          if (!completion.isComplete) ...[
            const SizedBox(height: 8),
            Text(completion.missing.first, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ]),
      );
}
