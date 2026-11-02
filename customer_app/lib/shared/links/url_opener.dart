import 'package:url_launcher/url_launcher.dart';

/// Opens policy pages and the store listing outside the app.
abstract interface class UrlOpener {
  /// Returns false when nothing could open [url].
  Future<bool> open(Uri url);
}

class LaunchUrlOpener implements UrlOpener {
  const LaunchUrlOpener();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

/// For tests: records the URLs.
class FakeUrlOpener implements UrlOpener {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}
