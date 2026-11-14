import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/presentation/cart_bar.dart';
import '../l10n/generated/app_localizations.dart';

/// The bottom tabs (`03 §1`): Home, Categories, Order again, Account. The
/// floating cart bar sits above them on the shopping tabs.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  static const accountTab = 3;

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Tooltips are off: the labels are always visible, and the home header
    // already has an "Account" button.
    NavigationDestination tab(IconData icon, IconData selected, String label) =>
        NavigationDestination(
          icon: Icon(icon),
          selectedIcon: Icon(selected),
          label: label,
          tooltip: '',
        );
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shell.currentIndex != accountTab) const CartBar(),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (index) => shell.goBranch(
              index,
              initialLocation: index == shell.currentIndex,
            ),
            destinations: [
              tab(Icons.home_outlined, Icons.home_rounded, l10n.tabHome),
              tab(
                Icons.grid_view_outlined,
                Icons.grid_view_rounded,
                l10n.tabCategories,
              ),
              tab(
                Icons.replay_rounded,
                Icons.replay_circle_filled_rounded,
                l10n.tabOrderAgain,
              ),
              tab(
                Icons.person_outline_rounded,
                Icons.person_rounded,
                l10n.tabAccount,
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }
}
