import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/agent_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../reports/domain/report.dart'; // Module 14
import '../../../reports/presentation/widgets/report_sheet.dart';
import '../providers/agent_providers.dart';
import '../widgets/agent_profile_view.dart';
import '../widgets/agent_states.dart';

/// `/agents/:agentId`: visitors and users see the public professional profile.
/// A missing or non-public profile is a normal "not available" state.
class PublicAgentProfilePage extends ConsumerWidget {
  const PublicAgentProfilePage({super.key, required this.agentId});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicAgentProfileProvider(agentId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Professional profile'),
        actions: [
          // Module 14: report a professional (not yourself).
          if (profile.value case final p? when ref.watch(currentUserProvider)?.id != agentId)
            ReportButton(
              tooltip: 'Signaler ce profil',
              target: ReportTarget.user(id: agentId, name: p.displayName, agent: true),
            ),
        ],
      ),
      body: profile.when(
        loading: () => const AgentLoading(),
        error: (e, _) => AgentErrorView(
          // Rules deny reading a private / suspended profile -> "not available".
          message: e is AgentFailure && e.type == AgentFailureType.permissionDenied
              ? 'This profile is not available.'
              : 'We could not load this profile. Please try again.',
          onRetry: () => ref.invalidate(publicAgentProfileProvider(agentId)),
        ),
        data: (p) => (p == null || !p.isPublic)
            ? const AgentEmptyView(icon: Icons.person_off_outlined, message: 'This profile is not available.')
            : AgentProfileView(profile: p),
      ),
    );
  }
}
