import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show AppConfig;
import 'package:rider_app/features/launch/data/fake_app_config_repository.dart';
import 'package:rider_app/features/launch/domain/app_version.dart';
import 'package:rider_app/features/launch/domain/launch_gate.dart';

AppConfig config({
  String? min = '1.0.0',
  String? latest = '1.0.0',
  String? storeUrl =
      'https://play.google.com/store/apps/details?id=in.jivo.rider',
  bool maintenance = false,
  String message = '',
}) {
  final json = FakeAppConfigRepository.exampleJson(FakeConfigScenario.normal)
    ..['min_supported_version'] = min
    ..['latest_version'] = latest
    ..['store_url'] = storeUrl
    ..['maintenance'] = maintenance
    ..['maintenance_message'] = message;
  return AppConfig.fromJson(json);
}

void main() {
  group('compareVersions', () {
    test('numeric, part by part', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.0.0', '1.2.0'), lessThan(0));
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
    });

    test('missing parts count as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1', '1.0.1'), lessThan(0));
    });

    test('pre-release and build suffixes are ignored', () {
      expect(compareVersions('1.2.0-beta+3', '1.2.0'), 0);
      expect(compareVersions('1.0.0+7', '1.0.1'), lessThan(0));
    });
  });

  group('launchGateFor', () {
    test('proceeds when the app is up to date', () {
      expect(
        launchGateFor(config(), appVersion: '1.0.0'),
        isA<LaunchProceed>(),
      );
    });

    test('null versions (server could not identify the app) never force an '
        'update', () {
      expect(
        launchGateFor(config(min: null, latest: null), appVersion: '0.0.1'),
        isA<LaunchProceed>(),
      );
    });

    test('below min_supported_version: forced update', () {
      final gate = launchGateFor(config(min: '1.2.0'), appVersion: '1.0.0');
      expect(gate, isA<LaunchUpdate>().having((g) => g.forced, 'forced', true));
      expect(gate.blocksApp, isTrue);
    });

    test('equal to min_supported_version is not forced', () {
      expect(
        launchGateFor(
          config(min: '1.0.0', latest: '1.0.0'),
          appVersion: '1.0.0',
        ),
        isA<LaunchProceed>(),
      );
    });

    test('below latest_version only: dismissible prompt, unless dismissed', () {
      final gate = launchGateFor(config(latest: '1.2.0'), appVersion: '1.0.0');
      expect(
        gate,
        isA<LaunchUpdate>().having((g) => g.forced, 'forced', false),
      );
      expect(gate.blocksApp, isFalse);

      expect(
        launchGateFor(
          config(latest: '1.2.0'),
          appVersion: '1.0.0',
          softUpdateDismissed: true,
        ),
        isA<LaunchProceed>(),
      );
    });

    test('maintenance blocks with the server message', () {
      final gate = launchGateFor(
        config(maintenance: true, message: 'Back at 6 AM'),
        appVersion: '1.0.0',
      );
      expect(
        gate,
        isA<LaunchMaintenance>().having(
          (g) => g.message,
          'message',
          'Back at 6 AM',
        ),
      );
    });

    test('a forced update outranks maintenance', () {
      final gate = launchGateFor(
        config(min: '2.0.0', maintenance: true),
        appVersion: '1.0.0',
      );
      expect(gate, isA<LaunchUpdate>().having((g) => g.forced, 'forced', true));
    });

    test('a missing or invalid store_url falls back to the rider listing', () {
      final gate = launchGateFor(
        config(min: '2.0.0', storeUrl: null),
        appVersion: '1.0.0',
      ) as LaunchUpdate;
      expect(gate.storeUrl, fallbackStoreUrl);
      expect(fallbackStoreUrl.queryParameters['id'], 'in.jivo.rider');
      expect(storeUriOf('not a url'), fallbackStoreUrl);
    });
  });
}
