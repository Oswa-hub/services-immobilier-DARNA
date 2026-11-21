import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/verification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../agents/presentation/widgets/agent_formatters.dart';
import '../../../agents/presentation/widgets/agent_states.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/verification_enums.dart';
import '../../domain/entities/verification_record.dart';
import '../providers/verification_providers.dart';
import '../widgets/verification_status_badge.dart';

/// `/admin/verification` (spec §6.2, VER-011, VER-012, VER-019).
/// Filters by status (server side) and by type / text (client side, so no extra
/// Firestore index is needed). Access is enforced by Firestore rules; the route
/// guard only hides the page.
class VerificationQueuePage extends ConsumerStatefulWidget {
  const VerificationQueuePage({super.key});

  @override
  ConsumerState<VerificationQueuePage> createState() => _VerificationQueuePageState();
}

class _VerificationQueuePageState extends ConsumerState<VerificationQueuePage> {
  VerificationStatus _status = VerificationStatus.pending;
  VerificationTargetType? _type;
  String _query = '';

  static const _statuses = [
    VerificationStatus.pending,
    VerificationStatus.approved,
    VerificationStatus.rejected,
    VerificationStatus.expired,
  ];

  List<VerificationRecord> _filter(List<VerificationRecord> all) {
    final q = _query.trim().toLowerCase();
    return [
      for (final r in all)
        if ((_type == null || r.targetType == _type) &&
            (q.isEmpty ||
                r.id.toLowerCase().contains(q) ||
                r.targetId.toLowerCase().contains(q) ||
                r.applicantId.toLowerCase().contains(q)))
          r,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(verificationQueueProvider(_status));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Demandes de vérification')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ID de la demande, de la cible ou du demandeur',
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            for (final s in _statuses) ...[
              ChoiceChip(label: Text(s.label), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
              const SizedBox(width: 8),
            ],
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            ChoiceChip(label: const Text('Tous les types'), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
            for (final t in VerificationTargetType.values) ...[
              const SizedBox(width: 8),
              ChoiceChip(label: Text(t.label), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
            ],
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: queue.when(
            loading: () => const AgentLoading(),
            error: (e, _) => AgentErrorView(
              message: e is VerificationFailure ? e.message : const VerificationFailure(VerificationFailureType.unknown).message,
              onRetry: () => ref.invalidate(verificationQueueProvider(_status)),
            ),
            data: (all) {
              final list = _filter(all);
              if (list.isEmpty) {
                return const AgentEmptyView(icon: Icons.inbox_outlined, message: 'Aucune demande ne correspond à ces filtres.');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _RequestCard(record: list[i]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.record});

  final VerificationRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return AgentCard(
      onTap: () => context.push(Routes.adminVerificationReview(r.id)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.targetType.label, style: const TextStyle(fontWeight: FontWeight.w800))),
          VerificationStatusBadge(status: r.effectiveStatus()),
        ]),
        const SizedBox(height: 6),
        Text('Cible : ${r.targetId}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        Text('Demandeur : ${r.applicantId}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        Text(
          'Submitted ${r.submittedAt == null ? '-' : formatShortDate(r.submittedAt!)} · attempt ${r.attemptNumber} · ${r.documents.length} file(s)',
          style: const TextStyle(fontSize: 12),
        ),
      ]),
    );
  }
}
