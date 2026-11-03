/// One page of a paginated list (02 §5: `{count, next, previous, results}`).
class Page<T> {
  const Page({required this.items, this.nextPage, this.count});

  final List<T> items;

  /// The page number to ask for next, or null on the last page.
  final int? nextPage;
  final int? count;

  bool get hasMore => nextPage != null;
}
