import 'package:flutter/material.dart';

/// The bottom of a rider screen: an optional error line, the one primary
/// action (full width, 56 dp from the rider theme) with a busy spinner, and
/// optional secondary actions below it.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              Text(
                error!,
                key: errorKey,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ] else if (hint != null) ...[
              Text(hint!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
            ],
            FilledButton(
              key: buttonKey,
              onPressed: busy ? null : onPressed,
              child: busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(label),
            ),
            for (final action in secondary) ...[
              const SizedBox(height: 8),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
