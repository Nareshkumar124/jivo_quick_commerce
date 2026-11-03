// Accept → deliver against the fakes, moving along a GPX route
// (docs/development-phase.md §3, Phase 4 Rider: the integration-test
// harness). No backend needed: every platform plugin and the rider API are
// faked (`test/helpers/rider_app_harness.dart`), so the run proves the app's
// screens and state machine on a real Android build. The same driver runs
// as a widget test in CI
// (`test/features/task/presentation/accept_to_deliver_route_test.dart`).
//
// There is no emulator on this machine (CLAUDE.md): run it on the USB phone,
// only when nobody else is using it, then put the normal dev build back:
//
//   flutter test integration_test/accept_to_deliver_fake_test.dart \
//     --flavor dev -d 9TY5KF8H49Z5YDON
//   flutter build apk --flavor dev -t lib/main_dev.dart \
//     --dart-define=API_BASE_URL=http://localhost:8001
//   adb -s 9TY5KF8H49Z5YDON install -r \
//     build/app/outputs/flutter-apk/app-dev-release.apk
//
// (No `adb reverse` is needed for this test: it never calls the backend.
// The dev build the user runs does need `adb reverse tcp:8001 tcp:8001`.)
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/delivery_flow_driver.dart';
import '../test/helpers/rider_app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('prepaid: accept → arrived store → pickup → arrived customer '
      '→ deliver (GPX route, fakes)', (tester) async {
    final h = RiderTestHarness();
    await h.signedInBefore('+919811122231');
    await h.pump(tester);

    await driveAcceptToDeliver(tester, h);

    expect(h.tasks.calls.last, 'deliver prepaid null');
  });

  testWidgets('COD: the same ride, cash confirmed before deliver '
      '(GPX route, fakes)', (tester) async {
    final h = RiderTestHarness();
    await h.signedInBefore('+919811122231');
    await h.pump(tester);

    await driveAcceptToDeliver(tester, h, cod: true);

    expect(h.tasks.calls.last, 'deliver cash 1249.00');
  });
}
