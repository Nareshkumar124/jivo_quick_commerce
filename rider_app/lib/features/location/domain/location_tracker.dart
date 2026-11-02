import 'dart:async';

import 'location_buffer.dart';
import 'location_point.dart';
import 'location_uploader.dart';
import 'position_source.dart';
import 'tracker_stats.dart';
import 'tracking_config.dart';

DateTime _utcNow() => DateTime.now().toUtc();

/// Online location tracking: GPS fixes go into a [LocationBuffer] and are
/// POSTed in batches on a timer (04 §3).
///
/// - Runs only between [start] and [stop]. The service calls [start] when the
///   rider goes online and [stop] when they go offline; after [stop] no
///   further fix is recorded.
/// - Sample and upload intervals depend on [TrackingMode] and can be replaced
///   by the server's values.
/// - A failed upload keeps the points; every later tick retries, so the
///   buffer drains by itself once the network is back ("flush on reconnect").
/// - Pure Dart: the GPS stream, uploader and storage are injected.
class LocationTracker {
  LocationTracker({
    required this._source,
    required this._buffer,
    required this._uploader,
    this._config = const TrackingConfig(),
    this._mode = TrackingMode.idle,
    this._resubscribeDelay = const Duration(seconds: 10),
    this._now = _utcNow,
    this._onStats,
  });

  final PositionSource _source;
  final LocationBuffer _buffer;
  final LocationUploader _uploader;
  final Duration _resubscribeDelay;
  final DateTime Function() _now;
  final void Function(TrackerStats stats)? _onStats;

  TrackingConfig _config;
  TrackingMode _mode;

  bool _running = false;
  bool _restored = false;
  StreamSubscription<LocationPoint>? _positions;
  int _generation = 0;
  Timer? _uploadTimer;
  Timer? _resubscribeTimer;
  Future<void>? _flushing;

  int _uploaded = 0;
  int _rejected = 0;
  LocationPoint? _lastPoint;
  DateTime? _lastUploadAt;
  UploadStatus _lastUploadStatus = UploadStatus.none;
  String? _lastError;

  bool get isRunning => _running;
  TrackingMode get mode => _mode;
  TrackingConfig get config => _config;
  TrackingIntervals get intervals => _config.intervalsFor(_mode);

  TrackerStats get stats => TrackerStats(
    running: _running,
    mode: _mode,
    intervals: intervals,
    buffered: _buffer.length,
    uploaded: _uploaded,
    rejected: _rejected,
    droppedOverflow: _buffer.droppedOverflow,
    lastPoint: _lastPoint,
    lastUploadAt: _lastUploadAt,
    lastUploadStatus: _lastUploadStatus,
    lastError: _lastError,
  );

  /// Starts GPS updates and the upload timer. Restores points buffered by an
  /// earlier session first, so they are uploaded before new ones.
  Future<void> start() async {
    if (_running) return;
    if (!_restored) {
      await _buffer.restore();
      _restored = true;
    }
    _running = true;
    _subscribe();
    _startUploadTimer();
    _emit();
  }

  /// Stops GPS updates immediately. Buffered points stay persisted for the
  /// next online session. With [flushTimeout], first tries one last upload of
  /// the points recorded while online, bounded by that timeout.
  Future<void> stop({Duration? flushTimeout}) async {
    if (!_running) return;
    _running = false;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _uploadTimer?.cancel();
    _uploadTimer = null;
    final positions = _positions;
    _positions = null;
    _emit();
    await positions?.cancel();
    if (flushTimeout != null) {
      await flush().timeout(flushTimeout, onTimeout: () {});
    }
    await _buffer.settle();
  }

  /// Switches between idle and on-task intervals.
  void setMode(TrackingMode mode) {
    if (mode == _mode) return;
    final before = intervals;
    _mode = mode;
    _onIntervalsChanged(before);
    _emit();
  }

  /// Replaces the configuration, for example with the server's intervals.
  void updateConfig(TrackingConfig config) {
    final before = intervals;
    _config = config;
    _onIntervalsChanged(before);
    _emit();
  }

  /// Uploads buffered points in batches until the buffer is empty or an upload
  /// fails. Concurrent calls share one run.
  Future<void> flush() => _flushing ??= _drain().whenComplete(() {
    _flushing = null;
  });

  Future<void> _drain() async {
    while (true) {
      final batch = _buffer.peekBatch(_config.maxBatchSize);
      if (batch == null) return;

      UploadResult result;
      try {
        result = await _uploader.upload(batch.points);
      } catch (error) {
        result = UploadRetryLater(error);
      }
      _lastUploadAt = _now();

      switch (result) {
        case UploadAccepted():
          await _buffer.acknowledge(batch);
          _uploaded += batch.length;
          _lastUploadStatus = UploadStatus.accepted;
          _lastError = null;
          if (result.idleIntervals != null || result.onTaskIntervals != null) {
            updateConfig(
              _config.withServerIntervals(
                idle: result.idleIntervals,
                onTask: result.onTaskIntervals,
              ),
            );
          }
        case UploadRejected(:final code):
          await _buffer.acknowledge(batch);
          _rejected += batch.length;
          _lastUploadStatus = UploadStatus.rejected;
          _lastError = code;
        case UploadRetryLater(:final reason):
          _lastUploadStatus = UploadStatus.retryLater;
          _lastError = reason?.toString();
          _emit();
          return;
      }
      _emit();
    }
  }

  void _onIntervalsChanged(TrackingIntervals before) {
    if (!_running || intervals == before) return;
    if (intervals.sample != before.sample) _resubscribeNow();
    if (intervals.upload != before.upload) _startUploadTimer();
  }

  /// Cancels the current GPS stream, then subscribes with the new interval.
  /// Waits for the cancel: geolocator shares one platform stream and only
  /// applies new settings once the old one is cancelled.
  void _resubscribeNow() {
    final old = _positions;
    _positions = null;
    final generation = ++_generation;
    final cancelled = old?.cancel() ?? Future<void>.value();
    unawaited(
      cancelled.then((_) {
        if (_running && generation == _generation && _positions == null) {
          _subscribe();
        }
      }),
    );
  }

  void _subscribe() {
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _positions = _source
        .positions(intervals)
        .listen(
          _onPoint,
          onError: _onSourceError,
          onDone: _onSourceDone,
          cancelOnError: true,
        );
  }

  void _onPoint(LocationPoint point) {
    if (!_running) return;
    _lastPoint = point;
    unawaited(_buffer.add(point));
    _emit();
  }

  void _onSourceError(Object error) {
    _positions = null;
    _lastError = error.toString();
    _scheduleResubscribe();
    _emit();
  }

  void _onSourceDone() {
    _positions = null;
    _scheduleResubscribe();
  }

  void _scheduleResubscribe() {
    if (!_running) return;
    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(_resubscribeDelay, () {
      if (_running && _positions == null) _subscribe();
    });
  }

  void _startUploadTimer() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(intervals.upload, (_) => unawaited(flush()));
  }

  void _emit() => _onStats?.call(stats);
}
