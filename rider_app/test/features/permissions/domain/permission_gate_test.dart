import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/permissions/domain/permission_gate.dart';
import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';

import '../../../helpers/permission_fixtures.dart';

GateStep? nextStep(PermissionSnapshot s, {bool disclosure = false}) =>
    PermissionGate.evaluate(s, disclosureAccepted: disclosure).next?.step;

void main() {
  group('PermissionGate', () {
    test('passes when everything is granted', () {
      final result = PermissionGate.evaluate(
        allGranted,
        disclosureAccepted: false,
      );

      expect(result.canGoOnline, isTrue);
      expect(result.next, isNull);
      expect(result.items.every((i) => i.done), isTrue);
    });

    test('a fresh install starts with the prominent disclosure', () {
      final result = PermissionGate.evaluate(
        freshInstall,
        disclosureAccepted: false,
      );

      expect(result.canGoOnline, isFalse);
      expect(result.next!.step, GateStep.disclosure);
    });

    test('walks the steps in the 04 §2.1 order', () {
      final steps = <GateStep?>[];
      var s = freshInstall;
      steps.add(nextStep(s));
      steps.add(nextStep(s, disclosure: true));
      s = s.copyWith(locationWhenInUse: Grant.granted);
      steps.add(nextStep(s, disclosure: true));
      s = s.copyWith(locationAlways: Grant.granted);
      steps.add(nextStep(s, disclosure: true));
      s = s.copyWith(notifications: Grant.granted);
      steps.add(nextStep(s, disclosure: true));
      s = s.copyWith(batteryOptimisationIgnored: true);
      steps.add(nextStep(s, disclosure: true));
      s = s.copyWith(gpsEnabled: true);
      steps.add(nextStep(s, disclosure: true));

      expect(steps, [
        GateStep.disclosure,
        GateStep.locationWhenInUse,
        GateStep.locationAlways,
        GateStep.notifications,
        GateStep.batteryOptimisation,
        GateStep.gps,
        null,
      ]);
    });

    test('the disclosure comes before the background request even when '
        'while-in-use location was granted elsewhere', () {
      final s = freshInstall.copyWith(locationWhenInUse: Grant.granted);

      expect(nextStep(s), GateStep.disclosure);
      expect(nextStep(s, disclosure: true), GateStep.locationAlways);
    });

    test('the disclosure is not shown again once background location is '
        'granted', () {
      expect(nextStep(allGranted), isNull);
    });

    test('notifications are not required below Android 13 (API 33)', () {
      final s = allGranted.copyWith(sdkInt: 32, notifications: Grant.denied);
      expect(nextStep(s), isNull);
    });

    test('notifications are required on Android 13+', () {
      final s = allGranted.copyWith(sdkInt: 33, notifications: Grant.denied);
      expect(nextStep(s), GateStep.notifications);
    });

    test('below Android 10 (API 29) background location comes with '
        'while-in-use', () {
      final s = allGranted.copyWith(sdkInt: 28, locationAlways: Grant.denied);
      expect(nextStep(s), isNull);
    });

    test('battery exemption and GPS are both blocking', () {
      expect(
        nextStep(allGranted.copyWith(batteryOptimisationIgnored: false)),
        GateStep.batteryOptimisation,
      );
      expect(nextStep(allGranted.copyWith(gpsEnabled: false)), GateStep.gps);
    });

    test('permanently denied items are flagged for the settings page', () {
      final s = freshInstall.copyWith(locationWhenInUse: Grant.blocked);
      final next = PermissionGate.evaluate(s, disclosureAccepted: true).next!;

      expect(next.step, GateStep.locationWhenInUse);
      expect(next.blocked, isTrue);
    });

    test('a missing full-screen-intent permission is advisory on Android '
        '14+ only and never blocks going online', () {
      final s34 = allGranted.copyWith(fullScreenIntentAllowed: false);
      final r34 = PermissionGate.evaluate(s34, disclosureAccepted: false);
      expect(r34.fullScreenIntentMissing, isTrue);
      expect(r34.canGoOnline, isTrue);

      final s33 = s34.copyWith(sdkInt: 33);
      expect(
        PermissionGate.evaluate(
          s33,
          disclosureAccepted: false,
        ).fullScreenIntentMissing,
        isFalse,
      );
    });

    test('"Approximate" keeps the location step open (04 §2.1)', () {
      final approximate = allGranted.copyWith(locationPrecise: false);
      final result = PermissionGate.evaluate(
        approximate,
        disclosureAccepted: true,
      );
      expect(result.canGoOnline, isFalse);
      expect(result.next!.step, GateStep.locationWhenInUse);
      expect(result.next!.approximate, isTrue);
      expect(result.next!.blocked, isFalse);
    });

    test('OEM auto-start guidance is offered for aggressive OEMs only', () {
      expect(PermissionGate.oemBrandOf('Xiaomi'), OemBrand.xiaomi);
      expect(PermissionGate.oemBrandOf('Redmi'), OemBrand.xiaomi);
      expect(PermissionGate.oemBrandOf('POCO'), OemBrand.xiaomi);
      expect(PermissionGate.oemBrandOf('OPPO'), OemBrand.oppo);
      expect(PermissionGate.oemBrandOf('vivo'), OemBrand.vivo);
      expect(PermissionGate.oemBrandOf('iQOO'), OemBrand.vivo);
      expect(PermissionGate.oemBrandOf('realme'), OemBrand.realme);
      expect(PermissionGate.oemBrandOf('OnePlus'), OemBrand.oneplus);
      expect(PermissionGate.oemBrandOf('samsung'), isNull);
      expect(PermissionGate.oemBrandOf('Google'), isNull);

      final xiaomi = allGranted.copyWith(manufacturer: 'Xiaomi');
      final result = PermissionGate.evaluate(xiaomi, disclosureAccepted: false);
      expect(result.oemBrand, OemBrand.xiaomi);
      expect(result.canGoOnline, isTrue, reason: 'guidance is not blocking');
    });
  });
}
