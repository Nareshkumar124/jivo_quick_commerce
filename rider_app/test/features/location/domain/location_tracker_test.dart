import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/data/in_memory_point_store.dart';
import 'package:rider_app/features/location/domain/location_buffer.dart';
import 'package:rider_app/features/location/domain/location_tracker.dart';
import 'package:rider_app/features/location/domain/location_uploader.dart';
import 'package:rider_app/features/location/domain/tracker_stats.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';

import '../../../helpers/location_fakes.dart';

void main() {
  late FakePositionSource source;
  late ScriptedUploader uploader;
  late InMemoryPointStore store;
  late List<TrackerStats> emitted;

  const config = TrackingConfig(
    idle: TrackingIntervals(
      sample: Duration(seconds: 30),
      upload: Duration(seconds: 30),
    ),
    onTask: TrackingIntervals(
      sample: Duration(seconds: 5),
      upload: Duration(seconds: 10),
    ),
    maxBatchSize: 3,
    maxBufferedPoints: 100,
  );

  setUp(() {
    source = FakePositionSource();
    uploader = ScriptedUploader();
    store = InMemoryPointStore();
    emitted = [];
  });

  LocationTracker build({
    TrackingMode mode = TrackingMode.onTask,
    InMemoryPointStore? withStore,
  }) => LocationTracker(
    source: source,
    buffer: LocationBuffer(store: withStore ?? store, maxPoints: 100),
    uploader: uploader,
    config: config,
    mode: mode,
    resubscribeDelay: const Duration(seconds: 10),
    now: () => DateTime.utc(2026, 11, 2, 12),
    onStats: emitted.add,
  );

  test('defaults follow 04 §3: 5 s / 10 s on task, 30 s idle', () {
    const defaults = TrackingConfig();
    expect(defaults.onTask.sample, const Duration(seconds: 5));
    expect(defaults.onTask.upload, const Duration(seconds: 10));
    expect(defaults.idle.sample, const Duration(seconds: 30));
    expect(defaults.idle.upload, const Duration(seconds: 30));
  });

  test('start subscribes with the interval of the current mode', () {
    fakeAsync((async) {
      final tracker = build(mode: TrackingMode.idle);
      tracker.start();
      async.flushMicrotasks();

      expect(tracker.isRunning, isTrue);
      expect(source.requested.single, config.idle);
    });
  });

  test('fixes are batched and uploaded on the upload interval', () {
    fakeAsync((async) {
      build().start();
      async.flushMicrotasks();

      source.emit(pointN(0));
      source.emit(pointN(1));
      async.elapse(const Duration(seconds: 9));
      expect(uploader.batches, isEmpty, reason: 'not before 10 s');

      async.elapse(const Duration(seconds: 1));
      expect(uploader.batches, [
        [pointN(0), pointN(1)],
      ]);
      expect(emitted.last.buffered, 0);
      expect(emitted.last.uploaded, 2);
      expect(emitted.last.lastUploadStatus, UploadStatus.accepted);
    });
  });

  test('a failed upload keeps the points and the next tick sends them '
      '(flush on reconnect), in recorded order', () {
    fakeAsync((async) {
      uploader.script.add(const UploadRetryLater('no network'));
      build().start();
      async.flushMicrotasks();

      source.emit(pointN(0));
      source.emit(pointN(1));
      async.elapse(const Duration(seconds: 10));
      expect(emitted.last.buffered, 2);
      expect(emitted.last.lastUploadStatus, UploadStatus.retryLater);

      source.emit(pointN(2));
      source.emit(pointN(3));
      async.elapse(const Duration(seconds: 10));

      // Batch size 3: the backlog drains in two POSTs within one tick.
      expect(uploader.batches.skip(1).toList(), [
        [pointN(0), pointN(1), pointN(2)],
        [pointN(3)],
      ]);
      expect(emitted.last.buffered, 0);
      expect(emitted.last.uploaded, 4);
    });
  });

  test('an uploader exception is treated as retry-later', () {
    fakeAsync((async) {
      uploader.throwNext = Exception('socket closed');
      build().start();
      async.flushMicrotasks();
      source.emit(pointN(0));

      async.elapse(const Duration(seconds: 10));
      expect(emitted.last.buffered, 1);
      expect(emitted.last.lastError, contains('socket closed'));

      async.elapse(const Duration(seconds: 10));
      expect(uploader.allSent, [pointN(0)]);
      expect(emitted.last.buffered, 0);
    });
  });

  test('a rejected batch is dropped and later points still go out', () {
    fakeAsync((async) {
      uploader.script.add(const UploadRejected('VALIDATION_ERROR'));
      build().start();
      async.flushMicrotasks();
      for (var i = 0; i < 4; i++) {
        source.emit(pointN(i));
      }

      async.elapse(const Duration(seconds: 10));

      expect(uploader.batches, [
        [pointN(0), pointN(1), pointN(2)],
        [pointN(3)],
      ]);
      expect(emitted.last.rejected, 3);
      expect(emitted.last.uploaded, 1);
      expect(emitted.last.buffered, 0);
    });
  });

  test('switching to on-task re-subscribes with the faster interval and '
      'speeds up uploads', () {
    fakeAsync((async) {
      final tracker = build(mode: TrackingMode.idle);
      tracker.start();
      async.flushMicrotasks();

      tracker.setMode(TrackingMode.onTask);
      async.flushMicrotasks();

      expect(source.requested, [config.idle, config.onTask]);
      expect(source.cancels, 1);

      source.emit(pointN(0));
      async.elapse(const Duration(seconds: 10));
      expect(uploader.allSent, [pointN(0)]);
    });
  });

  test('server intervals replace the defaults, clamped to safe bounds', () {
    fakeAsync((async) {
      uploader.script.add(
        const UploadAccepted(
          onTaskIntervals: TrackingIntervals(
            sample: Duration(seconds: 8),
            upload: Duration(milliseconds: 500),
          ),
        ),
      );
      final tracker = build();
      tracker.start();
      async.flushMicrotasks();
      source.emit(pointN(0));

      async.elapse(const Duration(seconds: 10));

      expect(
        tracker.config.onTask,
        const TrackingIntervals(
          sample: Duration(seconds: 8),
          upload: TrackingConfig.minInterval,
        ),
      );
      expect(source.requested.last.sample, const Duration(seconds: 8));
    });
  });

  test('stop ends location updates: no more fixes, no more uploads', () {
    fakeAsync((async) {
      uploader.script.add(const UploadRetryLater());
      final tracker = build();
      tracker.start();
      async.flushMicrotasks();
      final controller = source.current;
      source.emit(pointN(0));
      async.elapse(const Duration(seconds: 10)); // fails, point kept

      tracker.stop();
      async.flushMicrotasks();
      expect(tracker.isRunning, isFalse);
      expect(controller.hasListener, isFalse, reason: 'GPS stream cancelled');

      // A late fix from the platform is ignored.
      controller.add(pointN(1));
      async.elapse(const Duration(minutes: 5));

      expect(uploader.batches.length, 1, reason: 'no uploads after stop');
      expect(store.points, [pointN(0)], reason: 'kept for next session');
      expect(emitted.last.running, isFalse);
    });
  });

  test('stop with a flush timeout makes one last upload attempt', () {
    fakeAsync((async) {
      final tracker = build();
      tracker.start();
      async.flushMicrotasks();
      source.emit(pointN(0));
      async.flushMicrotasks(); // deliver the fix before going offline

      tracker.stop(flushTimeout: const Duration(seconds: 3));
      async.flushMicrotasks();

      expect(uploader.allSent, [pointN(0)]);
      expect(store.points, isEmpty);
    });
  });

  test('a GPS error re-subscribes after the delay', () {
    fakeAsync((async) {
      build().start();
      async.flushMicrotasks();

      source.current.addError(StateError('location service disabled'));
      async.flushMicrotasks();
      expect(emitted.last.lastError, contains('location service disabled'));
      expect(source.requested.length, 1);

      async.elapse(const Duration(seconds: 10));
      expect(source.requested.length, 2);
      expect(source.isListening, isTrue);
    });
  });

  test('points left from an earlier session are uploaded first', () {
    fakeAsync((async) {
      final persisted = InMemoryPointStore([pointN(0), pointN(1)]);
      build(withStore: persisted).start();
      async.flushMicrotasks();
      source.emit(pointN(2));

      async.elapse(const Duration(seconds: 10));

      expect(uploader.allSent, [pointN(0), pointN(1), pointN(2)]);
    });
  });
}
