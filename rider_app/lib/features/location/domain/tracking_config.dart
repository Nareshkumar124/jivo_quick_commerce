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
    this.heartbeat = const Duration(seconds: 60),
    this.maxRetryDelay = const Duration(seconds: 60),
  }) : assert(maxBatchSize > 0),
       assert(maxBufferedPoints > 0);

  /// Reads [toJson] output. Keys added after the Phase 0 spike are optional,
  /// so settings saved by an older build still load.
  factory TrackingConfig.fromJson(Map<String, dynamic> json) => TrackingConfig(
    idle: TrackingIntervals.fromJson(
      (json['idle'] as Map).cast<String, dynamic>(),
    ),
    onTask: TrackingIntervals.fromJson(
      (json['on_task'] as Map).cast<String, dynamic>(),
    ),
    maxBatchSize: json['max_batch_size'] as int,
    maxBufferedPoints: json['max_buffered_points'] as int,
    heartbeat: json['heartbeat_ms'] is int
        ? Duration(milliseconds: json['heartbeat_ms'] as int)
        : const Duration(seconds: 60),
    maxRetryDelay: json['max_retry_delay_ms'] is int
        ? Duration(milliseconds: json['max_retry_delay_ms'] as int)
        : const Duration(seconds: 60),
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

  /// When nothing was uploaded for this long (no fix: indoors, GPS stream
  /// restarting), the tracker sends a heartbeat so the server does not
  /// auto-offline a rider who is still online (10 min, 04 §2.3).
  final Duration heartbeat;

  /// Upper bound of the retry backoff after failed uploads. Kept short: on a
  /// patchy network the next good minute must not be missed.
  final Duration maxRetryDelay;

  TrackingIntervals intervalsFor(TrackingMode mode) => switch (mode) {
    TrackingMode.idle => idle,
    TrackingMode.onTask => onTask,
  };

  /// Applies intervals returned by the server, clamped to
  /// [minInterval]..[maxInterval]. Null values keep the current setting.
  ///
  /// The server sends one interval per mode in `config/app` `rider_location`
  /// today; [fromRiderLocationSeconds] uses it for both the fix and the upload
  /// interval until api-requests #2 splits them.
  TrackingConfig withServerIntervals({
    TrackingIntervals? idle,
    TrackingIntervals? onTask,
    int? maxBatchSize,
  }) => TrackingConfig(
    idle: (idle ?? this.idle).clamped(minInterval, maxInterval),
    onTask: (onTask ?? this.onTask).clamped(minInterval, maxInterval),
    maxBatchSize: (maxBatchSize != null && maxBatchSize > 0)
        ? maxBatchSize
        : this.maxBatchSize,
    maxBufferedPoints: maxBufferedPoints,
    heartbeat: heartbeat,
    maxRetryDelay: maxRetryDelay,
  );

  /// The server's `rider_location` settings (`config/app`, `shift/start`,
  /// `locations` and `heartbeat` responses; api-requests #2): upload and
  /// sample periods per mode, and the batch size. A sample period missing
  /// (older server) falls back to the upload period. Null or non-positive
  /// values keep the current setting; everything is clamped.
  TrackingConfig fromRiderLocationSeconds({
    int? active,
    int? idle,
    int? activeSample,
    int? idleSample,
    int? maxBatch,
  }) {
    TrackingIntervals? pair(int? upload, int? sample, TrackingIntervals now) {
      final u = upload != null && upload > 0 ? upload : null;
      final s = sample != null && sample > 0 ? sample : u;
      if (u == null && s == null) return null;
      return TrackingIntervals(
        sample: s == null ? now.sample : Duration(seconds: s),
        upload: u == null ? now.upload : Duration(seconds: u),
      );
    }

    return withServerIntervals(
      idle: pair(idle, idleSample, this.idle),
      onTask: pair(active, activeSample, onTask),
      maxBatchSize: maxBatch,
    );
  }

  Map<String, dynamic> toJson() => {
    'idle': idle.toJson(),
    'on_task': onTask.toJson(),
    'max_batch_size': maxBatchSize,
    'max_buffered_points': maxBufferedPoints,
    'heartbeat_ms': heartbeat.inMilliseconds,
    'max_retry_delay_ms': maxRetryDelay.inMilliseconds,
  };

  @override
  bool operator ==(Object other) =>
      other is TrackingConfig &&
      other.idle == idle &&
      other.onTask == onTask &&
      other.maxBatchSize == maxBatchSize &&
      other.maxBufferedPoints == maxBufferedPoints &&
      other.heartbeat == heartbeat &&
      other.maxRetryDelay == maxRetryDelay;

  @override
  int get hashCode => Object.hash(
    idle,
    onTask,
    maxBatchSize,
    maxBufferedPoints,
    heartbeat,
    maxRetryDelay,
  );
}
