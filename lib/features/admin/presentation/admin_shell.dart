import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/presentation/providers/push_registration.dart';
import '../../settings/presentation/providers/platform_settings_providers.dart';

class AdminSection {
  const AdminSection(this.label, this.icon, this.route, {this.external = false});

  final String label;
  final IconData icon;
  final String route;

  /// Opened as a full page (own app bar) instead of inside the shell.
  final bool external;
}

/// Spec §37 — every admin area.
const adminSections = <AdminSection>[
  AdminSection('Tableau de bord', Icons.dashboard_outlined, Routes.adminDashboard),
  AdminSection('Utilisateurs', Icons.people_outline, Routes.adminUsers),
  AdminSection('Annonces', Icons.home_work_outlined, Routes.adminProperties),
  AdminSection('Vérification', Icons.verified_user_outlined, Routes.adminVerification, external: true),
  AdminSection('Signalements', Icons.flag_outlined, Routes.adminReports),
  AdminSection('Notifications', Icons.campaign_outlined, Routes.adminNotifications),
  AdminSection('Contenu', Icons.category_outlined, Routes.adminContent),
  AdminSection('Statistiques', Icons.insights_outlined, Routes.adminAnalytics),
  AdminSection('Paramètres', Icons.settings_outlined, Routes.adminSettings),
  AdminSection('Journal d’audit', Icons.history_rounded, Routes.adminAuditLogs),
];

/// Module 15 — admin layout (go_router ShellRoute). Navigation rail on wide
/// screens, drawer on phones. Access: router guard (`/admin` = admins only) and
/// Firestore rules (`isAdmin()`).
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _index {
    final i = adminSections.indexWhere((s) => location.startsWith(s.route));
    return i < 0 ? 0 : i;
  }

  void _open(BuildContext context, AdminSection s) =>
      s.external ? context.push(s.route) : context.go(s.route);

  Future<void> _logout(WidgetRef ref) async {
    await ref.read(pushRegistrarProvider).unregister();
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // Keeps `settings/platform` loaded: moderation uses its expiry period and
    // notification mode (AdminActions reads it synchronously).
    ref.watch(platformSettingsProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final current = adminSections[_index];

    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 230,
            backgroundColor: Colors.white,
            selectedIndex: _index,
            onDestinationSelected: (i) => _open(context, adminSections[i]),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('DARNA Admin',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy, fontSize: 18)),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextButton.icon(
                      onPressed: () => context.go(Routes.home),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Voir l’application'),
                    ),
                    TextButton.icon(
                      onPressed: () => _logout(ref),
                      icon: const Icon(Icons.logout),
                      label: const Text('Déconnexion'),
                    ),
                  ]),
                ),
              ),
            ),
            destinations: [
              for (final s in adminSections) NavigationRailDestination(icon: Icon(s.icon), label: Text(s.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(children: [
              _TopBar(title: current.label, email: user?.email),
              Expanded(child: child),
            ]),
          ),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(current.label, style: const TextStyle(fontWeight: FontWeight.w800))),
      drawer: Drawer(
        child: SafeArea(
          child: Column(children: [
            ListTile(
              title: const Text('DARNA Admin',
                  style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.navy, fontSize: 18)),
              subtitle: Text(user?.email ?? ''),
            ),
            const Divider(),
            Expanded(
              child: ListView(children: [
                for (var i = 0; i < adminSections.length; i++)
                  ListTile(
                    leading: Icon(adminSections[i].icon),
                    title: Text(adminSections[i].label),
                    selected: i == _index,
                    onTap: () {
                      Navigator.of(context).pop();
                      _open(context, adminSections[i]);
                    },
                  ),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Voir l’application'),
              onTap: () => context.go(Routes.home),
            ),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Déconnexion'), onTap: () => _logout(ref)),
          ]),
        ),
      ),
      body: child,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.email});
  final String title;
  final String? email;

  @override
  Widget build(BuildContext context) => Container(
        height: 60,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
          if (email != null) Text(email!, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
}
