import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/domain/location_point.dart';

void main() {
  group('LocationPoint', () {
    test('recorded_at is serialised as UTC ISO-8601 with a Z suffix', () {
      final point = LocationPoint(
        lat: 28.61,
        lng: 77.21,
        accuracy: 4.5,
        speed: 6.2,
        heading: 90,
        recordedAt: DateTime.utc(2026, 11, 2, 10, 15, 30, 250),
      );

      final json = point.toJson();

      expect(json['recorded_at'], '2026-11-02T10:15:30.250Z');
      expect(json, {
        'lat': 28.61,
        'lng': 77.21,
        'accuracy': 4.5,
        'speed': 6.2,
        'heading': 90.0,
        'recorded_at': '2026-11-02T10:15:30.250Z',
      });
    });

    test('a local recorded time is converted to UTC', () {
      final local = DateTime(2026, 11, 2, 15, 45);
      final point = LocationPoint(lat: 1, lng: 2, recordedAt: local);

      expect(point.recordedAt.isUtc, isTrue);
      expect(point.recordedAt, local.toUtc());
      expect(point.toJson()['recorded_at'], endsWith('Z'));
    });

    test('round-trips through JSON, including null optional fields', () {
      final point = LocationPoint(
        lat: 28.61,
        lng: 77.21,
        recordedAt: DateTime.utc(2026, 11, 2),
      );

      expect(LocationPoint.fromJson(point.toJson()), point);
    });
  });
}
