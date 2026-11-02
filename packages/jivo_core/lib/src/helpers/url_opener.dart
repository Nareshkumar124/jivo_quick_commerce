/// Opens a link in another app (browser, Play Store, dialer). Behind an
/// interface so widget tests run without the url_launcher platform channel.
///
/// The apps implement it with url_launcher (`LaunchMode.externalApplication`).
abstract interface class UrlOpener {
  /// Returns false when no app could open [uri]. Never throws.
  Future<bool> open(Uri uri);
}

/// For tests: records every URL and reports [result].
class FakeUrlOpener implements UrlOpener {
  FakeUrlOpener({this.result = true});

  /// What [open] returns.
  bool result;

  /// The URLs passed to [open], in order.
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}
