import 'package:flutter/foundation.dart';
import 'package:jivo_core/helpers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in another app (browser, Play Store, maps, dialer) with
/// url_launcher. The [UrlOpener] interface and its test double
/// (`FakeUrlOpener`) live in jivo_core.
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
