import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/platform_permissions_service.dart';
import '../domain/permission_gate.dart';
import '../domain/permissions_service.dart';

final permissionsServiceProvider = Provider<PermissionsService>(
  (ref) => const PlatformPermissionsService(),
);

/// Whether the rider accepted the location disclosure in this app session.
/// Not persisted: if background location is not granted yet, the disclosure
/// is shown again before the next request (Play policy).
final disclosureAcceptedProvider = NotifierProvider<DisclosureAccepted, bool>(
  DisclosureAccepted.new,
);

class DisclosureAccepted extends Notifier<bool> {
  @override
  bool build() => false;

  void accept() => state = true;
}

/// What the gate tells the rider after a step did not work out.
@immutable
class GateNotices {
  const GateNotices({
    this.alwaysNotChosen = false,
    this.disclosureDeclined = false,
  });

  /// The rider came back from the "Allow all the time" request without
  /// choosing it (Android 11+ opens the app's location settings page, where
  /// "Allow only while using the app" is easy to keep). The gate then
  /// explains what to choose and offers the app settings page.
  final bool alwaysNotChosen;

  /// The rider tapped "Not now" on the prominent disclosure. Nothing is
  /// requested; the gate explains that going online needs location.
  final bool disclosureDeclined;
}

final gateNoticesProvider = NotifierProvider<GateNoticesNotifier, GateNotices>(
  GateNoticesNotifier.new,
);

class GateNoticesNotifier extends Notifier<GateNotices> {
  @override
  GateNotices build() => const GateNotices();

  void set({bool? alwaysNotChosen, bool? disclosureDeclined}) {
    state = GateNotices(
      alwaysNotChosen: alwaysNotChosen ?? state.alwaysNotChosen,
      disclosureDeclined: disclosureDeclined ?? state.disclosureDeclined,
    );
  }
}

final permissionsGateControllerProvider =
    AsyncNotifierProvider<PermissionsGateController, GateEvaluation>(
      PermissionsGateController.new,
    );

/// Drives the permissions gate (04 §2.1): reads the device state, decides the
/// next step and runs the matching system request.
class PermissionsGateController extends AsyncNotifier<GateEvaluation> {
  PermissionsService get _service => ref.read(permissionsServiceProvider);

  @override
  Future<GateEvaluation> build() =>
      _evaluate(disclosureAccepted: ref.read(disclosureAcceptedProvider));

  Future<GateEvaluation> _evaluate({required bool disclosureAccepted}) async {
    final snapshot = await _service.snapshot();
    return PermissionGate.evaluate(
      snapshot,
      disclosureAccepted: disclosureAccepted,
    );
  }

  /// Re-reads the device, for example when the rider returns from Settings.
  Future<GateEvaluation> refresh() async {
    final result = await AsyncValue.guard(
      () => _evaluate(disclosureAccepted: ref.read(disclosureAcceptedProvider)),
    );
    if (ref.mounted) state = result;
    return result.requireValue;
  }

  /// The rider accepted the prominent disclosure. Continues straight to the
  /// next system request, so the disclosure immediately precedes it.
  Future<void> acceptDisclosure() async {
    ref.read(disclosureAcceptedProvider.notifier).accept();
    ref.read(gateNoticesProvider.notifier).set(disclosureDeclined: false);
    final evaluation = await refresh();
    final next = evaluation.nextAfterDisclosure;
    if (next != null) await fix(next);
  }

  /// The rider declined the disclosure: no location request is made (Play
  /// policy), and going online stays blocked with an explanation.
  void declineDisclosure() =>
      ref.read(gateNoticesProvider.notifier).set(disclosureDeclined: true);

  /// The app's settings page, where the rider picks Permissions › Location ›
  /// "Allow all the time" by hand (the deep link Android allows; there is no
  /// public intent for the location permission page itself).
  Future<void> openLocationAlwaysSettings() async {
    await _service.openAppSettings();
    await refresh();
  }

  /// Whether a location prompt may be shown now: the disclosure was accepted
  /// in this session, or the rider has been through it already (its row is
  /// done, e.g. background location granted and only "Precise" missing).
  bool get disclosureSatisfied =>
      ref.read(disclosureAcceptedProvider) ||
      (state.value?.items.any((i) => i.step == GateStep.disclosure && i.done) ??
          false);

  /// Runs the system request (or settings page) for [item]. The disclosure
  /// step is handled by the UI, which shows the disclosure screen.
  Future<void> fix(GateItem item) async {
    if (item.step == GateStep.disclosure) return;
    if (item.blocked) {
      await _service.openAppSettings();
    } else {
      switch (item.step) {
        case GateStep.disclosure:
          return;
        case GateStep.locationWhenInUse:
          // The prominent disclosure precedes every location prompt, also
          // when the rider taps the row directly (Play launch check).
          if (!disclosureSatisfied) return;
          await _service.requestLocationWhenInUse();
        case GateStep.locationAlways:
          // Play policy: never ask for background location before the
          // disclosure was accepted or already gone through (the screen shows
          // the disclosure first when it is not, so a tap never does nothing).
          if (!disclosureSatisfied) return;
          await _service.requestLocationAlways();
          final after = await refresh();
          final notChosen = after.items.any(
            (i) => i.step == GateStep.locationAlways && !i.done,
          );
          if (ref.mounted) {
            ref
                .read(gateNoticesProvider.notifier)
                .set(alwaysNotChosen: notChosen);
          }
          return;
        case GateStep.notifications:
          await _service.requestNotifications();
        case GateStep.gps:
          await _service.openLocationSettings();
      }
    }
    await refresh();
  }

  Future<void> openAppSettings() => _service.openAppSettings();

  /// Optional battery tip: the system list of battery-optimised apps, where
  /// the rider can pick Jivo Rider and choose "Don't optimise". Re-read on
  /// return so the tip disappears once it is done.
  Future<void> openBatteryOptimisationSettings() async {
    await _service.openBatteryOptimisationSettings();
    await refresh();
  }

  /// The rider skipped the battery tip: it is hidden until the app restarts.
  void skipBatteryTip() => ref.read(batteryTipSkippedProvider.notifier).skip();
}

/// Whether the rider skipped the optional battery tip in this app session.
final batteryTipSkippedProvider = NotifierProvider<BatteryTipSkipped, bool>(
  BatteryTipSkipped.new,
);

class BatteryTipSkipped extends Notifier<bool> {
  @override
  bool build() => false;

  void skip() => state = true;
}
