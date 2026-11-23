import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/data/in_memory_point_store.dart';
import 'package:rider_app/features/location/data/location_service_protocol.dart';
import 'package:rider_app/features/location/domain/location_buffer.dart';
import 'package:rider_app/features/location/domain/location_tracker.dart';
import 'package:rider_app/features/location/domain/location_uploader.dart';
import 'package:rider_app/features/location/domain/tracker_stats.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';

import '../../../helpers/location_fakes.dart';

/// T-821: the task id on each batch, server drops, resend order and the
/// `active_task_id` check.
void main() {
  late FakePositionSource source;
  late ScriptedUploader uploader;
  late List<TrackerStats> emitted;
  late List<int?> mismatches;

  const config = TrackingConfig(
    onTask: TrackingIntervals(
      sample: Duration(seconds: 5),
      upload: Duration(seconds: 10),
    ),
    maxBatchSize: 3,
    maxBufferedPoints: 100,
    maxRetryDelay: Duration(seconds: 10),
  );

  setUp(() {
    source = FakePositionSource();
    uploader = ScriptedUploader();
    emitted = [];
    mismatches = [];
  });

  LocationTracker build({int? taskId}) => LocationTracker(
    source: source,
    buffer: LocationBuffer(store: InMemoryPointStore(), maxPoints: 100),
    uploader: uploader,
    config: config,
    mode: TrackingMode.onTask,
    taskId: taskId,
    now: () => DateTime.utc(2026, 11, 2, 12),
    onStats: emitted.add,
    onTaskMismatch: mismatches.add,
  );

  test('every batch carries the current task id; idle sends none', () {
    fakeAsync((async) {
      final tracker = build(taskId: 7001)..start();
      async.flushMicrotasks();
      source.emit(pointN(0));
      async.elapse(const Duration(seconds: 10));

      tracker.setMode(TrackingMode.idle);
      async.flushMicrotasks();
      source.emit(pointN(1));
      async.elapse(const Duration(seconds: 30));

      expect(uploader.taskIds, [7001, null]);
      expect(emitted.last.taskId, isNull);
    });
  });

  test('a failed upload keeps the points; they go again oldest first, '
      'in recorded order, before newer fixes', () {
    fakeAsync((async) {
      build(taskId: 7001).start();
      async.flushMicrotasks();
      uploader.script.add(const UploadRetryLater('offline'));
      source.emit(pointN(0));
      source.emit(pointN(1));
      async.elapse(const Duration(seconds: 10));
      expect(emitted.last.buffered, 2, reason: 'kept after the failure');

      source.emit(pointN(2));
      source.emit(pointN(3));
      async.elapse(const Duration(seconds: 20));

      expect(uploader.batches.first, [pointN(0), pointN(1)]);
      expect(uploader.allSent.skip(2).toList(), [
        pointN(0),
        pointN(1),
        pointN(2),
        pointN(3),
      ]);
      final resent = uploader.allSent.skip(2).toList();
      for (var i = 1; i < resent.length; i++) {
        expect(resent[i].recordedAt.isAfter(resent[i - 1].recordedAt), isTrue);
      }
      expect(emitted.last.buffered, 0);
    });
  });

  test('points the server dropped (rejected_reasons) are never resent', () {
    fakeAsync((async) {
      build(taskId: 7001).start();
      async.flushMicrotasks();
      uploader.script.add(
        const UploadAccepted(dropped: 1, outOfOrder: 1, lowAccuracy: 0),
      );
      source.emit(pointN(0));
      source.emit(pointN(1));
      source.emit(pointN(2));
      async.elapse(const Duration(seconds: 10));
      source.emit(pointN(3));
      async.elapse(const Duration(seconds: 10));

      expect(uploader.batches, [
        [pointN(0), pointN(1), pointN(2)],
        [pointN(3)],
      ]);
      expect(emitted.last.serverDropped, 1);
      expect(emitted.last.historyOnly, 1);
      expect(emitted.last.uploaded, 3);
      expect(emitted.last.buffered, 0);
    });
  });

  test('another active task on the server is reported once', () {
    fakeAsync((async) {
      build(taskId: 7001).start();
      async.flushMicrotasks();
      for (var i = 0; i < 3; i++) {
        uploader.script.add(
          const UploadAccepted(activeTaskId: null, reportsActiveTask: true),
        );
        source.emit(pointN(i));
        async.elapse(const Duration(seconds: 10));
      }
      expect(mismatches, [null], reason: 'once, not on every batch');
    });
  });

  test('a mismatch that persists after the one reload is not reported '
      'again; a new server task or a task change re-arms it', () {
    fakeAsync((async) {
      final tracker = build(taskId: 7001)..start();
      async.flushMicrotasks();
      void batch(int i, int? serverTask) {
        uploader.script.add(
          UploadAccepted(activeTaskId: serverTask, reportsActiveTask: true),
        );
        source.emit(pointN(i));
        async.elapse(const Duration(seconds: 10));
      }

      batch(0, 7002);
      // The reload kept 7001 on the phone (no setMode): the same mismatch
      // keeps coming back, and is not reported on every batch.
      batch(1, 7002);
      batch(2, 7002);
      expect(mismatches, [7002]);

      // The server now reports another task: a new mismatch.
      batch(3, 7003);
      expect(mismatches, [7002, 7003]);

      // A task change on the phone clears it; the old pair is new again.
      tracker.setMode(TrackingMode.onTask, taskId: 7004);
      async.flushMicrotasks();
      tracker.setMode(TrackingMode.onTask, taskId: 7001);
      async.flushMicrotasks();
      batch(4, 7002);
      expect(mismatches, [7002, 7003, 7002]);
    });
  });

  test('the same task, or an answer without the field, is no mismatch', () {
    fakeAsync((async) {
      build(taskId: 7001).start();
      async.flushMicrotasks();
      uploader.script
        ..add(const UploadAccepted(activeTaskId: 7001, reportsActiveTask: true))
        ..add(const UploadAccepted());
      source.emit(pointN(0));
      async.elapse(const Duration(seconds: 10));
      source.emit(pointN(1));
      async.elapse(const Duration(seconds: 10));
      expect(mismatches, isEmpty);
    });
  });

  test('the set_mode message carries the task id across isolates', () {
    expect(LocationMessages.setMode(TrackingMode.onTask, taskId: 7001), {
      'type': 'set_mode',
      'mode': 'onTask',
      'task_id': 7001,
    });
    expect(
      LocationMessages.isTaskMismatch(LocationMessages.taskMismatch(4)),
      isTrue,
    );
    const settings = LocationTaskSettings(
      config: TrackingConfig(),
      mode: TrackingMode.onTask,
      taskId: 7001,
    );
    final restored = LocationTaskSettings.fromJson(settings.toJson());
    expect(restored.taskId, 7001);
    expect(restored.copyWith(clearTaskId: true).taskId, isNull);
  });

  test('stats keep the new counters across the isolate boundary', () {
    fakeAsync((async) {
      build(taskId: 7001).start();
      async.flushMicrotasks();
      final stats = TrackerStats.fromJson(emitted.last.toJson());
      expect(stats.taskId, 7001);
      expect(stats.serverDropped, 0);
    });
  });
}
