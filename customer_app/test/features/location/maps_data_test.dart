import 'package:customer_app/features/location/data/maps_availability.dart';
import 'package:customer_app/features/location/data/reverse_geocoder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' show Placemark;

const _point = (lat: 28.4595, lng: 77.0266);
const _channel = MethodChannel('in.jivo.quick/maps');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformReverseGeocoder', () {
    test('maps placemark fields to address parts', () async {
      final geocoder = PlatformReverseGeocoder(
        lookup: (_) async => const [
          Placemark(
            street: 'Plot 12, Sector 14',
            subLocality: 'Sector 14',
            locality: 'Gurugram',
            subAdministrativeArea: 'Gurgaon',
            administrativeArea: 'Haryana',
            postalCode: '122001',
          ),
        ],
      );
      final parts = (await geocoder.partsAt(_point))!;
      expect(parts.line, 'Plot 12, Sector 14, Gurugram, Haryana, 122001');
      expect(parts.area, 'Sector 14');
      expect(parts.city, 'Gurugram');
      expect(parts.state, 'Haryana');
      expect(parts.pincode, '122001');
      expect(
        await geocoder.addressAt(_point),
        'Plot 12, Sector 14, Gurugram, Haryana, 122001',
      );
    });

    test('falls back: area to locality, city to district', () async {
      final parts = PlatformReverseGeocoder.partsOf(
        const Placemark(
          name: '12',
          locality: ' ',
          subAdministrativeArea: 'Gurgaon',
          administrativeArea: 'Haryana',
        ),
      );
      expect(parts.area, isNull);
      expect(parts.city, 'Gurgaon');
      expect(parts.line, '12, Haryana');

      final withLocality = PlatformReverseGeocoder.partsOf(
        const Placemark(locality: 'Gurugram'),
      );
      expect(withLocality.area, 'Gurugram');
      expect(withLocality.city, 'Gurugram');
    });

    test('an Android full-address street is not repeated', () {
      expect(
        PlatformReverseGeocoder.addressLine(
          const Placemark(
            street: 'Sector 14, Gurugram, Haryana 122001, India',
            subLocality: 'Sector 14',
            locality: 'Gurugram',
            administrativeArea: 'Haryana',
            postalCode: '122001',
          ),
        ),
        'Sector 14, Gurugram, Haryana 122001, India',
      );
    });

    test('returns null on no result or failure, never throws', () async {
      final empty = PlatformReverseGeocoder(lookup: (_) async => const []);
      expect(await empty.addressAt(_point), isNull);
      expect(await empty.partsAt(_point), isNull);

      final failing = PlatformReverseGeocoder(
        lookup: (_) async => throw PlatformException(code: 'IO_ERROR'),
      );
      expect(await failing.addressAt(_point), isNull);
      expect(await failing.partsAt(_point), isNull);

      expect(PlatformReverseGeocoder.addressLine(const Placemark()), isNull);
    });
  });

  group('PlatformMapsAvailability', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(_channel, null);
    });

    test('reports the key the build injected', () async {
      messenger.setMockMethodCallHandler(_channel, (call) async {
        expect(call.method, 'prepare');
        return true;
      });
      expect(await const PlatformMapsAvailability().isAvailable(), isTrue);
    });

    test('no key: unavailable, so screens use the fallback', () async {
      messenger.setMockMethodCallHandler(_channel, (_) async => false);
      expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
    });

    test('a channel failure is unavailable, not a crash', () async {
      messenger.setMockMethodCallHandler(
        _channel,
        (_) async => throw PlatformException(code: 'boom'),
      );
      expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
      messenger.setMockMethodCallHandler(_channel, null);
      expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      group(platform.name, () {
        setUp(() => debugDefaultTargetPlatformOverride = platform);

        test('asks the channel: key provided', () async {
          final calls = <String>[];
          messenger.setMockMethodCallHandler(_channel, (call) async {
            calls.add(call.method);
            return true;
          });
          expect(await const PlatformMapsAvailability().isAvailable(), isTrue);
          expect(calls, ['prepare']);
        });

        test('asks the channel: no key', () async {
          messenger.setMockMethodCallHandler(_channel, (_) async => false);
          expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
        });

        test('a null reply is unavailable', () async {
          messenger.setMockMethodCallHandler(_channel, (_) async => null);
          expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
        });

        test('a channel error or missing handler is unavailable', () async {
          messenger.setMockMethodCallHandler(
            _channel,
            (_) async => throw PlatformException(code: 'boom'),
          );
          expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
          messenger.setMockMethodCallHandler(_channel, null);
          expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
        });
      });
    }

    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      test(
        '${platform.name} never asks the channel and is unavailable',
        () async {
          debugDefaultTargetPlatformOverride = platform;
          var asked = false;
          messenger.setMockMethodCallHandler(_channel, (_) async {
            asked = true;
            return true;
          });
          expect(await const PlatformMapsAvailability().isAvailable(), isFalse);
          expect(asked, isFalse);
        },
      );
    }
  });
}
