import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/presentation/cart_bar.dart';
import '../l10n/generated/app_localizations.dart';
import 'theme.dart';

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
    // Line icons in both states (home redesign): the selected tab is told
    // apart by its mint pill, bold label and green colour.
    NavigationDestination tab(IconData icon, String label) =>
        NavigationDestination(icon: Icon(icon), label: label, tooltip: '');
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shell.currentIndex != accountTab) const CartBar(),
          // A hairline instead of a shadow (home redesign).
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: context.customerColors.hairline),
              ),
            ),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: NavigationBar(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: (index) => shell.goBranch(
                  index,
                  initialLocation: index == shell.currentIndex,
                ),
                destinations: [
                  tab(Icons.home_outlined, l10n.tabHome),
                  tab(Icons.grid_view_outlined, l10n.tabCategories),
                  tab(Icons.replay_rounded, l10n.tabOrderAgain),
                  tab(Icons.person_outline_rounded, l10n.tabAccount),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
