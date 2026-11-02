import 'package:flutter/foundation.dart';

/// Whether the rider is waiting for offers or doing a delivery task.
/// The two modes use different intervals (04 §3).
enum TrackingMode { idle, onTask }

/// How often to take a GPS fix ([sample]) and how often to POST the batch of
/// buffered fixes ([upload]).
@immutable
class TrackingIntervals {
  const TrackingIntervals({required this.sample, required this.upload});

  factory TrackingIntervals.fromJson(Map<String, dynamic> json) =>
      TrackingIntervals(
        sample: Duration(milliseconds: json['sample_ms'] as int),
        upload: Duration(milliseconds: json['upload_ms'] as int),
      );

  final Duration sample;
  final Duration upload;

  Map<String, dynamic> toJson() => {
    'sample_ms': sample.inMilliseconds,
    'upload_ms': upload.inMilliseconds,
  };

  TrackingIntervals clamped(Duration min, Duration max) => TrackingIntervals(
    sample: _clamp(sample, min, max),
    upload: _clamp(upload, min, max),
  );

  static Duration _clamp(Duration d, Duration min, Duration max) =>
      d < min ? min : (d > max ? max : d);

  @override
  bool operator ==(Object other) =>
      other is TrackingIntervals &&
      other.sample == sample &&
      other.upload == upload;

  @override
  int get hashCode => Object.hash(sample, upload);

  @override
  String toString() =>
      'TrackingIntervals(sample: ${sample.inSeconds}s, upload: ${upload.inSeconds}s)';
}

/// Tuning for the online location tracker.
///
/// The defaults follow `docs/04-rider-app.md` §3: a fix every 5 s and a batch
/// POST every 10 s on a task, both 30 s while idle. The server can override the
/// intervals ([withServerIntervals]); the app always prefers the server's
/// values.
@immutable
class TrackingConfig {
  const TrackingConfig({
    this.idle = const TrackingIntervals(
      sample: Duration(seconds: 30),
      upload: Duration(seconds: 30),
    ),
    this.onTask = const TrackingIntervals(
      sample: Duration(seconds: 5),
      upload: Duration(seconds: 10),
    ),
    this.maxBatchSize = 50,
    this.maxBufferedPoints = 5000,
  }) : assert(maxBatchSize > 0),
       assert(maxBufferedPoints > 0);

  factory TrackingConfig.fromJson(Map<String, dynamic> json) => TrackingConfig(
    idle: TrackingIntervals.fromJson(json['idle'] as Map<String, dynamic>),
    onTask: TrackingIntervals.fromJson(json['on_task'] as Map<String, dynamic>),
    maxBatchSize: json['max_batch_size'] as int,
    maxBufferedPoints: json['max_buffered_points'] as int,
  );

  /// Bounds for server-provided intervals, so a bad config can neither drain
  /// the battery nor stop updates for minutes.
  static const minInterval = Duration(seconds: 3);
  static const maxInterval = Duration(seconds: 120);

  final TrackingIntervals idle;
  final TrackingIntervals onTask;

  /// Points per POST. A reconnect after a long offline spell drains the buffer
  /// in several POSTs of this size.
  final int maxBatchSize;

  /// Offline buffer cap. When full, the oldest points are dropped: the newest
  /// position matters most for dispatch and live tracking. 5000 points is
  /// about 7 h of on-task fixes at 5 s (about 600 KB on disk).
  final int maxBufferedPoints;

  TrackingIntervals intervalsFor(TrackingMode mode) => switch (mode) {
    TrackingMode.idle => idle,
    TrackingMode.onTask => onTask,
  };

  /// Applies intervals returned by the server, clamped to
  /// [minInterval]..[maxInterval]. Null values keep the current setting.
  ///
  /// TODO(P5): feed from `config/app` `rider_location`
  /// (`active_interval_seconds`, `idle_interval_seconds`). The server sends one
  /// interval per mode; whether it is the fix or the upload interval is an
  /// open question for the backend.
  TrackingConfig withServerIntervals({
    TrackingIntervals? idle,
    TrackingIntervals? onTask,
  }) => TrackingConfig(
    idle: (idle ?? this.idle).clamped(minInterval, maxInterval),
    onTask: (onTask ?? this.onTask).clamped(minInterval, maxInterval),
    maxBatchSize: maxBatchSize,
    maxBufferedPoints: maxBufferedPoints,
  );

  Map<String, dynamic> toJson() => {
    'idle': idle.toJson(),
    'on_task': onTask.toJson(),
    'max_batch_size': maxBatchSize,
    'max_buffered_points': maxBufferedPoints,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackingConfig &&
      other.idle == idle &&
      other.onTask == onTask &&
      other.maxBatchSize == maxBatchSize &&
      other.maxBufferedPoints == maxBufferedPoints;

  @override
  int get hashCode =>
      Object.hash(idle, onTask, maxBatchSize, maxBufferedPoints);
}
