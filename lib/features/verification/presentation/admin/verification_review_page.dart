import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/verification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../agents/presentation/widgets/agent_formatters.dart';
import '../../../agents/presentation/widgets/agent_states.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
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
    messenger.showSnackBar(SnackBar(content: Text(ok ? done : (state.failure?.message ?? 'Something went wrong.'))));
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
      appBar: AppBar(title: const Text('Review request')),
      body: async.when(
        loading: () => const AgentLoading(),
        error: (e, _) => AgentErrorView(
          message: e is VerificationFailure ? e.message : const VerificationFailure(VerificationFailureType.unknown).message,
          onRetry: () => ref.invalidate(verificationProvider(verificationId)),
        ),
        data: (r) {
          if (r == null) return const AgentEmptyView(icon: Icons.search_off_rounded, message: 'Request not found.');
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
                SelectableText('Request ${r.id}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                SelectableText('Applicant ${r.applicantId}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                SelectableText('Target ${r.targetId}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(
                  'Submitted ${r.submittedAt == null ? '-' : formatShortDate(r.submittedAt!)} · attempt ${r.attemptNumber}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (r.reviewedBy != null)
                  Text('Last decision by ${r.reviewedBy} on ${r.reviewedAt == null ? '-' : formatShortDate(r.reviewedAt!)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (r.rejectionReason != null) Text('Reason: ${r.rejectionReason}', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SectionTitle('Submitted information'),
                SubmittedDataView(type: r.targetType, data: r.submittedData),
                const SectionTitle('Documents'),
                const Text(
                  'Review only what was submitted. Opening a document creates a short-lived private link.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                for (final d in r.documents) VerificationDocumentTile(verificationId: r.id, document: d),
                const SectionTitle('History'),
                VerificationHistoryList(verificationId: r.id),
                const SizedBox(height: 20),
                if (isOwnRequest)
                  const Text('You cannot review your own request.', style: TextStyle(color: AppColors.muted)),
                if (canReview)
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: busy
                            ? null
                            : () async {
                                final ok = await confirmAction(context,
                                    title: 'Approve request',
                                    message: 'Confirm that the submitted evidence is sufficient for this request.',
                                    confirmLabel: 'Approve');
                                if (ok && context.mounted) {
                                  await _run(context, ref, () => controller.approve(r.id), 'Request approved.');
                                }
                              },
                        child: const Text('Approve'),
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
                                  await _run(context, ref, () => controller.reject(r.id, reason), 'Request rejected.');
                                }
                              },
                        child: const Text('Reject'),
                      ),
                    ),
                  ]),
                if (canExpire)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await confirmAction(context,
                                title: 'Mark as expired',
                                message: 'The verified badge will no longer be shown for this target.',
                                confirmLabel: 'Mark expired');
                            if (ok && context.mounted) {
                              await _run(context, ref, () => controller.markExpired(r.id), 'Marked as expired.');
                            }
                          },
                    child: const Text('Mark as expired'),
                  ),
                if (!VerificationStateMachine.canReview(r.status) && !canExpire && !isOwnRequest)
                  const Text('This request is not waiting for review.', style: TextStyle(color: AppColors.muted)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
