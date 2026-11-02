import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Identifies the calling app on every request (`02 §5`, client info).
///
/// The backend uses these headers for force-update checks and analytics.
@immutable
class ClientInfo {
  const ClientInfo({
    required this.appName,
    required this.appVersion,
    required this.platform,
    this.buildNumber = '',
  });

  /// Reads the version from the installed app and the platform from
  /// [defaultTargetPlatform].
  ///
  /// [appName] is `customer` or `rider`.
  static Future<ClientInfo> fromPlatform({required String appName}) async {
    final info = await PackageInfo.fromPlatform();
    return ClientInfo(
      appName: appName,
      appVersion: info.version,
      buildNumber: info.buildNumber,
      platform: platformName(defaultTargetPlatform),
    );
  }

  static const appNameHeader = 'X-App-Name';
  static const appVersionHeader = 'X-App-Version';
  static const platformHeader = 'X-Platform';

  /// `customer` or `rider`.
  final String appName;

  /// The marketing version without the build number, e.g. `1.0.0`.
  final String appVersion;

  /// The build number, e.g. `1`. Not sent as a header.
  final String buildNumber;

  /// `android` or `ios`.
  final String platform;

  /// The headers sent with every request.
  Map<String, String> get headers => {
    appNameHeader: appName,
    appVersionHeader: appVersion,
    platformHeader: platform,
  };

  /// The release name reported to Sentry, e.g. `jivo-customer@1.0.0+1`.
  String get release =>
      'jivo-$appName@$appVersion${buildNumber.isEmpty ? '' : '+$buildNumber'}';

  /// The `X-Platform` value for [platform].
  static String platformName(TargetPlatform platform) => switch (platform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => platform.name.toLowerCase(),
  };

  @override
  bool operator ==(Object other) =>
      other is ClientInfo &&
      other.appName == appName &&
      other.appVersion == appVersion &&
      other.buildNumber == buildNumber &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(appName, appVersion, buildNumber, platform);

  @override
  String toString() =>
      'ClientInfo($appName $appVersion+$buildNumber, $platform)';
}
