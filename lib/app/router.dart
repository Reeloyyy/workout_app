import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/history/ui/history_screen.dart';
import '../features/import/domain/workout_parser.dart';
import '../features/import/import_providers.dart';
import '../features/import/ui/import_preview_screen.dart';
import '../features/import/ui/import_screen.dart';
import '../features/library/ui/library_screen.dart';
import '../features/settings/ui/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _TabShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: 'import',
                    builder: (context, state) => const ImportScreen(),
                    routes: [
                      GoRoute(
                        path: 'preview',
                        redirect: (context, state) =>
                            ref.read(importResultProvider) is ImportSuccess
                            ? null
                            : '/import',
                        builder: (context, state) =>
                            const ImportPreviewScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Bottom navigation for the three top-level tabs.
///
/// Routes that must hide the bar (the player) are declared outside the shell.
class _TabShell extends StatelessWidget {
  const _TabShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
