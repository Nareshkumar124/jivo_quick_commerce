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
  final int? nextPage;
  final bool loading;

  /// The first page arrived at least once.
  final bool loaded;
  final ApiError? error;

  bool get hasMore => nextPage != null;
}

/// Loads a paged list: the first page on start, the next one on "Load
/// more", the first again on refresh. One request at a time.
class PagedListNotifier<T, H> extends Notifier<PagedListState<T, H>> {
  PagedListNotifier(this._fetch);

  final Future<(Page<T>, H?)> Function(Ref ref, int page) _fetch;

  @override
  PagedListState<T, H> build() {
    Future.microtask(refresh);
    return PagedListState<T, H>(loading: true);
  }

  /// Reloads from the first page, keeping the list on screen meanwhile.
  Future<void> refresh() => _load(1, replace: true);

  Future<void> loadMore() async {
    final next = state.nextPage;
    if (next == null || state.loading) return;
    await _load(next, replace: false);
  }

  Future<void> _load(int page, {required bool replace}) async {
    if (state.loading && state.loaded) return;
    state = PagedListState(
      items: state.items,
      header: state.header,
      nextPage: state.nextPage,
      loading: true,
      loaded: state.loaded,
    );
    try {
      final (result, header) = await _fetch(ref, page);
      if (!ref.mounted) return;
      state = PagedListState(
        items: replace ? result.items : [...state.items, ...result.items],
        header: header ?? state.header,
        nextPage: result.nextPage,
        loaded: true,
      );
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return;
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
}
