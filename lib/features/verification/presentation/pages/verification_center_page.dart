import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../agents/presentation/widgets/agent_states.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/verification_enums.dart';
import '../../domain/services/verification_policy.dart';
import '../providers/verification_providers.dart';
import '../widgets/verification_status_badge.dart';

/// `/verification` (spec §12.1 screen 1): every verification the signed-in user
/// can request, with its status and the next action.
class VerificationCenterPage extends ConsumerWidget {
  const VerificationCenterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Verification')),
      body: user == null
          ? const AgentEmptyView(icon: Icons.lock_outline, message: 'Sign in to manage your verification.')
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 32), children: [
                  const Text(
                    'Verification is an administrative review of the information and documents you submit. '
                    'A badge shows what was reviewed; it is not a guarantee about a property or a transaction.',
                    style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  _Tile(type: VerificationTargetType.user, targetId: user.id),
                  if (user.role == UserRole.owner) _Tile(type: VerificationTargetType.owner, targetId: user.id),
                  if (user.role == UserRole.agent) _Tile(type: VerificationTargetType.agent, targetId: user.id),
                  const SectionTitle('Listings'),
                  AgentCard(
                    onTap: () => context.push(Routes.myListings),
                    child: const Row(children: [
                      Icon(Icons.home_work_outlined, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Property verification is requested from one of your listings. Open My Listings and choose “Verify this listing”.',
                          style: TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                    ]),
                  ),
                ]),
              ),
            ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.type, required this.targetId});

  final VerificationTargetType type;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = type.docId(targetId);
    final record = ref.watch(verificationProvider(id));
    final status = record.value?.effectiveStatus() ?? VerificationStatus.notSubmitted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AgentCard(
        onTap: record.isLoading
            ? null
            : () => context.push(record.value == null ? Routes.verificationForm(type, targetId) : Routes.verificationDetails(id)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${type.label} verification', style: const TextStyle(fontWeight: FontWeight.w800))),
            VerificationStatusBadge(status: status),
          ]),
          const SizedBox(height: 6),
          Text(VerificationPolicy.intro(type), style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35)),
          const SizedBox(height: 6),
          Text(status.nextStep, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (record.hasError)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Status could not be loaded.', style: TextStyle(color: AppColors.error, fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}
