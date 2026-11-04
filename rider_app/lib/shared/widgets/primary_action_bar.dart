import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';

/// Marks the [PrimaryActionBar]s below it as retrying after a network
/// error: the primary reads "Try again: {label}" (task-step shell §3).
class PrimaryActionRetry extends InheritedWidget {
  const PrimaryActionRetry({
    required this.retrying,
    required super.child,
    super.key,
  });

  final bool retrying;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PrimaryActionRetry>()
          ?.retrying ??
      false;

  @override
  bool updateShouldNotify(PrimaryActionRetry oldWidget) =>
      retrying != oldWidget.retrying;
}

/// The bottom of a rider screen: an optional error line, the one primary
/// action (full width, 56 dp from the rider theme) with a busy spinner, and
/// optional secondary actions.
///
/// - [secondaryAbove]: put the secondary actions above the primary, so the
///   primary is the bottom-most, most reachable target (offer Accept, UX
///   audit RD-04).
/// - [primaryHeight]: a taller primary (64 dp Accept).
/// - The bar never takes more than half the screen; it scrolls instead
///   (200% text, RD-12), with the primary kept last.
/// - Busy: the primary shows a spinner ("Working") and every action in the
///   bar is disabled, so a gloved double tap sends nothing twice (shell §4).
/// - The error line has an icon and is a live region (shell §2).
class PrimaryActionBar extends StatelessWidget {
  const PrimaryActionBar({
    required this.label,
    required this.onPressed,
    this.buttonKey,
    this.busy = false,
    this.error,
    this.errorKey,
    this.hint,
    this.secondary = const [],
    this.secondaryAbove = false,
    this.primaryHeight,
    this.quickRow = const [],
    this.exitLink,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final bool busy;
  final String? error;
  final Key? errorKey;

  /// Shown above the button when there is no error (e.g. why it is
  /// disabled).
  final String? hint;
  final List<Widget> secondary;
  final bool secondaryAbove;
  final double? primaryHeight;

  /// Navigate / Call: equal 56 dp buttons in one sticky row above the error
  /// line (task-step shell §1, audit RD-07).
  final List<Widget> quickRow;

  /// "Can't deliver…": a text button 24 dp below everything else, so a
  /// rushed tap on the primary never lands on it (shell §1, RD-08).
  final Widget? exitLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final height = primaryHeight;
    final retrying = PrimaryActionRetry.of(context) && !busy;
    final primary = FilledButton(
      key: buttonKey,
      style: height == null
          ? null
          : FilledButton.styleFrom(minimumSize: Size.fromHeight(height)),
      onPressed: busy ? null : onPressed,
      child: busy
          ? Semantics(
              label: l10n.taskWorking,
              child: const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            )
          : Text(retrying ? l10n.taskTryAgain(label) : label),
    );
    Widget lockable(Widget action) =>
        IgnorePointer(ignoring: busy, child: action);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: SingleChildScrollView(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (quickRow.isNotEmpty) ...[
                Row(
                  children: [
                    for (var i = 0; i < quickRow.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: lockable(quickRow[i])),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error, color: colors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          key: errorKey,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (hint != null) ...[
                Text(
                  hint!,
                  style: TextStyle(fontSize: 16, color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
              ],
              if (secondaryAbove) ...[
                for (final action in secondary) ...[
                  lockable(action),
                  const SizedBox(height: 16),
                ],
                primary,
              ] else ...[
                primary,
                for (final action in secondary) ...[
                  const SizedBox(height: 8),
                  lockable(action),
                ],
              ],
              if (exitLink case final link?) ...[
                const SizedBox(height: 24),
                lockable(link),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
