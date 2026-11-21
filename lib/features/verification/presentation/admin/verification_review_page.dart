import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/verification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../agents/presentation/widgets/agent_formatters.dart';
import '../../../agents/presentation/widgets/agent_states.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/services/verification_state_machine.dart';
import '../providers/verification_providers.dart';
import '../widgets/submitted_data_view.dart';
import '../widgets/verification_document_viewer.dart';
import '../widgets/verification_history_list.dart';
import '../widgets/verification_status_badge.dart';
import 'verification_decision_dialog.dart';

/// `/admin/verification/:id` (spec §12.1 admin screens 3 to 7).
class VerificationReviewPage extends ConsumerWidget {
  const VerificationReviewPage({super.key, required this.verificationId});

  final String verificationId;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<bool> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await action();
    final state = ref.read(verificationReviewProvider);
    messenger.showSnackBar(SnackBar(content: Text(ok ? done : (state.failure?.message ?? 'Une erreur est survenue.'))));
    if (ok && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(verificationProvider(verificationId));
    final me = ref.watch(currentUserProvider);
    final busy = ref.watch(verificationReviewProvider).isBusy;
    final controller = ref.read(verificationReviewProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Examiner la demande')),
      body: async.when(
        loading: () => const AgentLoading(),
        error: (e, _) => AgentErrorView(
          message: e is VerificationFailure ? e.message : const VerificationFailure(VerificationFailureType.unknown).message,
          onRetry: () => ref.invalidate(verificationProvider(verificationId)),
        ),
        data: (r) {
          if (r == null) return const AgentEmptyView(icon: Icons.search_off_rounded, message: 'Demande introuvable.');
          final isOwnRequest = me != null && r.applicantId == me.id;
          final canReview = VerificationStateMachine.canReview(r.status) && !isOwnRequest;
          final canExpire = VerificationStateMachine.canExpire(r.status) && !isOwnRequest;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
                Row(children: [
                  Expanded(child: Text('${r.targetType.label} verification', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  VerificationStatusBadge(status: r.effectiveStatus()),
                ]),
                const SizedBox(height: 6),
                SelectableText('Demande ${r.id}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                SelectableText('Demandeur ${r.applicantId}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                SelectableText('Cible ${r.targetId}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(
                  'Submitted ${r.submittedAt == null ? '-' : formatShortDate(r.submittedAt!)} · attempt ${r.attemptNumber}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (r.reviewedBy != null)
                  Text('Last decision by ${r.reviewedBy} on ${r.reviewedAt == null ? '-' : formatShortDate(r.reviewedAt!)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (r.rejectionReason != null) Text('Motif : ${r.rejectionReason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SectionTitle('Informations envoyées'),
                SubmittedDataView(type: r.targetType, data: r.submittedData),
                const SectionTitle('Documents'),
                const Text(
                  'Examinez uniquement ce qui a été envoyé.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                for (final d in r.documents) VerificationDocumentTile(verificationId: r.id, document: d),
                const SectionTitle('Historique'),
                VerificationHistoryList(verificationId: r.id),
                const SizedBox(height: 20),
                if (isOwnRequest)
                  const Text('Vous ne pouvez pas examiner votre propre demande.', style: TextStyle(color: AppColors.muted)),
                if (canReview)
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final ok = await confirmAction(context,
                                    title: 'Accepter la demande',
                                    message: 'Confirmez que les justificatifs envoyés suffisent pour cette demande.',
                                    confirmLabel: 'Accepter');
                                if (ok && context.mounted) {
                                  await _run(context, ref, () => controller.approve(r.id), 'Demande acceptée.');
                                }
                              },
                        child: const Text('Accepter'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final reason = await askRejectionReason(context);
                                if (reason != null && context.mounted) {
                                  await _run(context, ref, () => controller.reject(r.id, reason), 'Demande refusée.');
                                }
                              },
                        child: const Text('Refuser'),
                      ),
                    ),
                  ]),
                if (canExpire)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await confirmAction(context,
                                title: 'Marquer comme expirée',
                                message: 'Le badge vérifié ne sera plus affiché pour cette cible.',
                                confirmLabel: 'Marquer expirée');
                            if (ok && context.mounted) {
                              await _run(context, ref, () => controller.markExpired(r.id), 'Marquée comme expirée.');
                            }
                          },
                    child: const Text('Marquer comme expirée'),
                  ),
                if (!VerificationStateMachine.canReview(r.status) && !canExpire && !isOwnRequest)
                  const Text('Cette demande n\'est pas en attente d\'examen.', style: TextStyle(color: AppColors.muted)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
