import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../errors/rider_error_text.dart';
import '../paged_list_controller.dart';
import 'error_line.dart';

/// A paginated list: skeleton rows until the first page, an error with
/// Retry, an empty state, then the items with "Load more" at the end.
/// [header] goes above the items (summaries, banners).
///
/// UX audit RA-18: the first load shows three static skeleton cards (no
/// shimmer: it is heavy on budget phones); the empty state has a 48 dp
/// [emptyIcon], the text and an optional [emptyAction]; a failed "Load
/// more" is an [ErrorLine] (icon, danger colour, live region).
class PagedListView<T, H> extends StatelessWidget {
  const PagedListView({
    required this.state,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
    required this.emptyText,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.header = const [],
    super.key,
  });

  final PagedListState<T, H> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final String emptyText;
  final IconData emptyIcon;

  /// One next step for an empty list (tickets: "Raise a ticket").
  final Widget? emptyAction;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = state.error;
    if (!state.loaded) {
      if (error == null) return const _SkeletonList();
      return _ErrorRetry(error: error, onRetry: onRefresh);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('paged-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ...header,
          if (state.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    emptyIcon,
                    key: const Key('paged-empty-icon'),
                    size: 48,
                    color: RiderColors.of(context).textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyText,
                    key: const Key('paged-empty'),
                    textAlign: TextAlign.center,
                  ),
                  if (emptyAction case final action?) ...[
                    const SizedBox(height: 16),
                    action,
                  ],
                ],
              ),
            ),
          for (final item in state.items) itemBuilder(context, item),
          if (error != null) ...[
            const SizedBox(height: 8),
            ErrorLine(
              riderApiErrorMessage(context, error),
              textKey: const Key('paged-error'),
            ),
          ],
          if (state.hasMore || error != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('paged-more'),
              onPressed: state.loading
                  ? null
                  : (state.hasMore ? onLoadMore : onRefresh),
              child: state.loading
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(state.hasMore ? l10n.listLoadMore : l10n.retry),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three grey cards the size of a list row, while the first page loads.
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final color = RiderColors.of(context).neutralContainer;
    return Semantics(
      label: AppLocalizations.of(context).listLoading,
      child: ListView(
        key: const Key('paged-loading'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 88,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.error, required this.onRetry});

  final ApiError error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 64),
          const SizedBox(height: 16),
          Text(
            riderApiErrorMessage(context, error),
            key: const Key('paged-error'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('paged-retry'),
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    ),
  );
}
