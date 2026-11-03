import 'package:flutter/foundation.dart';
import 'package:jivo_api/jivo_api.dart' show AppConfig;
import 'package:jivo_core/jivo_core.dart' show isVersionBelow;

/// What the app must show before anything else, decided from
/// `GET /api/v1/config/app/` (04 §2.1 "Force update / maintenance") or from a
/// 426 / 503 on any later call.
sealed class LaunchGate {
  const LaunchGate();

  /// Whether the rider can use the app (login, home) behind this gate.
  bool get blocksApp;
}

/// Nothing to show: continue to login or home.
final class LaunchProceed extends LaunchGate {
  const LaunchProceed();

  @override
  bool get blocksApp => false;
}

/// Maintenance mode. [message] is the server's `maintenance_message`; empty
/// means "show the generic text".
final class LaunchMaintenance extends LaunchGate {
  const LaunchMaintenance(this.message);

  final String message;

  @override
  bool get blocksApp => true;
}

/// An update is available ([forced] false: dismissible prompt) or required
/// ([forced] true: blocking screen).
@immutable
final class LaunchUpdate extends LaunchGate {
  const LaunchUpdate({required this.forced, required this.storeUrl});

  final bool forced;
  final Uri storeUrl;

  @override
  bool get blocksApp => forced;

  @override
  bool operator ==(Object other) =>
      other is LaunchUpdate &&
      other.forced == forced &&
      other.storeUrl == storeUrl;

  @override
  int get hashCode => Object.hash(forced, storeUrl);
}

/// The rider app's Play listing, used when the server sends no `store_url`.
final fallbackStoreUrl = Uri.parse(
  'https://play.google.com/store/apps/details?id=in.jivo.rider',
);

/// Decides the gate for [config] and the installed [appVersion].
///
/// Order: force update (below `min_supported_version`; it outranks
/// maintenance, as in jivo_core's `AppControlSignals`), then maintenance,
/// then the optional update prompt (below `latest_version`, unless the rider
/// already chose "Later" this session). Null versions (the server could not
/// identify the app) never trigger an update.
LaunchGate launchGateFor(
  AppConfig config, {
  required String appVersion,
  bool softUpdateDismissed = false,
}) {
  final storeUrl = storeUriOf(config.storeUrl);
  if (isVersionBelow(appVersion, config.minSupportedVersion)) {
    return LaunchUpdate(forced: true, storeUrl: storeUrl);
  }
  if (config.maintenance) return LaunchMaintenance(config.maintenanceMessage);

  if (!softUpdateDismissed &&
      isVersionBelow(appVersion, config.latestVersion)) {
    return LaunchUpdate(forced: false, storeUrl: storeUrl);
  }
  return const LaunchProceed();
}

/// Parses a server store URL, falling back to [fallbackStoreUrl].
Uri storeUriOf(Object? raw) {
  final uri = raw is String ? Uri.tryParse(raw.trim()) : null;
  final valid = uri != null && uri.hasScheme && uri.host.isNotEmpty;
  return valid ? uri : fallbackStoreUrl;
}
