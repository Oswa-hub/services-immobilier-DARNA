import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/admin_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

/// Module 15 — `/admin/audit-logs`: the 100 latest entries, filterable.
class AdminAuditLogsPage extends ConsumerStatefulWidget {
  const AdminAuditLogsPage({super.key});

  @override
  ConsumerState<AdminAuditLogsPage> createState() => _AdminAuditLogsPageState();
}

class _AdminAuditLogsPageState extends ConsumerState<AdminAuditLogsPage> {
  String _query = '';

  bool _matches(AuditEntry a) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [a.action, a.actorId, a.targetType, a.targetId, a.reason]
        .whereType<String>()
        .any((v) => v.toLowerCase().contains(q));
  }

  static IconData _icon(String action) => switch (action.split('.').first) {
        'user' => Icons.person_outline,
        'property' => Icons.home_work_outlined,
        'verification' => Icons.verified_user_outlined,
        'notification' => Icons.campaign_outlined,
        'content' => Icons.category_outlined,
        'settings' => Icons.settings_outlined,
        _ => Icons.history_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(adminAuditLogsProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.filter_list),
            hintText: 'Filtrer : action, administrateur, cible, motif',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      Expanded(
        child: logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AdminMessage.error(e, onRetry: () => ref.invalidate(adminAuditLogsProvider)),
          data: (all) {
            final list = all.where(_matches).toList();
            if (list.isEmpty) return const AdminMessage(icon: Icons.history_rounded, text: 'Aucune entrée.');
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = list[i];
                final change = a.previousStatus != null || a.newStatus != null
                    ? ' · ${a.previousStatus ?? '?'} → ${a.newStatus ?? '?'}'
                    : '';
                return ListTile(
                  tileColor: Colors.white,
                  leading: Icon(_icon(a.action), color: AppColors.primary),
                  title: Text('${a.action}$change'),
                  subtitle: Text([
                    '${a.targetType ?? ''} ${a.targetId ?? ''}'.trim(),
                    if (a.reason != null) 'Motif : ${a.reason}',
                    'Par ${a.actorRole ?? 'inconnu'} ${a.actorId ?? ''} · ${fmtDate(a.timestamp, time: true)}',
                  ].where((s) => s.isNotEmpty).join('\n')),
                  isThreeLine: a.reason != null,
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
