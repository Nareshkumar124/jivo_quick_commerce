import 'package:jivo_core/jivo_core.dart';

/// Dev configuration with the defaults (no `--dart-define` in tests).
final testEnv = AppEnv.resolve(flavor: Flavor.dev);

const testClientInfo = ClientInfo(
  appName: 'customer',
  appVersion: '1.0.0',
  buildNumber: '1',
  platform: 'android',
);
