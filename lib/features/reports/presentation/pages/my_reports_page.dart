import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/report_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/report.dart';
import '../providers/report_providers.dart';

String _date(DateTime? d) {
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

Color reportStatusColor(ReportStatus s) => switch (s) {
      ReportStatus.open => AppColors.accent,
      ReportStatus.investigating => AppColors.primary,
      ReportStatus.resolved => AppColors.success,
      ReportStatus.rejected => AppColors.muted,
    };

/// Module 14 — `/reports`: the reports I filed and the users I blocked.
class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Signalements et sécurité'),
            bottom: const TabBar(tabs: [Tab(text: 'Mes signalements'), Tab(text: 'Utilisateurs bloqués')]),
          ),
          body: const TabBarView(children: [_MyReports(), _Blocked()]),
        ),
      );
}

class _MyReports extends ConsumerWidget {
  const _MyReports();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);
    return reports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        icon: Icons.cloud_off_rounded,
        text: e is ReportFailure ? e.message : 'Impossible de charger vos signalements.',
        onRetry: () => ref.invalidate(myReportsProvider),
      ),
      data: (list) => list.isEmpty
          ? const _Message(
              icon: Icons.flag_outlined,
              text: 'Vous n’avez fait aucun signalement.\n'
                  'Utilisez le drapeau sur une annonce, un profil ou une conversation pour signaler un problème.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ReportCard(report: list[i]),
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final color = reportStatusColor(r.status);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.line)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${r.target.type.label} · ${r.reasonLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(r.status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (r.target.label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.target.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 6),
          Text('Envoyé le ${_date(r.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          if (r.status.isClosed && (r.resolution ?? '').isNotEmpty) ...[
            const Divider(height: 18),
            Text('Réponse de la modération (${_date(r.closedAt)})',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(r.resolution!),
          ],
        ]),
      ),
    );
  }
}

class _Blocked extends ConsumerWidget {
  const _Blocked();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    return blocked.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Message(
        icon: Icons.cloud_off_rounded,
        text: e is ReportFailure ? e.message : 'Impossible de charger la liste.',
        onRetry: () => ref.invalidate(blockedUsersProvider),
      ),
      data: (list) => list.isEmpty
          ? const _Message(
              icon: Icons.block,
              text: 'Vous n’avez bloqué personne.\nUn utilisateur bloqué ne peut plus vous envoyer de messages.',
            )
          : ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final b = list[i];
                return ListTile(
                  tileColor: Colors.white,
                  leading: const Icon(Icons.block, color: AppColors.error),
                  title: Text(b.name),
                  subtitle: Text('Bloqué le ${_date(b.since)}'),
                  trailing: TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final f = await ref.read(reportActionsProvider).unblock(b.id);
                      messenger.showSnackBar(SnackBar(content: Text(f?.message ?? '${b.name} est débloqué.')));
                    },
                    child: const Text('Débloquer'),
                  ),
                );
              },
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ]),
        ),
      );
}
