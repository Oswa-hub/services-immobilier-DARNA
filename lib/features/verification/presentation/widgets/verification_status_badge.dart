import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/entities/verification_enums.dart';

/// Status pill (spec §12.3). Icon + text, never colour alone.
class VerificationStatusBadge extends StatelessWidget {
  const VerificationStatusBadge({super.key, required this.status});

  final VerificationStatus status;

  ({IconData icon, Color color}) get _style => switch (status) {
        VerificationStatus.notSubmitted => (icon: Icons.shield_outlined, color: AppColors.muted),
        VerificationStatus.pending => (icon: Icons.hourglass_top_rounded, color: const Color(0xFFB7791F)),
        VerificationStatus.approved => (icon: Icons.verified_rounded, color: AppColors.success),
        VerificationStatus.rejected => (icon: Icons.error_outline_rounded, color: AppColors.error),
        VerificationStatus.expired => (icon: Icons.history_toggle_off_rounded, color: AppColors.error),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Semantics(
      label: 'Statut de vérification : ${status.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: s.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(s.icon, size: 15, color: s.color),
          const SizedBox(width: 5),
          Text(status.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.color)),
        ]),
      ),
    );
  }
}
