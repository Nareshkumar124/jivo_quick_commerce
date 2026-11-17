import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/permissions/domain/permission_gate.dart';
import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';

import '../../../helpers/permission_fixtures.dart';

// Device test 2026-11-17 (realme RMX5056, Android 15): the checklist said
// "Location access: Done" while the location app-ops were `ignore`. The
// live grant reads the runtime permission and the app-op together.
void main() {
  group('LocationOpMode.fromWire', () {
    test('maps the channel strings', () {
      expect(LocationOpMode.fromWire('allowed'), LocationOpMode.allowed);
      expect(LocationOpMode.fromWire('foreground'), LocationOpMode.foreground);
      expect(LocationOpMode.fromWire('ignored'), LocationOpMode.denied);
      expect(LocationOpMode.fromWire('errored'), LocationOpMode.denied);
      expect(LocationOpMode.fromWire('default'), LocationOpMode.unknown);
      expect(LocationOpMode.fromWire(null), LocationOpMode.unknown);
    });
  });

  group('liveLocationGrant', () {
    test('a permission that is not granted stays as it is', () {
      for (final op in LocationOpMode.values) {
        for (final background in [false, true]) {
          expect(
            liveLocationGrant(Grant.denied, op, background: background),
            Grant.denied,
          );
          expect(
            liveLocationGrant(Grant.blocked, op, background: background),
            Grant.blocked,
          );
        }
      }
    });

    test('granted but the op is ignored: blocked (settings only)', () {
      expect(
        liveLocationGrant(
          Grant.granted,
          LocationOpMode.denied,
          background: false,
        ),
        Grant.blocked,
      );
      expect(
        liveLocationGrant(
          Grant.granted,
          LocationOpMode.denied,
          background: true,
        ),
        Grant.blocked,
      );
    });

    // Review: "all the time" granted but the op only foreground: a request
    // would return at once, so the gate must open the app settings.
    test('while-in-use only: fine for the foreground; "all the time" is '
        'blocked (settings page)', () {
      expect(
        liveLocationGrant(
          Grant.granted,
          LocationOpMode.foreground,
          background: false,
        ),
        Grant.granted,
      );
      expect(
        liveLocationGrant(
          Grant.granted,
          LocationOpMode.foreground,
          background: true,
        ),
        Grant.blocked,
      );
    });

    test('allowed, or an op that cannot be read: the permission decides', () {
      for (final op in [LocationOpMode.allowed, LocationOpMode.unknown]) {
        expect(
          liveLocationGrant(Grant.granted, op, background: true),
          Grant.granted,
        );
      }
    });

    test('the gate then shows location as needed, not "Done"', () {
      final live = allGranted.copyWith(
        locationWhenInUse: liveLocationGrant(
          Grant.granted,
          LocationOpMode.denied,
          background: false,
        ),
        locationAlways: liveLocationGrant(
          Grant.granted,
          LocationOpMode.denied,
          background: true,
        ),
      );
      final gate = PermissionGate.evaluate(live, disclosureAccepted: true);
      final location = gate.items.firstWhere(
        (i) => i.step == GateStep.locationWhenInUse,
      );
      expect(location.done, isFalse);
      expect(location.blocked, isTrue);
      expect(gate.canGoOnline, isFalse);
    });
  });

  test('the gate then opens the app settings for "all the time"', () {
    final live = allGranted.copyWith(
      locationAlways: liveLocationGrant(
        Grant.granted,
        LocationOpMode.foreground,
        background: true,
      ),
    );
    final next = PermissionGate.evaluate(live, disclosureAccepted: true).next!;
    expect(next.step, GateStep.locationAlways);
    expect(next.blocked, isTrue);
  });
}
