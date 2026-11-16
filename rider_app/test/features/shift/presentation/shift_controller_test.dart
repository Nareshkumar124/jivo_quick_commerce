import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/domain/rider_account.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';
import 'package:rider_app/features/location/domain/location_service_client.dart';
import 'package:rider_app/features/permissions/domain/permission_gate.dart';
import 'package:rider_app/features/permissions/domain/permission_snapshot.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';
import 'package:rider_app/features/shift/domain/shift_repository.dart';
import 'package:rider_app/features/shift/presentation/shift_controller.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/features/task/presentation/task_block.dart';
import 'package:rider_app/features/task/presentation/task_flow_controller.dart';

import '../../../helpers/fake_permissions_service.dart';
import '../../../helpers/permission_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

const _text = OnlineNotificationText(
  title: "You're online",
  body: 'Jivo Rider is using your location for deliveries.',
  channelName: 'Online status',
  channelDescription: 'Shown while you are online.',
);

/// The online toggle (04 §2.3, slice 5.2): permissions → GPS fix →
/// `shift/start` → foreground service; offline stops tracking first.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RiderTestHarness h;
  late StubbedPermissions perms;
  late ProviderContainer c;

  Future<void> setUpRider({PermissionSnapshot? snapshot}) async {
    h = RiderTestHarness();
    perms = StubbedPermissions(snapshot ?? allGranted);
    await h.signedInBefore('+919811122231');
    c = await h.container(
      extra: [permissionsServiceProvider.overrideWithValue(perms.service)],
    );
    await c.read(riderAccountControllerProvider.notifier).load();
    c.listen(shiftControllerProvider, (_, _) {});
    await pumpEventQueue();
    await c.read(shiftControllerProvider.notifier).sync();
  }

  ShiftController shift() => c.read(shiftControllerProvider.notifier);
  ShiftState state() => c.read(shiftControllerProvider);

  test('going online: GPS fix to shift/start, then the service', () async {
    await setUpRider();
    expect(state().synced, isTrue);

    expect(await shift().goOnline(_text), isTrue);
    expect(state().phase, ShiftPhase.online);
    expect(h.shift.calls, ['start(28.5706,77.3261)']);
    expect(h.location.running, isTrue);
    expect(h.location.calls, ['start(idle)']);
  });

  test('server intervals from shift/start are applied, clamped', () async {
    await setUpRider();
    h.shift.startResponse = const ShiftStart(
      onTaskIntervals: TrackingIntervals(
        sample: Duration(seconds: 1),
        upload: Duration(seconds: 8),
      ),
      maxBatch: 20,
    );
    await shift().goOnline(_text);
    final config = h.location.lastConfig!;
    expect(config.onTask.sample, TrackingConfig.minInterval);
    expect(config.onTask.upload, const Duration(seconds: 8));
    expect(config.maxBatchSize, 20);
  });

  test('a missing permission blocks going online before any request', () async {
    await setUpRider(
      snapshot: allGranted.copyWith(locationAlways: Grant.denied),
    );

    expect(await shift().goOnline(_text), isFalse);
    expect(state().problem, ShiftProblem.permissionsMissing);
    // The disclosure comes before "Allow all the time" (Play policy).
    expect(state().missingStep, GateStep.disclosure);
    expect(h.shift.calls, isEmpty);
    expect(h.locationReader.reads, 0, reason: 'no location before consent');
    expect(h.location.running, isFalse);
  });

  test('back from Settings with the gate passing clears the guard', () async {
    await setUpRider(snapshot: allGranted.copyWith(gpsEnabled: false));
    await shift().goOnline(_text);
    expect(state().missingStep, GateStep.gps);

    perms.current = allGranted;
    await shift().sync();
    expect(state().problem, isNull);
  });

  test('no GPS fix: not online, nothing sent', () async {
    await setUpRider();
    h.locationReader.unavailable = true;
    expect(await shift().goOnline(_text), isFalse);
    expect(state().problem, ShiftProblem.locationUnavailable);
    expect(h.shift.calls, isEmpty);
  });

  test('the server refuses (too far): its code is kept, no service', () async {
    await setUpRider();
    h.shift.nextStartError = const ApiError(
      code: ApiErrorCode.outsideGeofence,
      statusCode: 422,
      details: {'distance_m': 3400, 'radius_m': 2000},
    );
    expect(await shift().goOnline(_text), isFalse);
    expect(state().problem, ShiftProblem.server);
    expect(state().error!.code, ApiErrorCode.outsideGeofence);
    expect(h.location.running, isFalse);
  });

  test('the service fails to start: the shift is ended again', () async {
    await setUpRider();
    h.location.startError = StateError('foreground service not allowed');
    expect(await shift().goOnline(_text), isFalse);
    expect(state().problem, ShiftProblem.serviceFailed);
    expect(h.shift.calls, ['start(28.5706,77.3261)', 'end']);
    expect(h.shift.online, isFalse);
  });

  test('going offline stops tracking before shift/end', () async {
    await setUpRider();
    await shift().goOnline(_text);
    h.location.calls.clear();

    expect(await shift().goOffline(), isTrue);
    expect(h.location.calls, ['stop']);
    expect(h.shift.calls.last, 'end');
    expect(state().phase, ShiftPhase.offline);
    expect(state().endPending, isFalse);
  });

  test('going offline is refused during a task (rule 7)', () async {
    await setUpRider();
    await shift().goOnline(_text);
    c.read(taskBlocksGoingOfflineProvider.notifier).set(true);

    expect(await shift().goOffline(), isFalse);
    expect(state().problem, ShiftProblem.taskActive);
    expect(h.location.running, isTrue);
  });

  test('shift/end lost: offline on the phone, "Try again" resends', () async {
    await setUpRider();
    await shift().goOnline(_text);
    h.shift.nextEndError = const ApiError(code: ApiErrorCode.network);

    expect(await shift().goOffline(), isTrue);
    expect(h.location.running, isFalse, reason: 'tracking stopped anyway');
    expect(state().problem, ShiftProblem.endNotConfirmed);
    expect(state().endPending, isTrue);

    await shift().retryEnd();
    expect(state().problem, isNull);
    expect(state().endPending, isFalse);
    expect(h.shift.online, isFalse);
  });

  test('auto-offline while the app runs: offline with the reason', () async {
    await setUpRider();
    await shift().goOnline(_text);

    h.location.serverStop('RIDER_OFFLINE');
    await pumpEventQueue();
    expect(state().phase, ShiftPhase.offline);
    expect(state().problem, ShiftProblem.autoOffline);
  });

  test(
    'auto-offline while the app was closed: shown on the next start',
    () async {
      h = RiderTestHarness();
      perms = StubbedPermissions(allGranted);
      h.location.pendingServerStop = 'RIDER_OFFLINE';
      await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [permissionsServiceProvider.overrideWithValue(perms.service)],
      );
      await c.read(riderAccountControllerProvider.notifier).load();
      c.listen(shiftControllerProvider, (_, _) {});
      await pumpEventQueue();
      await shift().sync();
      expect(state().problem, ShiftProblem.autoOffline);
      expect(h.location.pendingServerStop, isNull, reason: 'shown once');
    },
  );

  test('reopened while online: the running service means online', () async {
    h = RiderTestHarness();
    perms = StubbedPermissions(allGranted);
    h.location.running = true;
    h.shift.online = true;
    await h.signedInBefore('+919811122231');
    c = await h.container(
      extra: [permissionsServiceProvider.overrideWithValue(perms.service)],
    );
    await c.read(riderAccountControllerProvider.notifier).load();
    c.listen(shiftControllerProvider, (_, _) {});
    await pumpEventQueue();
    await shift().sync();
    expect(state().phase, ShiftPhase.online);
  });

  test('a session that ends while online stops the service', () async {
    await setUpRider();
    await shift().goOnline(_text);
    await h.session.signOut(reason: SignOutReason.sessionExpired);
    expect(h.location.running, isFalse);
    expect(h.cleaner.clears, 1);
  });

  test(
    'reopened after the server auto-offlined the rider: tracking stops '
    'and the reason shows (heartbeat says offline, ended_by system)',
    () async {
      h = RiderTestHarness();
      perms = StubbedPermissions(allGranted);
      h.location.running = true;
      h.shift.autoOffline();
      await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [permissionsServiceProvider.overrideWithValue(perms.service)],
      );
      await c.read(riderAccountControllerProvider.notifier).load();
      c.listen(shiftControllerProvider, (_, _) {});
      await pumpEventQueue();
      await shift().sync();
      expect(h.location.running, isFalse);
      expect(state().phase, ShiftPhase.offline);
      expect(state().problem, ShiftProblem.autoOffline);
    },
  );

  test('ended by ops: its own reason, not the 10-minute one', () async {
    h = RiderTestHarness();
    perms = StubbedPermissions(allGranted);
    h.location.running = true;
    h.shift
      ..online = false
      ..endedBy = ShiftEndedBy.ops;
    await h.signedInBefore('+919811122231');
    c = await h.container(
      extra: [permissionsServiceProvider.overrideWithValue(perms.service)],
    );
    await c.read(riderAccountControllerProvider.notifier).load();
    c.listen(shiftControllerProvider, (_, _) {});
    await pumpEventQueue();
    await shift().sync();
    expect(h.location.running, isFalse);
    expect(state().problem, ShiftProblem.endedByOps);
  });

  // P8 hardening: Android stopped the app and its location service in the
  // middle of a delivery (OEM battery manager, force stop) and the rider
  // opens the app again. The task screen comes back, but home's toggle is
  // out of reach during a task, so nothing restarted tracking.
  group('cold start mid-task with the service gone', () {
    Future<void> coldStart({
      required bool serverOnline,
      bool task = true,
      void Function(RiderTestHarness h)? before,
    }) async {
      h = RiderTestHarness();
      perms = StubbedPermissions(allGranted);
      h.location.running = false;
      h.shift
        ..online = serverOnline
        ..activeTaskId = task ? 501 : null;
      if (task) h.tasks.seedTask(h.tasks.newTask(status: TaskStatus.pickedUp));
      before?.call(h);
      await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [permissionsServiceProvider.overrideWithValue(perms.service)],
      );
      c
        ..listen(shiftControllerProvider, (_, _) {})
        ..listen(taskFlowControllerProvider, (_, _) {});
      await c.read(riderAccountControllerProvider.notifier).load();
      await pumpEventQueue();
    }

    test('the server still has the rider online on the task: tracking '
        'resumes with the on-task intervals', () async {
      await coldStart(serverOnline: true);
      expect(
        c.read(taskFlowControllerProvider).task?.status,
        TaskStatus.pickedUp,
      );
      expect(h.location.running, isTrue);
      expect(h.location.calls, ['start(onTask)']);
      expect(state().phase, ShiftPhase.online);
      expect(state().synced, isTrue);
    });

    test('the server has the rider offline: nothing is tracked', () async {
      await coldStart(serverOnline: false);
      expect(h.location.calls, isEmpty);
      expect(state().phase, ShiftPhase.offline);
      expect(state().synced, isTrue);
    });

    test(
      'no network for the check: the next return to the app tries again',
      () async {
        await coldStart(
          serverOnline: true,
          before: (h) => h.shift.nextStatusError = const ApiError(
            code: ApiErrorCode.network,
          ),
        );
        expect(h.location.calls, isEmpty);
        expect(state().phase, ShiftPhase.offline);

        await shift().sync(); // the app came back to the foreground
        expect(h.location.calls, ['start(onTask)']);
        expect(state().phase, ShiftPhase.online);
      },
    );

    test(
      'no task: the phone stays offline until the rider goes online',
      () async {
        await coldStart(serverOnline: true, task: false);
        expect(h.location.calls, isEmpty);
        expect(h.shift.calls, isNot(contains('status')));
        expect(state().phase, ShiftPhase.offline);
      },
    );
  });

  // P8 hardening: ops suspended the rider while signed in. The schema's 403
  // example says "Not ACTIVE: route on rider_status".
  group('403 RIDER_NOT_ACTIVE routes on details.rider_status', () {
    const suspended = ApiError(
      code: ApiErrorCode.permissionDenied,
      statusCode: 403,
      details: {'reason': 'RIDER_NOT_ACTIVE', 'rider_status': 'SUSPENDED'},
    );

    RiderStatusEnum? riderStatus() =>
        switch (c.read(riderAccountControllerProvider)) {
          AccountLoaded(:final riderStatus) => riderStatus,
          _ => null,
        };

    test('going online refused: the account follows the server', () async {
      await setUpRider();
      expect(riderStatus(), RiderStatusEnum.ACTIVE);
      h.shift.nextStartError = suspended;

      expect(await shift().goOnline(_text), isFalse);
      expect(riderStatus(), RiderStatusEnum.SUSPENDED);
      expect(h.location.running, isFalse);
    });

    test('tracking stopped with PERMISSION_DENIED: the heartbeat says why, '
        'and the account follows', () async {
      await setUpRider();
      await shift().goOnline(_text);
      h.shift.nextStatusError = suspended;

      h.location.serverStop('PERMISSION_DENIED');
      await pumpEventQueue();
      expect(h.shift.calls, contains('status'));
      expect(riderStatus(), RiderStatusEnum.SUSPENDED);
    });

    test('other refusals change nothing', () async {
      await setUpRider();
      h.shift.nextStartError = const ApiError(
        code: ApiErrorCode.permissionDenied,
        statusCode: 403,
        details: {'rider_status': 'ACTIVE'},
      );
      await shift().goOnline(_text);
      expect(riderStatus(), RiderStatusEnum.ACTIVE);
    });
  });

  test('prepaid_only from shift/start is kept while online', () async {
    await setUpRider();
    h.shift.startResponse = const ShiftStart(prepaidOnly: true);
    await shift().goOnline(_text);
    expect(state().prepaidOnly, isTrue);
  });
}
