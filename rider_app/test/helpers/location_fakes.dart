import 'dart:async';

import 'package:rider_app/features/location/domain/location_point.dart';
import 'package:rider_app/features/location/domain/location_uploader.dart';
import 'package:rider_app/features/location/domain/point_store.dart';
import 'package:rider_app/features/location/domain/position_source.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';

final _t0 = DateTime.utc(2026, 11, 2, 10);

/// Point number [i], recorded [i] seconds after a fixed start time.
LocationPoint pointN(int i) => LocationPoint(
  lat: 28.6 + i / 10000,
  lng: 77.2 + i / 10000,
  accuracy: 5,
  recordedAt: _t0.add(Duration(seconds: i)),
);

/// GPS source driven by the test. Each subscription gets its own controller.
class FakePositionSource implements PositionSource {
  final requested = <TrackingIntervals>[];
  final controllers = <StreamController<LocationPoint>>[];
  int cancels = 0;

  StreamController<LocationPoint> get current => controllers.last;

  bool get isListening =>
      controllers.isNotEmpty && controllers.last.hasListener;

  @override
  Stream<LocationPoint> positions(TrackingIntervals intervals) {
    requested.add(intervals);
    // Async onCancel: under fake_async, a synchronous onCancel makes
    // cancel() return an already-completed root-zone future whose
    // continuations fake_async never runs.
    final controller = StreamController<LocationPoint>(
      onCancel: () async => cancels++,
    );
    controllers.add(controller);
    return controller.stream;
  }

  /// Emits on the latest subscription, like the platform would.
  void emit(LocationPoint point) => current.add(point);
}

/// Uploader that records batches and replays scripted results (accepts by
/// default).
class ScriptedUploader implements LocationUploader {
  final batches = <List<LocationPoint>>[];
  final script = <UploadResult>[];
  Object? throwNext;

  List<LocationPoint> get allSent => [for (final b in batches) ...b];

  @override
  Future<UploadResult> upload(List<LocationPoint> batch) async {
    if (throwNext != null) {
      final error = throwNext!;
      throwNext = null;
      throw error;
    }
    batches.add(batch);
    return script.isEmpty ? const UploadAccepted() : script.removeAt(0);
  }

  /// Heartbeats sent, with the last known fix of each.
  final heartbeatsSent = <LocationPoint?>[];
  final heartbeatScript = <UploadResult>[];

  @override
  Future<UploadResult> heartbeat({LocationPoint? lastKnown}) async {
    heartbeatsSent.add(lastKnown);
    return heartbeatScript.isEmpty
        ? const UploadAccepted()
        : heartbeatScript.removeAt(0);
  }
}

/// Store whose writes can be made to fail.
class FailingPointStore implements PointStore {
  bool fail = true;
  final stored = <LocationPoint>[];
  int replaceCalls = 0;

  @override
  Future<List<LocationPoint>> load() async => [...stored];

  @override
  Future<void> append(List<LocationPoint> points) async {
    if (fail) throw StateError('disk full');
    stored.addAll(points);
  }

  @override
  Future<void> replaceAll(List<LocationPoint> points) async {
    replaceCalls++;
    if (fail) throw StateError('disk full');
    stored
      ..clear()
      ..addAll(points);
  }
}
