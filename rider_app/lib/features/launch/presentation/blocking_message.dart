import 'package:flutter/material.dart';

/// Full-screen message layout shared by splash errors, update, maintenance
/// and the status screens: icon, title and body, then the actions at the
/// bottom.
///
/// UX audit RA-01: the icon, title and body scroll (centred while they
/// fit), and the actions stay pinned at the bottom, so at 200 % text on a
/// small phone the only way forward ("Update now", "Try again") is never
/// cut off. The actions take at most half the screen and scroll themselves
/// beyond that. The 80 dp icon is hidden above 1.5× text.
class BlockingMessage extends StatelessWidget {
  const BlockingMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  /// Above this text scale the icon is left out (it saves about 100 dp).
  static const iconTextScaleLimit = 1.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showIcon =
        MediaQuery.textScalerOf(context).scale(10) / 10 <= iconTextScaleLimit;
    final message = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 32).clamp(0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showIcon) ...[
                Icon(icon, size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: message),
          if (actions.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 2,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, action) in actions.indexed) ...[
                      if (i > 0) const SizedBox(height: 8),
                      action,
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
