import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../settings/presentation/providers/platform_settings_providers.dart';
import '../../domain/admin_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

enum _Target { all, role, user }

/// Module 15 — `/admin/notifications`: platform announcement (everyone / one
/// role) or account warning (one user). Written straight to `notifications`
/// (works on the Spark plan); recipients see them in their center (Module 12).
class AdminNotificationsPage extends ConsumerStatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  ConsumerState<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends ConsumerState<AdminNotificationsPage> {
  _Target _target = _Target.all;
  UserRole _role = UserRole.agent;
  AdminNotificationType _type = AdminNotificationType.announcement;
  final _userId = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _userId.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Audience get _audience => switch (_target) {
        _Target.all => const AllUsers(),
        _Target.role => UsersWithRole(_role),
        _Target.user => SingleUser(_userId.text.trim()),
      };

  String get _audienceLabel => switch (_target) {
        _Target.all => 'tous les utilisateurs actifs',
        _Target.role => 'tous les comptes « ${roleLabel(_role)} » actifs',
        _Target.user => 'l’utilisateur ${_userId.text.trim()}',
      };

  Future<void> _send() async {
    if (_target == _Target.user && _userId.text.trim().isEmpty) {
      showAdminResult(context, null, 'Indiquez l’identifiant de l’utilisateur.');
      return;
    }
    final ok = await askAdminConfirmation(
      context,
      title: 'Envoyer la notification ?',
      message: '« ${_title.text.trim()} » sera envoyée à $_audienceLabel.',
      confirmLabel: 'Envoyer',
    );
    if (ok == null || !mounted) return;

    setState(() => _sending = true);
    final (count, failure) = await ref.read(adminActionsProvider).sendNotification(
          audience: _audience,
          type: _type,
          title: _title.text,
          body: _body.text,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    showAdminResult(context, failure, 'Notification envoyée à $count destinataire${count > 1 ? 's' : ''}.');
    if (failure == null) {
      _title.clear();
      _body.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(platformSettingsProvider).announcementsEnabled;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (!enabled)
            const Card(
              color: AppColors.accentSoft,
              elevation: 0,
              child: ListTile(
                leading: Icon(Icons.info_outline, color: AppColors.accent),
                title: Text('Les annonces sont désactivées dans les Paramètres.'),
                subtitle: Text('Seuls les avertissements individuels peuvent être envoyés.'),
              ),
            ),
          const AdminSectionTitle('Destinataires'),
          SegmentedButton<_Target>(
            segments: const [
              ButtonSegment(value: _Target.all, label: Text('Tous')),
              ButtonSegment(value: _Target.role, label: Text('Par rôle')),
              ButtonSegment(value: _Target.user, label: Text('Un utilisateur')),
            ],
            selected: {_target},
            onSelectionChanged: (s) => setState(() {
              _target = s.first;
              if (_target != _Target.user) _type = AdminNotificationType.announcement;
            }),
          ),
          const SizedBox(height: 12),
          if (_target == _Target.role)
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rôle', border: OutlineInputBorder()),
              items: [for (final r in UserRole.values) DropdownMenuItem(value: r, child: Text(roleLabel(r)))],
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
          if (_target == _Target.user) ...[
            TextField(
              controller: _userId,
              decoration: const InputDecoration(
                labelText: 'Identifiant de l’utilisateur',
                helperText: 'Copiez-le depuis la fiche dans « Utilisateurs ».',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AdminNotificationType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: [
                for (final t in AdminNotificationType.values) DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
          ],
          const AdminSectionTitle('Message'),
          TextField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _body,
            maxLength: 500,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(labelText: 'Texte', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending || (!enabled && _target != _Target.user) ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: const Text('Envoyer'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les notifications apparaissent dans le centre de notifications des destinataires. '
            'Chaque envoi est enregistré dans le journal d’audit.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        ]),
      ),
    );
  }
}
