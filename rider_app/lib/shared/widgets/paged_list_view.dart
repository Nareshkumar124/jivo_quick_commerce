import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../l10n/app_localizations.dart';
import '../paged_list_controller.dart';
import '../errors/rider_error_text.dart';

/// A paginated list: a spinner until the first page, an error with Retry,
/// an empty message, then the items with "Load more" at the end. [header]
/// goes above the items (summaries, banners).
class PagedListView<T, H> extends StatelessWidget {
  const PagedListView({
    required this.state,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
    required this.emptyText,
    this.header = const [],
    super.key,
  });

  final PagedListState<T, H> state;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final String emptyText;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = state.error;
    if (!state.loaded) {
      if (error == null) {
        return const Center(child: CircularProgressIndicator());
      }
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
              child: Text(
                emptyText,
                key: const Key('paged-empty'),
                textAlign: TextAlign.center,
              ),
            ),
          for (final item in state.items) itemBuilder(context, item),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              riderApiErrorMessage(context, error),
              key: const Key('paged-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
