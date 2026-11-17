import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/notification_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/notification_preferences.dart';
import '../providers/notification_providers.dart';
import '../providers/push_registration.dart';

/// Module 12 — notification preferences (`/notifications/settings`).
///
/// Each switch is saved at once to `users/{uid}.notificationPreferences`; the
/// Cloud Functions read it before delivering anything.
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final pushSupported = ref.watch(pushMessagingProvider).isSupported;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Préférences de notification')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                e is NotificationFailure ? e.message : 'Impossible de charger vos préférences.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(notificationPreferencesProvider),
                child: const Text('Réessayer'),
              ),
            ]),
          ),
        ),
        data: (p) => _Form(prefs: p, pushSupported: pushSupported),
      ),
    );
  }
}

class _Form extends ConsumerWidget {
  const _Form({required this.prefs, required this.pushSupported});

  final NotificationPreferences prefs;
  final bool pushSupported;

  Future<void> _save(BuildContext context, WidgetRef ref, NotificationPreferences next) async {
    final messenger = ScaffoldMessenger.of(context);
    final failure = await ref.read(notificationPreferencesProvider.notifier).save(next);
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const _Section('Ce que vous recevez'),
            _Card(children: [
              _Switch(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Messages',
                subtitle: 'Nouveaux messages et demandes sur vos annonces.',
                value: prefs.newMessages,
                onChanged: (v) => _save(context, ref, prefs.copyWith(newMessages: v)),
              ),
              _Switch(
                icon: Icons.favorite_border_rounded,
                title: 'Favoris',
                subtitle: 'Baisse de prix ou annonce sauvegardée plus disponible.',
                value: prefs.favoriteUpdates,
                onChanged: (v) => _save(context, ref, prefs.copyWith(favoriteUpdates: v)),
              ),
              _Switch(
                icon: Icons.home_work_outlined,
                title: 'Alertes nouvelles annonces',
                subtitle: 'Nouveaux biens dans votre gouvernorat préféré (profil).',
                value: prefs.propertyAlerts,
                onChanged: (v) => _save(context, ref, prefs.copyWith(propertyAlerts: v)),
              ),
              _Switch(
                icon: Icons.campaign_outlined,
                title: 'Annonces de la plateforme',
                subtitle: 'Nouveautés et informations importantes d’ImmoFind.',
                value: prefs.announcements,
                onChanged: (v) => _save(context, ref, prefs.copyWith(announcements: v)),
              ),
              const ListTile(
                leading: Icon(Icons.verified_user_outlined, color: AppColors.muted),
                title: Text('Compte et annonces'),
                subtitle: Text('Modération, vérification et sécurité : toujours activées.'),
                trailing: Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.muted),
              ),
            ]),
            const _Section('Comment vous les recevez'),
            _Card(children: [
              const ListTile(
                leading: Icon(Icons.inbox_outlined, color: AppColors.primary),
                title: Text('Dans l’application'),
                subtitle: Text('Centre de notifications — toujours activé.'),
              ),
              _Switch(
                icon: Icons.phone_iphone_rounded,
                title: 'Notifications push',
                subtitle: pushSupported
                    ? 'Alertes sur cet appareil, même application fermée.'
                    : 'Disponible sur l’application Android / iOS.',
                value: prefs.pushNotifications,
                onChanged: pushSupported ? (v) => _save(context, ref, prefs.copyWith(pushNotifications: v)) : null,
              ),
              _Switch(
                icon: Icons.email_outlined,
                title: 'E-mails',
                subtitle: 'Annonce approuvée ou refusée, résultat de vérification.',
                value: prefs.emailNotifications,
                onChanged: (v) => _save(context, ref, prefs.copyWith(emailNotifications: v)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.muted)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
}
