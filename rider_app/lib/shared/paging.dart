/// One page of a paginated list (02 §5: `{count, next, previous, results}`).
class Page<T> {
  const Page({required this.items, this.nextPage, this.count});

  final List<T> items;

  /// The cursor to ask for next, or null on the last page: the page number
  /// for page-numbered lists (payouts), the `before_id` for the stable
  /// lists (cash ledger, task history; api-requests #24).
  final int? nextPage;
  final int? count;

  bool get hasMore => nextPage != null;
}

/// The `page` query parameter of a DRF `next` link (page-numbered lists).
int? pageOfNext(String? next) => _intQuery(next, 'page');

/// The `before_id` query parameter of a `next` link (stable lists).
int? beforeIdOfNext(String? next) => _intQuery(next, 'before_id');

int? _intQuery(String? link, String name) {
  if (link == null || link.isEmpty) return null;
  final value = Uri.tryParse(link)?.queryParameters[name];
  return value == null ? null : int.tryParse(value);
}
