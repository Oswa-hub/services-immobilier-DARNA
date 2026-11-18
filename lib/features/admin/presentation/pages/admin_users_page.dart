import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/admin_models.dart';
import '../../domain/admin_policy.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

/// Module 15 — `/admin/users` (spec §39): search, filter, view, suspend,
/// restore, ban, delete (soft: status `deleted`), change role.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  AccountStatus? _status;
  UserRole? _role;
  String _query = '';

  /// Server filter: status. Client filters: role + text (no extra index).
  List<AdminUser> _filter(List<AdminUser> all) {
    final q = _query.trim().toLowerCase();
    return [
      for (final u in all)
        if ((_role == null || u.role == _role) &&
            (q.isEmpty ||
                u.email.toLowerCase().contains(q) ||
                (u.name ?? '').toLowerCase().contains(q) ||
                (u.phone ?? '').contains(q) ||
                u.id == _query.trim()))
          u,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider(_status));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Nom, e-mail, téléphone ou identifiant',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final s in <AccountStatus?>[null, ...AccountStatus.values])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(s == null ? 'Tous' : accountStatusLabel(s)),
                selected: _status == s,
                onSelected: (_) => setState(() => _status = s),
              ),
            ),
          const SizedBox(width: 12),
          DropdownButton<UserRole?>(
            value: _role,
            hint: const Text('Rôle'),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<UserRole?>(value: null, child: Text('Tous les rôles')),
              for (final r in UserRole.values) DropdownMenuItem<UserRole?>(value: r, child: Text(roleLabel(r))),
            ],
            onChanged: (r) => setState(() => _role = r),
          ),
        ]),
      ),
      Expanded(
        child: users.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AdminMessage.error(e, onRetry: () => ref.invalidate(adminUsersProvider(_status))),
          data: (all) {
            final list = _filter(all);
            if (list.isEmpty) {
              return const AdminMessage(icon: Icons.person_search_outlined, text: 'Aucun utilisateur ne correspond.');
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final u = list[i];
                return ListTile(
                  tileColor: Colors.white,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.chip,
                    child: Text(u.displayName.isEmpty ? '?' : u.displayName.characters.first.toUpperCase(),
                        style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800)),
                  ),
                  title: Row(children: [
                    Flexible(child: Text(u.displayName, overflow: TextOverflow.ellipsis)),
                    if (u.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: AppColors.primary),
                    ],
                  ]),
                  subtitle: Text('${u.email} · ${roleLabel(u.role)}', overflow: TextOverflow.ellipsis),
                  trailing: StatusChip(accountStatusLabel(u.status), accountStatusColor(u.status)),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => AdminUserSheet(user: u),
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

/// Details + actions for one user.
class AdminUserSheet extends ConsumerWidget {
  const AdminUserSheet({super.key, required this.user});

  final AdminUser user;

  Future<void> _status(BuildContext context, WidgetRef ref, UserAction action) async {
    final reason = await askAdminConfirmation(
      context,
      title: '${action.label} ?',
      message: '${user.displayName} (${user.email}) passera au statut « ${accountStatusLabel(action.target)} ».',
      confirmLabel: action.label,
      needsReason: action.needsReason,
      destructive: action != UserAction.restore,
    );
    if (reason == null || !context.mounted) return;
    final failure = await ref.read(adminActionsProvider).setUserStatus(user, action, reason: reason);
    if (!context.mounted) return;
    showAdminResult(context, failure, 'Compte mis à jour.');
    if (failure == null) Navigator.of(context).pop();
  }

  Future<void> _role(BuildContext context, WidgetRef ref, UserRole role) async {
    final ok = await askAdminConfirmation(
      context,
      title: 'Changer le rôle ?',
      message: '${user.displayName} deviendra « ${roleLabel(role)} ».'
          '${role == UserRole.admin ? '\nCe compte aura TOUS les droits d’administration.' : ''}',
      confirmLabel: 'Confirmer',
      destructive: role == UserRole.admin,
    );
    if (ok == null || !context.mounted) return;
    final failure = await ref.read(adminActionsProvider).setUserRole(user, role);
    if (!context.mounted) return;
    showAdminResult(context, failure, 'Rôle mis à jour.');
    if (failure == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id ?? '';
    final actions = AdminPolicy.userActions(user, actorId: me);
    final canRole = AdminPolicy.canChangeRole(user, actorId: me);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 6),
          StatusChip(accountStatusLabel(user.status), accountStatusColor(user.status)),
          const SizedBox(height: 12),
          _Info('E-mail', user.email),
          _Info('Téléphone', user.phone ?? '—'),
          _Info('Rôle', roleLabel(user.role)),
          _Info('Vérifié', user.verified ? 'Oui' : 'Non'),
          _Info('Inscrit le', fmtDate(user.createdAt)),
          _Info('Identifiant', user.id),
          if (user.statusReason != null) _Info('Motif du statut', user.statusReason!),
          const Divider(height: 28),
          if (user.id == me)
            const Text('C’est votre compte : modifiez-le depuis un autre compte administrateur.',
                style: TextStyle(color: AppColors.muted))
          else ...[
            if (canRole)
              Row(children: [
                const Expanded(child: Text('Rôle', style: TextStyle(fontWeight: FontWeight.w700))),
                DropdownButton<UserRole>(
                  value: user.role,
                  items: [for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(roleLabel(r)))],
                  onChanged: (r) {
                    if (r != null && r != user.role) _role(context, ref, r);
                  },
                ),
              ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in actions)
                a == UserAction.restore
                    ? FilledButton(onPressed: () => _status(context, ref, a), child: Text(a.label))
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                        onPressed: () => _status(context, ref, a),
                        child: Text(a.label),
                      ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(child: SelectableText(value)),
        ]),
      );
}
