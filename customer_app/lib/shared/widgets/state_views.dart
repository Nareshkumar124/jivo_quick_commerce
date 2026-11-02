import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../l10n/generated/app_localizations.dart';

/// Error with a retry button (`03 §4`). [error] is mapped through jivo_core;
/// raw exception text is never shown.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(JivoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: JivoSpacing.lg),
            Text(
              describeErrorWithDetails(context, error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JivoSpacing.xl),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// A centred message for empty lists.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(JivoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: JivoSpacing.lg),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: JivoSpacing.xl),
            action!,
          ],
        ],
      ),
    ),
  );
}

/// Grey placeholder rows shown while a list loads (`03 §4`).
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.rows = 3, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
    );
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ExcludeSemantics(
        child: ListView.separated(
          padding: const EdgeInsets.all(JivoSpacing.gutter),
          itemCount: rows,
          separatorBuilder: (_, _) => const SizedBox(height: JivoSpacing.lg),
          itemBuilder: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(120, 16),
              const SizedBox(height: JivoSpacing.sm),
              bar(double.infinity, 14),
              const SizedBox(height: JivoSpacing.xs),
              bar(200, 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width primary button that shows progress and is disabled while
/// [busy] (`03 §4`).
class BusyButton extends StatelessWidget {
  const BusyButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: label,
              ),
            )
          : Text(label),
    ),
  );
}

/// Shows [message] in a snackbar.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
