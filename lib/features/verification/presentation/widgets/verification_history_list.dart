import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../agents/presentation/widgets/agent_formatters.dart';
import '../../domain/entities/verification_enums.dart';
import '../../domain/entities/verification_record.dart';
import '../providers/verification_providers.dart';

/// Append-only review history (spec §9.4, VER-010, VER-018).
class VerificationHistoryList extends ConsumerWidget {
  const VerificationHistoryList({super.key, required this.verificationId});

  final String verificationId;

  static String _label(VerificationHistoryEntry e) => switch (e.action) {
        VerificationAction.submitted => 'Submitted',
        VerificationAction.resubmitted => 'Resubmitted',
        VerificationAction.approved => 'Approved',
        VerificationAction.rejected => 'Changes required',
        VerificationAction.expired => 'Marked expired',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(verificationHistoryProvider(verificationId));
    return history.when(
      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (_, __) => const Text('The history could not be loaded.', style: TextStyle(color: AppColors.muted)),
      data: (items) {
        if (items.isEmpty) return const Text('No history yet.', style: TextStyle(color: AppColors.muted));
        return Column(children: [
          for (final e in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.history, size: 20, color: AppColors.muted),
              title: Text('Attempt ${e.attemptNumber} · ${_label(e)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                if (e.createdAt != null) formatShortDate(e.createdAt!),
                if (e.reason != null) e.reason!,
              ].join(' · ')),
            ),
        ]);
      },
    );
  }
}
