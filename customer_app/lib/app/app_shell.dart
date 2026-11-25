import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/cart/presentation/cart_bar.dart';
import '../l10n/generated/app_localizations.dart';
import 'theme.dart';

/// The bottom tabs (`03 §1`): Home, Order again, Account. The floating cart
/// bar sits above them on the shopping tabs.
///
/// The Categories tab is hidden (user, 2026-11-25). Its router branch (1)
/// stays, so `/categories` still opens; the bar then marks Home. To bring
/// the tab back, add branch 1 to [_tabBranches] and its destination below.
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  /// Router branch index of the Account tab.
  static const accountTab = 3;

  /// The router branch behind each visible tab, in bar order.
  static const _tabBranches = [0, 2, accountTab];

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
                // A hidden branch (Categories) marks Home.
                selectedIndex: max(
                  0,
                  _tabBranches.indexOf(shell.currentIndex),
                ),
                onDestinationSelected: (index) {
                  final branch = _tabBranches[index];
                  shell.goBranch(
                    branch,
                    initialLocation: branch == shell.currentIndex,
                  );
                },
                destinations: [
                  tab(Icons.home_outlined, l10n.tabHome),
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
