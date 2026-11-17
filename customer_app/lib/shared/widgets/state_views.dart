import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../l10n/generated/app_localizations.dart';
import '../connectivity/connectivity.dart';

/// Error with a retry button (`03 §4`). [error] is mapped through jivo_core;
/// raw exception text is never shown. With [retryOnReconnect] (the
/// default) it also retries once by itself each time the connection comes
/// back (`03 §2.1`, CA-02).
class ErrorRetryView extends ConsumerWidget {
  const ErrorRetryView({
    required this.error,
    required this.onRetry,
    this.retryOnReconnect = true,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry;
  final bool retryOnReconnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (retryOnReconnect) {
      ref.listen(reconnectProvider, (previous, next) {
        if (previous != next) onRetry();
      });
    }
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
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Red (`danger.fg` / `danger.on`, 6.46:1) for an action that can't be
  /// undone, such as cancelling an order (CA-28).
  final bool destructive;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: destructive
          ? FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            )
          : null,
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

/// A reload failed while the earlier content stays on screen (CA-03):
/// [next] is an error that still holds the last data, right after a load.
bool isFailedRefresh(AsyncValue<Object?>? previous, AsyncValue<Object?> next) =>
    next is AsyncError &&
    next.hasValue &&
    !next.isLoading &&
    (previous?.isLoading ?? false);

/// For `RefreshIndicator.onRefresh`: waits for [reload] and swallows its
/// error, which the screen already shows (snackbar or error state). Without
/// this, a failed pull-to-refresh is an uncaught async error.
Future<void> refreshQuietly(Future<Object?> reload) async {
  try {
    await reload;
  } catch (_) {
    // Shown by the screen.
  }
}

/// "Couldn't refresh. Check your connection." with Retry (CA-03): the
/// content on screen stays, instead of a full-screen error.
void showRefreshFailed(BuildContext context, VoidCallback onRetry) {
  final l10n = AppLocalizations.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const Key('refresh-failed'),
        content: Text(l10n.refreshFailed),
        action: SnackBarAction(label: l10n.retry, onPressed: onRetry),
      ),
    );
}

/// Shows [message] in a snackbar.
void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
