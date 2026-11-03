// Accept → deliver against the fakes, moving along a GPX route
// (docs/development-phase.md §3, Phase 4 Rider: the integration-test
// harness). No backend needed: every platform plugin and the rider API are
// faked (`test/helpers/rider_app_harness.dart`), so the run proves the app's
// screens and state machine on a real Android build.
//
//   flutter test integration_test/accept_to_deliver_fake_test.dart \
//     --flavor dev -d emulator-5554
//
// Never run it on a phone that someone is testing with.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/delivery_flow_driver.dart';
import '../test/helpers/rider_app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accept → arrived store → pickup → arrived customer → deliver '
      '(GPX route, fakes)', (tester) async {
    final h = RiderTestHarness();
    await h.signedInBefore('+919811122231');
    await h.pump(tester);

    await driveAcceptToDeliver(tester, h);

    expect(h.tasks.calls.last, 'deliver prepaid null');
  });
}
