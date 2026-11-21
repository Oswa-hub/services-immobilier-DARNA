import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/verification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../agents/presentation/widgets/agent_formatters.dart';
import '../../../agents/presentation/widgets/agent_states.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/services/verification_state_machine.dart';
import '../providers/verification_providers.dart';
import '../widgets/submitted_data_view.dart';
import '../widgets/verification_document_viewer.dart';
import '../widgets/verification_history_list.dart';
import '../widgets/verification_status_badge.dart';

/// `/verification/:id` (spec §12.1 screen 6): status, dates, rejection reason,
/// own documents, history, and the resubmit action when the state machine allows.
class VerificationDetailsPage extends ConsumerWidget {
  const VerificationDetailsPage({super.key, required this.verificationId});

  final String verificationId;

  /// Guidance text shown under the title. Defined here because
  /// `VerificationStatus` has no `nextStep` getter.
  /// Uses the state machine so it works for any status without needing
  /// to know every enum case.
  static String _nextStep(VerificationStatus status) {
    if (status == VerificationStatus.rejected) {
      return 'Lisez le motif ci-dessous, corrigez puis renvoyez.';
    }
    if (VerificationStateMachine.canSubmit(status)) {
      return 'Vous pouvez envoyer une nouvelle demande de vérification.';
    }
    return 'Votre demande est en cours de traitement. Cette page sera mise à jour dès qu\'une décision sera prise.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(verificationProvider(verificationId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Détails de la vérification')),
      body: async.when(
        loading: () => const AgentLoading(),
        error: (e, _) => AgentErrorView(
          message: e is VerificationFailure ? e.message : const VerificationFailure(VerificationFailureType.unknown).message,
          onRetry: () => ref.invalidate(verificationProvider(verificationId)),
        ),
        data: (r) {
          if (r == null) {
            return const AgentEmptyView(icon: Icons.search_off_rounded, message: 'Cette demande de vérification est introuvable.');
          }
          final status = r.effectiveStatus();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
                Row(children: [
                  Expanded(child: Text('${r.targetType.label} verification', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  VerificationStatusBadge(status: status),
                ]),
                const SizedBox(height: 8),
                Text(_nextStep(status), style: const TextStyle(color: AppColors.muted, height: 1.4)),
                if (status == VerificationStatus.rejected && r.rejectionReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(12)),
                    child: Text('Motif : ${r.rejectionReason}'),
                  ),
                ],
                const SectionTitle('Dates'),
                _line('Envoyée', r.submittedAt == null ? '-' : formatShortDate(r.submittedAt!)),
                if (r.reviewedAt != null) _line('Décision', formatShortDate(r.reviewedAt!)),
                if (r.expiresAt != null) _line('Valable jusqu\'au', formatShortDate(r.expiresAt!)),
                _line('Tentative', '${r.attemptNumber}'),
                const SectionTitle('Informations envoyées'),
                SubmittedDataView(type: r.targetType, data: r.submittedData),
                const SectionTitle('Documents'),
                if (r.documents.isEmpty) const Text('Aucun document.', style: TextStyle(color: AppColors.muted)),
                for (final d in r.documents) VerificationDocumentTile(verificationId: r.id, document: d),
                const SectionTitle('Historique'),
                VerificationHistoryList(verificationId: r.id),
                if (VerificationStateMachine.canSubmit(status)) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.push(Routes.verificationForm(r.targetType, r.targetId)),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.all(15)),
                    child: Text(status == VerificationStatus.rejected ? 'Corriger et renvoyer' : 'Envoyer une nouvelle demande'),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 170, child: Text(k, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );
}