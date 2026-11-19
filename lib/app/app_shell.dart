import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/messaging/presentation/providers/messaging_providers.dart';

/// Bottom navigation: Accueil · Explorer · Favoris · Messages · Profil.
/// The map is no longer a tab: it opens from Explorer, so while the map
/// branch (index 2) is active the "Explorer" tab stays highlighted.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Tab position -> router branch index (0 home, 1 search, 2 map, 3 favorites, 4 profile, 5 messages)
  static const _branches = [0, 1, 3, 5, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Module 11: conversations with an unread message (0 for a guest).
    final unread = ref.watch(unreadConversationsCountProvider);
    final i = _branches.indexOf(shell.currentIndex);
    final selected = i == -1 ? 1 : i;

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (tab) {
          final branch = _branches[tab];
          shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
          const NavigationDestination(
              icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorer'),
          const NavigationDestination(
              icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favoris'),
          NavigationDestination(
            icon: _MessagesIcon(unread: unread, selected: false),
            selectedIcon: _MessagesIcon(unread: unread, selected: true),
            label: 'Messages',
            tooltip: unread > 0 ? 'Messages, $unread non lus' : 'Messages',
          ),
          const NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}

/// Messages tab icon with the unread badge (Module 11).
class _MessagesIcon extends StatelessWidget {
  const _MessagesIcon({required this.unread, required this.selected});

  final int unread;
  final bool selected;

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(selected ? Icons.chat_bubble : Icons.chat_bubble_outline),
      );
}
