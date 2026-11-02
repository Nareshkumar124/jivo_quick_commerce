import 'package:flutter/foundation.dart';

import 'permission_snapshot.dart';

/// Blocking steps of the permissions gate, in the order the rider is taken
/// through them (`docs/04-rider-app.md` §2.1). All must be done before the
/// rider can go online.
enum GateStep {
  /// In-app prominent disclosure (Play policy). Must be accepted before the
  /// app asks for location, and in particular before "Allow all the time".
  disclosure,
  locationWhenInUse,
  locationAlways,
  notifications,
  batteryOptimisation,
  gps,
}

/// OEMs whose battery managers kill background services unless the rider
/// enables auto-start / "no restrictions" by hand (04 §3).
enum OemBrand { xiaomi, oppo, vivo, realme, oneplus }

@immutable
class GateItem {
  const GateItem(this.step, {required this.done, this.blocked = false});

  final GateStep step;
  final bool done;

  /// Only the system settings page can fix this step (permanently denied).
  final bool blocked;
}

@immutable
class GateEvaluation {
  const GateEvaluation({
    required this.items,
    required this.fullScreenIntentMissing,
    required this.oemBrand,
  });

  /// Every blocking step, in order.
  final List<GateItem> items;

  /// Advisory: Android 14+ without USE_FULL_SCREEN_INTENT. Offers then arrive
  /// as heads-up notifications instead of full screen. Does not block going
  /// online (see the spike report).
  final bool fullScreenIntentMissing;

  /// Advisory: show auto-start guidance for this OEM. Null for other brands.
  final OemBrand? oemBrand;

  /// The first step still to do, or null when the gate passes.
  GateItem? get next {
    for (final item in items) {
      if (!item.done) return item;
    }
    return null;
  }

  bool get canGoOnline => next == null;
}

/// Pure decision logic of the permissions gate. The platform reads go into a
/// [PermissionSnapshot]; this decides what is missing and what comes next.
abstract final class PermissionGate {
  /// Android 10 (API 29) split background location into its own permission.
  static const backgroundLocationSdk = 29;

  /// Android 13 (API 33) made notifications a runtime permission.
  static const notificationPermissionSdk = 33;

  /// Android 14 (API 34) restricted full-screen intents.
  static const fullScreenIntentSdk = 34;

  static GateEvaluation evaluate(
    PermissionSnapshot s, {
    required bool disclosureAccepted,
  }) {
    final whenInUse = s.locationWhenInUse == Grant.granted;
    final always = s.sdkInt < backgroundLocationSdk
        ? whenInUse
        : s.locationAlways == Grant.granted;
    final notifications =
        s.sdkInt < notificationPermissionSdk ||
        s.notifications == Grant.granted;

    return GateEvaluation(
      items: [
        // Once background location is granted the rider has already been
        // through the disclosure, so it is not shown again.
        GateItem(GateStep.disclosure, done: disclosureAccepted || always),
        GateItem(
          GateStep.locationWhenInUse,
          done: whenInUse,
          blocked: s.locationWhenInUse == Grant.blocked,
        ),
        GateItem(
          GateStep.locationAlways,
          done: always,
          blocked: s.locationAlways == Grant.blocked,
        ),
        GateItem(
          GateStep.notifications,
          done: notifications,
          blocked: s.notifications == Grant.blocked,
        ),
        GateItem(
          GateStep.batteryOptimisation,
          done: s.batteryOptimisationIgnored,
        ),
        GateItem(GateStep.gps, done: s.gpsEnabled),
      ],
      fullScreenIntentMissing:
          s.sdkInt >= fullScreenIntentSdk && !s.fullScreenIntentAllowed,
      oemBrand: oemBrandOf(s.manufacturer),
    );
  }

  /// Maps `Build.MANUFACTURER` to an OEM that needs auto-start guidance.
  /// Redmi/POCO report "Xiaomi"; iQOO reports "vivo".
  static OemBrand? oemBrandOf(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return OemBrand.xiaomi;
    }
    if (m.contains('oppo')) return OemBrand.oppo;
    if (m.contains('vivo') || m.contains('iqoo')) return OemBrand.vivo;
    if (m.contains('realme')) return OemBrand.realme;
    if (m.contains('oneplus')) return OemBrand.oneplus;
    return null;
  }
}
