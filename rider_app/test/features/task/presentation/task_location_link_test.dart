import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/features/task/presentation/task_flow_controller.dart';

import '../../../helpers/rider_app_harness.dart';

/// T-821: the task controller tells the location service which task the
/// pings belong to, and re-reads the task when the server sees another.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RiderTestHarness h;
  late ProviderContainer c;

  Future<void> start(TaskStatus? status) async {
    h = RiderTestHarness();
    if (status != null) h.tasks.seedTask(h.tasks.newTask(status: status));
    await h.signedInBefore('+919811122231');
    c = await h.container();
    c.listen(taskFlowControllerProvider, (_, _) {});
    await c.read(riderAccountControllerProvider.notifier).load();
    await c.read(taskFlowControllerProvider.notifier).load();
  }

  test('on a task the pings carry its id; idle carries none', () async {
    await start(TaskStatus.pickedUp);
    final id = c.read(taskFlowControllerProvider).task!.id;
    expect(h.location.lastMode, (TrackingMode.onTask, id));

    await start(null);
    expect(h.location.lastMode, isNull, reason: 'no task, nothing sent');
  });

  test('another active task on the server: the task is read again', () async {
    await start(TaskStatus.assigned);
    final before = h.tasks.calls.where((c) => c == 'fetchCurrentTask').length;

    h.location.taskMismatch();
    await pumpEventQueue();

    expect(
      h.tasks.calls.where((c) => c == 'fetchCurrentTask').length,
      before + 1,
    );
  });
}
