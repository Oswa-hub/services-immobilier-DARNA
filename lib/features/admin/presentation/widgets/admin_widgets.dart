import 'package:flutter/material.dart';

import '../../../../core/errors/admin_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../properties/domain/entities/property.dart';
import '../../domain/admin_policy.dart';

// ---- labels (French) -------------------------------------------------------------

String accountStatusLabel(AccountStatus s) => switch (s) {
      AccountStatus.active => 'Actif',
      AccountStatus.suspended => 'Suspendu',
      AccountStatus.banned => 'Banni',
      AccountStatus.pending => 'En attente',
      AccountStatus.deleted => 'Supprimé',
    };

Color accountStatusColor(AccountStatus s) => switch (s) {
      AccountStatus.active => AppColors.success,
      AccountStatus.pending => AppColors.muted,
      _ => AppColors.error,
    };

String roleLabel(UserRole r) => switch (r) {
      UserRole.user => 'Utilisateur',
      UserRole.owner => 'Propriétaire',
      UserRole.agent => 'Agent',
      UserRole.admin => 'Administrateur',
    };

String propertyStatusLabel(PropertyStatus s) => switch (s) {
      PropertyStatus.draft => 'Brouillon',
      PropertyStatus.pendingReview => 'En attente',
      PropertyStatus.published => 'Publiée',
      PropertyStatus.rejected => 'Refusée',
      PropertyStatus.suspended => 'Suspendue',
      PropertyStatus.removed => 'Retirée',
      PropertyStatus.expired => 'Expirée',
    };

Color propertyStatusColor(PropertyStatus s) => switch (s) {
      PropertyStatus.published => AppColors.success,
      PropertyStatus.pendingReview => AppColors.accent,
      PropertyStatus.rejected || PropertyStatus.suspended => AppColors.error,
      _ => AppColors.muted,
    };

String fmtDate(DateTime? d, {bool time = false}) {
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  final day = '${two(d.day)}/${two(d.month)}/${d.year}';
  return time ? '$day ${two(d.hour)}:${two(d.minute)}' : day;
}

String fmtPrice(num price, [String currency = 'TND']) {
  final s = price.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
  return '$s $currency';
}

// ---- widgets -------------------------------------------------------------------

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, required this.icon, this.color = AppColors.navy, this.onTap});

  final String label;
  final int? value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(value?.toString() ?? '—',
                          maxLines: 1,
                          style: TextStyle(fontSize: 22, height: 1.1, fontWeight: FontWeight.w900, color: color)),
                      const SizedBox(height: 2),
                      Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, height: 1.2, color: AppColors.muted)),
                    ]),
              ),
            ]),
          ),
        ),
      );
}

class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
          ?trailing,
        ]),
      );
}

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        child: child,
      );
}

class AdminMessage extends StatelessWidget {
  const AdminMessage({super.key, required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  factory AdminMessage.error(Object e, {VoidCallback? onRetry}) => AdminMessage(
        icon: Icons.cloud_off_rounded,
        text: e is AdminFailure ? e.message : 'Une erreur est survenue.',
        onRetry: onRetry,
      );

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ]),
        ),
      );
}

/// Asks a confirmation, with a mandatory reason when [needsReason].
/// Returns null when cancelled, '' when confirmed without reason.
Future<String?> askAdminConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool needsReason = false,
  bool destructive = false,
}) {
  final controller = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message),
          if (needsReason) ...[
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: AdminPolicy.maxReasonLength,
              decoration: InputDecoration(
                labelText: 'Motif (communiqué à l’utilisateur)',
                errorText: error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
            onPressed: () {
              if (needsReason) {
                final problem = AdminPolicy.checkReason(controller.text);
                if (problem != null) {
                  setState(() => error = problem);
                  return;
                }
              }
              Navigator.of(ctx).pop(needsReason ? controller.text.trim() : '');
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  // The controller is not disposed here: the dialog still uses it during its
  // closing animation. It is garbage-collected with the dialog.
}

void showAdminResult(BuildContext context, AdminFailure? failure, String success) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(failure?.message ?? success),
    backgroundColor: failure == null ? null : AppColors.error,
  ));
}
