import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../dev/property_seeder.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

/// Module 15 — `/admin/dashboard` (spec §38): KPIs + what needs attention.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(adminKpisProvider);
    final pending = ref.watch(adminPropertiesProvider(PropertyStatus.pendingReview));
    final users = ref.watch(adminUsersProvider(null));
    final audit = ref.watch(adminAuditLogsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminKpisProvider.future),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        kpis.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => AdminMessage.error(e, onRetry: () => ref.invalidate(adminKpisProvider)),
          data: (k) => LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 3 : 2);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: cols == 2 ? 1.9 : 2.5,
              children: [
                StatCard(label: 'Utilisateurs', value: k.totalUsers, icon: Icons.people_outline,
                    onTap: () => context.go(Routes.adminUsers)),
                StatCard(label: 'Utilisateurs actifs', value: k.activeUsers, icon: Icons.bolt, color: AppColors.success),
                StatCard(label: 'Nouveaux (7 jours)', value: k.newUsers7d, icon: Icons.person_add_alt, color: AppColors.primary),
                StatCard(label: 'Annonces', value: k.totalProperties, icon: Icons.home_work_outlined,
                    onTap: () => context.go(Routes.adminProperties)),
                StatCard(label: 'Annonces publiées', value: k.publishedProperties, icon: Icons.public, color: AppColors.success),
                StatCard(label: 'En attente de validation', value: k.pendingListings, icon: Icons.hourglass_top_rounded,
                    color: AppColors.accent, onTap: () => context.go(Routes.adminProperties)),
                StatCard(label: 'Vérifications en attente', value: k.pendingVerifications, icon: Icons.verified_user_outlined,
                    color: AppColors.accent, onTap: () => context.push(Routes.adminVerification)),
                StatCard(label: 'Signalements ouverts', value: k.openReports, icon: Icons.flag_outlined, color: AppColors.error),
              ],
            );
          }),
        ),
        AdminSectionTitle(
          'Annonces à valider',
          trailing: TextButton(onPressed: () => context.go(Routes.adminProperties), child: const Text('Tout voir')),
        ),
        AdminCard(
          child: pending.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (e, _) => AdminMessage.error(e),
            data: (list) => list.isEmpty
                ? const ListTile(title: Text('Aucune annonce en attente 🎉'))
                : Column(children: [
                    for (final p in list.take(5))
                      ListTile(
                        leading: const Icon(Icons.home_work_outlined),
                        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${p.governorate} · ${fmtPrice(p.price, p.currency)} · ${fmtDate(p.createdAt)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(Routes.adminProperties),
                      ),
                  ]),
          ),
        ),
        AdminSectionTitle(
          'Inscriptions récentes',
          trailing: TextButton(onPressed: () => context.go(Routes.adminUsers), child: const Text('Tout voir')),
        ),
        AdminCard(
          child: users.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (e, _) => AdminMessage.error(e),
            data: (list) => list.isEmpty
                ? const ListTile(title: Text('Aucun utilisateur.'))
                : Column(children: [
                    for (final u in list.take(5))
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(u.displayName),
                        subtitle: Text('${roleLabel(u.role)} · ${fmtDate(u.createdAt)}'),
                        trailing: StatusChip(accountStatusLabel(u.status), accountStatusColor(u.status)),
                      ),
                  ]),
          ),
        ),
        AdminSectionTitle(
          'Dernières actions de modération',
          trailing: TextButton(onPressed: () => context.go(Routes.adminAuditLogs), child: const Text('Journal')),
        ),
        AdminCard(
          child: audit.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (e, _) => AdminMessage.error(e),
            data: (list) => list.isEmpty
                ? const ListTile(title: Text('Aucune action enregistrée.'))
                : Column(children: [
                    for (final a in list.take(5))
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.history_rounded, size: 20),
                        title: Text('${a.action} · ${a.targetType ?? ''} ${a.targetId ?? ''}'),
                        subtitle: Text(fmtDate(a.timestamp, time: true)),
                      ),
                  ]),
          ),
        ),
        if (kDebugMode) ...[
          const AdminSectionTitle('Outils de développement'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
              onPressed: () => _run(context, () => PropertySeeder(ref.read(firestoreProvider)).seed(), 'Annonces de démo ajoutées'),
              child: const Text('DEBUG : ajouter des annonces de démo'),
            ),
            OutlinedButton(
              onPressed: () => _run(context, () => PropertySeeder(ref.read(firestoreProvider)).clear(), 'Annonces de démo supprimées'),
              child: const Text('DEBUG : supprimer les annonces de démo'),
            ),
          ]),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }

  static Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Échec : $e')));
    }
  }
}
