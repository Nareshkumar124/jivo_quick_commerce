import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/auth/presentation/rider_account_controller.dart';
import 'paging.dart';

/// A paginated list on screen: what is loaded, whether more pages exist, and
/// the last error. [header] is extra data some lists carry on their first
/// page (e.g. the cash summary).
@immutable
class PagedListState<T, H> {
  const PagedListState({
    this.items = const [],
    this.header,
    this.nextPage,
    this.loading = false,
    this.loaded = false,
    this.error,
  });

  final List<T> items;
  final H? header;

  /// The cursor of the next page (see `Page.nextPage`), or null.
  final int? nextPage;
  final bool loading;

  /// The first page arrived at least once.
  final bool loaded;
  final ApiError? error;

  bool get hasMore => nextPage != null;
}

/// Loads a paged list: the first page on start, the next one on "Load
/// more", the first again on refresh.
///
/// - "Load more" waits for any load in flight; a refresh never waits: it
///   supersedes whatever is in flight, whose late answer is dropped.
/// - Page-number paging shifts when new rows arrive between two pages (a
///   delivery adds a ledger entry), so a row can come back on the next
///   page. With [keyOf], rows already listed are skipped.
/// - The header is the latest page's, on purpose: the cash summary shown
///   is the freshest the server sent, and a page without a header keeps
///   the one already shown.
class PagedListNotifier<T, H> extends Notifier<PagedListState<T, H>> {
  PagedListNotifier(this._fetch, {this._keyOf});

  /// Fetches a page: [cursor] is null for the first one, then the
  /// previous page's `nextPage` (a page number or a `before_id`).
  final Future<(Page<T>, H?)> Function(Ref ref, int? cursor) _fetch;
  final Object Function(T item)? _keyOf;

  /// Bumped by every load; an answer for an older one is dropped.
  int _generation = 0;

  @override
  PagedListState<T, H> build() {
    Future.microtask(refresh);
    return PagedListState<T, H>(loading: true);
  }

  /// Reloads from the first page, keeping the list on screen meanwhile.
  Future<void> refresh() => _load(null, replace: true);

  Future<void> loadMore() async {
    final next = state.nextPage;
    if (next == null || state.loading) return;
    await _load(next, replace: false);
  }

  Future<void> _load(int? cursor, {required bool replace}) async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    state = PagedListState(
      items: state.items,
      header: state.header,
      nextPage: state.nextPage,
      loading: true,
      loaded: state.loaded,
    );
    try {
      final (result, header) = await _fetch(ref, cursor);
      if (!ref.mounted || generation != _generation) return;
      state = PagedListState(
        items: replace ? result.items : _append(state.items, result.items),
        header: header ?? state.header,
        nextPage: result.nextPage,
        loaded: true,
      );
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted || generation != _generation) return;
      reportAppControlError(ref, error);
      state = PagedListState(
        items: state.items,
        header: state.header,
        nextPage: state.nextPage,
        loaded: state.loaded,
        error: error,
      );
    }
  }

  List<T> _append(List<T> current, List<T> more) {
    final keyOf = _keyOf;
    if (keyOf == null) return [...current, ...more];
    final seen = {for (final item in current) keyOf(item)};
    return [
      ...current,
      for (final item in more)
        if (seen.add(keyOf(item))) item,
    ];
  }
}
