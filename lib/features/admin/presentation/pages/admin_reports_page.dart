import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/report_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../reports/domain/report.dart';
import '../../../reports/presentation/pages/my_reports_page.dart' show reportStatusColor;
import '../../../reports/presentation/providers/report_providers.dart';
import '../widgets/admin_widgets.dart';

Color _priorityColor(ReportPriority p) => switch (p) {
      ReportPriority.high => AppColors.error,
      ReportPriority.medium => AppColors.accent,
      ReportPriority.low => AppColors.muted,
    };

/// Module 14 + 15 — `/admin/reports` (spec §41): view, assign, investigate,
/// resolve (optionally suspending the listing / account), reject. High-risk
/// reports and targets reported by several people come first.
class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  /// true = all open work (open + investigating); otherwise [_status].
  bool _openWork = true;
  ReportStatus _status = ReportStatus.open;

  ReportStatus? get _serverFilter => _openWork ? null : _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminReportsProvider(_serverFilter));

    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('À traiter'),
              selected: _openWork,
              onSelected: (_) => setState(() => _openWork = true),
            ),
          ),
          for (final s in ReportStatus.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(s.label),
                selected: !_openWork && _status == s,
                onSelected: (_) => setState(() {
                  _openWork = false;
                  _status = s;
                }),
              ),
            ),
        ]),
      ),
      Expanded(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AdminMessage(
            icon: Icons.cloud_off_rounded,
            text: e is ReportFailure ? e.message : 'Chargement impossible.',
            onRetry: () => ref.invalidate(adminReportsProvider(_serverFilter)),
          ),
          data: (all) {
            final counts = ReportPolicy.countByTarget(all.where((r) => !r.status.isClosed));
            final list = [
              for (final r in all)
                if (!_openWork || !r.status.isClosed) r,
            ]..sort((a, b) => ReportPolicy.compareForQueue(a, b, countByTarget: counts));
            if (list.isEmpty) {
              return AdminMessage(
                icon: Icons.verified_outlined,
                text: _openWork ? 'Aucun signalement à traiter 🎉' : 'Aucun signalement.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = list[i];
                final count = counts[ReportPolicy.targetKey(r)] ?? 1;
                final priority = r.status.isClosed ? r.priority : ReportPolicy.escalate(r.priority, count);
                return ListTile(
                  tileColor: Colors.white,
                  leading: CircleAvatar(
                    backgroundColor: _priorityColor(priority).withValues(alpha: 0.14),
                    child: Icon(Icons.flag_rounded, color: _priorityColor(priority)),
                  ),
                  title: Text('${r.target.type.label} · ${r.reasonLabel}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (r.target.label.isNotEmpty) r.target.label,
                      '${fmtDate(r.createdAt)}${count > 1 && !r.status.isClosed ? ' · signalé $count fois' : ''}',
                    ].join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: r.target.label.isNotEmpty,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(r.status.label, reportStatusColor(r.status)),
                      const SizedBox(height: 4),
                      Text(priority.label,
                          style: TextStyle(fontSize: 11.5, color: _priorityColor(priority), fontWeight: FontWeight.w700)),
                    ],
                  ),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => AdminReportSheet(report: r, reportsOnTarget: count),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

/// One report: details + lifecycle actions.
class AdminReportSheet extends ConsumerStatefulWidget {
  const AdminReportSheet({super.key, required this.report, this.reportsOnTarget = 1});

  final Report report;
  final int reportsOnTarget;

  @override
  ConsumerState<AdminReportSheet> createState() => _AdminReportSheetState();
}

class _AdminReportSheetState extends ConsumerState<AdminReportSheet> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action, String success, {bool close = true}) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final error = await action();
    if (mounted) setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? success),
      backgroundColor: error == null ? null : AppColors.error,
    ));
    if (error == null && close && mounted) navigator.pop();
  }

  List<ResolutionAction> get _measures => switch (widget.report.target.type) {
        ReportTargetType.property => const [
            ResolutionAction.none,
            ResolutionAction.listingSuspended,
            ResolutionAction.listingRemoved,
            ResolutionAction.userSuspended,
            ResolutionAction.userBanned,
          ],
        _ => const [ResolutionAction.none, ResolutionAction.userSuspended, ResolutionAction.userBanned],
      };

  Future<void> _close(ReportStatus to) async {
    final result = await showDialog<(String, ResolutionAction)>(
      context: context,
      builder: (_) => _CloseDialog(resolve: to == ReportStatus.resolved, measures: _measures),
    );
    if (result == null || !mounted) return;
    final (note, action) = result;
    await _run(
      () => ref.read(adminReportActionsProvider).close(widget.report, to: to, note: note, action: action),
      to == ReportStatus.resolved ? 'Signalement résolu.' : 'Signalement rejeté.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final me = ref.watch(currentUserProvider)?.id;
    final actions = ref.read(adminReportActionsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${r.target.type.label} · ${r.reasonLabel}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            StatusChip(r.status.label, reportStatusColor(r.status)),
            StatusChip('Priorité ${r.priority.label.toLowerCase()}', _priorityColor(r.priority)),
            if (widget.reportsOnTarget > 1) StatusChip('Signalé ${widget.reportsOnTarget} fois', AppColors.error),
          ]),
          const SizedBox(height: 12),
          _Line('Élément', r.target.label.isEmpty ? r.target.id : r.target.label),
          if (r.description.isNotEmpty) _Line('Détails', r.description),
          _Line('Signalé le', fmtDate(r.createdAt, time: true)),
          _Line('Auteur du signalement', r.reporterId),
          if (r.target.ownerId != null) _Line('Compte concerné', r.target.ownerId!),
          if (r.target.conversationId != null) _Line('Conversation', r.target.conversationId!),
          _Line('Assigné à', r.assignedTo == null ? '—' : (r.assignedTo == me ? 'moi' : r.assignedTo!)),
          if (r.status.isClosed) ...[
            _Line('Décision', r.resolution ?? '—'),
            _Line('Mesure', r.resolutionAction.label),
            _Line('Clôturé le', fmtDate(r.closedAt, time: true)),
          ],
          if (r.target.propertyId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.propertyDetails(r.target.propertyId!));
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Voir l’annonce'),
              ),
            ),
          if (r.target.type == ReportTargetType.agent)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.agentPublic(r.target.id));
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Voir le profil'),
              ),
            ),
          const Divider(height: 28),
          if (r.status.isClosed)
            const Text('Ce signalement est clôturé.', style: TextStyle(color: AppColors.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r.assignedTo != me)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(() => actions.assignToMe(r), 'Signalement assigné.'),
                  icon: const Icon(Icons.person_pin_outlined),
                  label: const Text('M’assigner'),
                ),
              if (r.status == ReportStatus.open)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _run(() => actions.startInvestigation(r), 'Examen commencé.'),
                  icon: const Icon(Icons.search),
                  label: const Text('Commencer l’examen'),
                ),
              if (r.status == ReportStatus.investigating) ...[
                FilledButton.icon(
                  onPressed: _busy ? null : () => _close(ReportStatus.resolved),
                  icon: const Icon(Icons.check),
                  label: const Text('Résoudre'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _close(ReportStatus.rejected),
                  icon: const Icon(Icons.close),
                  label: const Text('Rejeter'),
                ),
              ],
            ]),
        ]),
      ),
    );
  }
}

class _CloseDialog extends StatefulWidget {
  const _CloseDialog({required this.resolve, required this.measures});

  final bool resolve;
  final List<ResolutionAction> measures;

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  // Not disposed in dispose(): the dialog may still be animating out with it.
  final _note = TextEditingController();
  ResolutionAction _action = ResolutionAction.none;
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.resolve ? 'Résoudre le signalement' : 'Rejeter le signalement'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.resolve) ...[
              const Text('Mesure appliquée', style: TextStyle(fontWeight: FontWeight.w700)),
              RadioGroup<ResolutionAction>(
                groupValue: _action,
                onChanged: (a) => setState(() => _action = a ?? ResolutionAction.none),
                child: Column(children: [
                  for (final a in widget.measures)
                    RadioListTile<ResolutionAction>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: a,
                      title: Text(a.label),
                    ),
                ]),
              ),
            ],
            TextField(
              controller: _note,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: ReportPolicy.maxResolution,
              decoration: InputDecoration(
                labelText: 'Décision (envoyée à l’auteur du signalement)',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final problem = ReportPolicy.checkResolution(_note.text);
              if (problem != null) {
                setState(() => _error = problem);
                return;
              }
              Navigator.of(context).pop((_note.text.trim(), widget.resolve ? _action : ResolutionAction.none));
            },
            child: Text(widget.resolve ? 'Résoudre' : 'Rejeter'),
          ),
        ],
      );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: SelectableText(value)),
        ]),
      );
}
