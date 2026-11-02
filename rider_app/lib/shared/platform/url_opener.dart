import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in another app (browser, Play Store). Behind an interface so
/// widget tests can run without the url_launcher platform channel.
abstract interface class UrlOpener {
  /// Returns false if no app could open [uri].
  Future<bool> open(Uri uri);
}

class ExternalUrlOpener implements UrlOpener {
  const ExternalUrlOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (error) {
      debugPrint('ExternalUrlOpener: cannot open $uri: $error');
      return false;
    }
  }
}
