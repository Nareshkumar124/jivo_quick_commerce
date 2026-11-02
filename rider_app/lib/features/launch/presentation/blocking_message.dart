import 'package:flutter/material.dart';

/// Full-screen message layout shared by splash errors, update and
/// maintenance: icon, title, body, then the actions at the bottom.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(icon, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
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
            const Spacer(),
            for (final action in actions) ...[
              action,
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
