import 'dart:io';

import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/data/file_point_store.dart';
import 'package:rider_app/features/location/data/in_memory_point_store.dart';
import 'package:rider_app/features/location/domain/location_buffer.dart';
import 'package:rider_app/features/location/domain/location_tracker.dart';
import 'package:rider_app/features/location/domain/location_uploader.dart';
import 'package:rider_app/features/location/domain/tracker_stats.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';

import '../../../helpers/location_fakes.dart';

class _NoJitter implements Random {
  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

/// Slice 5.2: retry backoff, heartbeat, the server stopping tracking, and the
/// queue surviving a restart.
void main() {
  late FakePositionSource source;
  late ScriptedUploader uploader;
  late InMemoryPointStore store;
  late List<TrackerStats> emitted;
  late List<String> serverStops;

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
    heartbeat: Duration(seconds: 60),
    maxRetryDelay: Duration(seconds: 60),
  );

  setUp(() {
    source = FakePositionSource();
    uploader = ScriptedUploader();
    store = InMemoryPointStore();
    emitted = [];
    serverStops = [];
  });

  LocationTracker build({TrackingMode mode = TrackingMode.onTask}) =>
      LocationTracker(
        source: source,
        buffer: LocationBuffer(store: store, maxPoints: 100),
        uploader: uploader,
        config: config,
        mode: mode,
        now: () => DateTime.utc(2026, 11, 4, 12),
        onStats: emitted.add,
        onServerStop: serverStops.add,
        random: _NoJitter(),
      );

  group('backoff on a dead network', () {
    test('retries at 10, 20, 40, 60, 60 s instead of every tick', () {
      fakeAsync((async) {
        uploader.script.addAll(
          List.filled(5, const UploadRetryLater('no network')),
        );
        build().start();
        async.flushMicrotasks();
        source.emit(pointN(0));

        // Attempts: tick at 10 s, then retries 10, 20, 40, 60 s later.
        final attemptsAt = <int>[];
        for (var second = 1; second <= 150; second++) {
          final before = uploader.batches.length;
          async.elapse(const Duration(seconds: 1));
          if (uploader.batches.length > before) attemptsAt.add(second);
        }
        expect(attemptsAt, [10, 20, 40, 80, 140]);
        expect(emitted.last.consecutiveFailures, 5);
        expect(emitted.last.buffered, 1, reason: 'the point is kept');
      });
    });

    test('a success resets the backoff and drains the buffer', () {
      fakeAsync((async) {
        uploader.script.addAll([
          const UploadRetryLater('no network'),
          const UploadRetryLater('no network'),
        ]);
        build().start();
        async.flushMicrotasks();
        source.emit(pointN(0));
        async.elapse(const Duration(seconds: 10)); // fail 1
        source.emit(pointN(1));
        async.elapse(const Duration(seconds: 10)); // fail 2 (retry)
        async.elapse(const Duration(seconds: 20)); // retry succeeds

        expect(uploader.allSent.toSet(), containsAll([pointN(0), pointN(1)]));
        expect(emitted.last.buffered, 0);
        expect(emitted.last.consecutiveFailures, 0);

        // Back to the normal 10 s tick.
        source.emit(pointN(2));
        final sent = uploader.batches.length;
        async.elapse(const Duration(seconds: 10));
        expect(uploader.batches.length, sent + 1);
      });
    });

    test("the server's Retry-After is honoured", () {
      fakeAsync((async) {
        uploader.script.add(
          const UploadRetryLater('429', Duration(seconds: 45)),
        );
        build().start();
        async.flushMicrotasks();
        source.emit(pointN(0));
        async.elapse(const Duration(seconds: 10));
        expect(uploader.batches, hasLength(1));

        async.elapse(const Duration(seconds: 44));
        expect(uploader.batches, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(uploader.batches, hasLength(2));
      });
    });
  });

  group('heartbeat', () {
    test('sent when nothing reached the server for a whole window', () {
      fakeAsync((async) {
        final tracker = build(mode: TrackingMode.idle);
        tracker.start();
        async.flushMicrotasks();

        // No fix at all (indoors): first window ends at 60 s.
        async.elapse(const Duration(seconds: 60));
        expect(uploader.heartbeatsSent, [null]);
        expect(emitted.last.heartbeats, 1);

        // That heartbeat counts as contact for the next window, so the
        // next one is due at 180 s: at most two windows (2 min) between
        // contacts, far below the 10-min auto-offline.
        async.elapse(const Duration(seconds: 60));
        expect(uploader.heartbeatsSent, hasLength(1));
        async.elapse(const Duration(seconds: 60));
        expect(uploader.heartbeatsSent, hasLength(2));
      });
    });

    test('not sent while uploads reach the server; carries the last fix', () {
      fakeAsync((async) {
        build().start();
        async.flushMicrotasks();
        for (var i = 0; i < 12; i++) {
          source.emit(pointN(i));
          async.elapse(const Duration(seconds: 10));
        }
        expect(uploader.heartbeatsSent, isEmpty);

        // GPS goes quiet; the buffer is empty.
        async.elapse(const Duration(seconds: 120));
        expect(uploader.heartbeatsSent, isNotEmpty);
        expect(uploader.heartbeatsSent.first, pointN(11));
      });
    });

    test('a failed heartbeat retries with backoff', () {
      fakeAsync((async) {
        uploader.heartbeatScript.add(const UploadRetryLater('no network'));
        build(mode: TrackingMode.idle).start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));
        expect(uploader.heartbeatsSent, hasLength(1));

        async.elapse(const Duration(seconds: 30)); // idle upload interval
        expect(uploader.heartbeatsSent, hasLength(2));
        expect(emitted.last.heartbeats, 1);
      });
    });
  });

  group('the server stops tracking (auto-offline)', () {
    test('on an upload: stop at once, no more fixes, callback once', () {
      fakeAsync((async) {
        uploader.script.add(const UploadTrackingStopped('RIDER_OFFLINE'));
        final tracker = build();
        tracker.start();
        async.flushMicrotasks();
        source.emit(pointN(0));
        async.elapse(const Duration(seconds: 10));

        expect(tracker.isRunning, isFalse);
        expect(tracker.stoppedBy, 'RIDER_OFFLINE');
        expect(serverStops, ['RIDER_OFFLINE']);
        expect(source.isListening, isFalse);

        async.elapse(const Duration(minutes: 5));
        expect(uploader.batches, hasLength(1));
        expect(uploader.heartbeatsSent, isEmpty);

        tracker.start();
        async.flushMicrotasks();
        expect(tracker.isRunning, isFalse, reason: 'a new shift is needed');
      });
    });

    test('on a heartbeat too', () {
      fakeAsync((async) {
        uploader.heartbeatScript.add(
          const UploadTrackingStopped('RIDER_OFFLINE'),
        );
        final tracker = build(mode: TrackingMode.idle);
        tracker.start();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));
        expect(tracker.isRunning, isFalse);
        expect(serverStops, ['RIDER_OFFLINE']);
      });
    });
  });

  test(
    'server intervals and the heartbeat window can change while running',
    () {
      fakeAsync((async) {
        final tracker = build(mode: TrackingMode.idle);
        tracker.start();
        async.flushMicrotasks();
        tracker.updateConfig(
          TrackingConfig(
            idle: config.idle,
            onTask: config.onTask,
            maxBatchSize: 3,
            maxBufferedPoints: 100,
            heartbeat: const Duration(seconds: 20),
          ),
        );
        async.elapse(const Duration(seconds: 20));
        expect(uploader.heartbeatsSent, hasLength(1));
      });
    },
  );

  test('the upload queue survives a kill: a new tracker on the same file '
      'sends the old points first, in order', () async {
    final dir = await Directory.systemTemp.createTemp('rider_queue');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/buffer.jsonl');

    // Session 1: offline, three fixes, then the process dies (no stop()).
    final offline = ScriptedUploader()
      ..script.addAll(List.filled(10, const UploadRetryLater('offline')));
    final first = FakePositionSource();
    final buffer1 = LocationBuffer(store: FilePointStore(file), maxPoints: 100);
    final tracker1 = LocationTracker(
      source: first,
      buffer: buffer1,
      uploader: offline,
      config: config,
      mode: TrackingMode.onTask,
    );
    await tracker1.start();
    for (var i = 0; i < 3; i++) {
      first.emit(pointN(i));
    }
    await Future<void>.delayed(Duration.zero);
    await buffer1.settle();

    // Session 2 (service restarted by the system): network back.
    final online = ScriptedUploader();
    final second = FakePositionSource();
    final tracker2 = LocationTracker(
      source: second,
      buffer: LocationBuffer(store: FilePointStore(file), maxPoints: 100),
      uploader: online,
      config: config,
      mode: TrackingMode.onTask,
    );
    await tracker2.start();
    second.emit(pointN(3));
    await Future<void>.delayed(Duration.zero);
    await tracker2.flush();

    expect(online.allSent, [pointN(0), pointN(1), pointN(2), pointN(3)]);
    await tracker1.stop();
    await tracker2.stop();
  });

  group('TrackingConfig', () {
    test('settings saved by an older build (no heartbeat keys) still load', () {
      final old = const TrackingConfig().toJson()
        ..remove('heartbeat_ms')
        ..remove('max_retry_delay_ms');
      final loaded = TrackingConfig.fromJson(old);
      expect(loaded.heartbeat, const Duration(seconds: 60));
      expect(loaded, const TrackingConfig());
    });

    test('round-trips through JSON', () {
      expect(TrackingConfig.fromJson(config.toJson()), config);
    });

    test('config/app rider_location seconds apply to both intervals, '
        'clamped; missing values keep the defaults', () {
      final c = const TrackingConfig().fromRiderLocationSeconds(
        active: 1,
        idle: 45,
      );
      expect(c.onTask.sample, TrackingConfig.minInterval);
      expect(c.idle.upload, const Duration(seconds: 45));
      expect(
        const TrackingConfig().fromRiderLocationSeconds(),
        const TrackingConfig(),
      );
    });
  });
}
