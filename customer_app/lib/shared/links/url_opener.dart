import 'package:jivo_core/helpers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens policy pages and the store listing outside the app. The
/// [UrlOpener] interface and its test double live in jivo_core.
class LaunchUrlOpener implements UrlOpener {
  const LaunchUrlOpener();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
