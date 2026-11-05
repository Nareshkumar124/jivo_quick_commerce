import 'dart:async';
import 'dart:math';

import 'backoff.dart';
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
/// - A failed upload keeps the points and retries after an exponential
///   backoff with jitter (the first retry within one upload interval, then up
///   to [TrackingConfig.maxRetryDelay]), so the buffer drains by itself once
///   the network is back ("flush on reconnect") without hammering a dead
///   link.
/// - Heartbeat: when nothing reached the server during a whole
///   [TrackingConfig.heartbeat] window (no fix indoors, GPS restarting), it
///   sends [LocationUploader.heartbeat], so the server does not auto-offline
///   a rider who is still online (10 min, 04 §2.3).
/// - [UploadTrackingStopped] (the server already ended the shift, or the
///   session is over) stops the tracker at once and calls `onServerStop`.
/// - Pure Dart: the GPS stream, uploader, storage and randomness are
///   injected.
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
    this._onServerStop,
    Random? random,
  }) : _random = random ?? Random();

  final PositionSource _source;
  final LocationBuffer _buffer;
  final LocationUploader _uploader;
  final Duration _resubscribeDelay;
  final DateTime Function() _now;
  final void Function(TrackerStats stats)? _onStats;

  /// Called once when the server stops tracking ([UploadTrackingStopped]).
  final void Function(String code)? _onServerStop;
  final Random _random;

  TrackingConfig _config;
  TrackingMode _mode;

  bool _running = false;
  bool _restored = false;
  StreamSubscription<LocationPoint>? _positions;
  int _generation = 0;
  Timer? _uploadTimer;
  Timer? _retryTimer;
  Timer? _heartbeatTimer;
  Timer? _resubscribeTimer;
  Future<void>? _flushing;
  Backoff? _backoff;

  /// Whether the server heard from us (upload or heartbeat) during the
  /// current heartbeat window.
  bool _contactInWindow = false;
  int _heartbeats = 0;
  String? _stoppedBy;

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

  /// The error code the server stopped tracking with, or null.
  String? get stoppedBy => _stoppedBy;

  /// Whether a backoff retry is pending.
  bool get retryPending => _retryTimer != null;

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
    consecutiveFailures: _backoff?.failures ?? 0,
    heartbeats: _heartbeats,
    stoppedBy: _stoppedBy,
  );

  /// Starts GPS updates and the upload timer. Restores points buffered by an
  /// earlier session first, so they are uploaded before new ones. Does
  /// nothing once the server has stopped tracking: a new tracker (a new
  /// shift) is needed.
  Future<void> start() async {
    if (_running || _stoppedBy != null) return;
    if (!_restored) {
      await _buffer.restore();
      _restored = true;
    }
    _running = true;
    _contactInWindow = false;
    _subscribe();
    _startUploadTimer();
    _startHeartbeatTimer();
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
    _retryTimer?.cancel();
    _retryTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    final positions = _positions;
    _positions = null;
    _emit();
    await positions?.cancel();
    if (flushTimeout != null && _stoppedBy == null) {
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
    final heartbeatChanged = config.heartbeat != _config.heartbeat;
    _config = config;
    _onIntervalsChanged(before);
    if (heartbeatChanged && _running) _startHeartbeatTimer();
    _emit();
  }

  /// Uploads buffered points in batches until the buffer is empty or an
  /// upload fails. Concurrent calls share one run. Ignores the backoff: use
  /// it for "send now" (going offline, the network just came back).
  Future<void> flush() => _flushing ??= _drain().whenComplete(() {
    _flushing = null;
  });

  /// The periodic upload tick. Skipped while a backoff retry is pending.
  void _onUploadTick() {
    if (_retryTimer != null) return;
    unawaited(flush());
  }

  Future<void> _drain() async {
    while (_stoppedBy == null) {
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
          _onContact();
          _applyServerSettings(result);
        case UploadRejected(:final code):
          await _buffer.acknowledge(batch);
          _rejected += batch.length;
          _lastUploadStatus = UploadStatus.rejected;
          _lastError = code;
          // The server answered: the link works and it heard from us.
          _onContact();
        case UploadRetryLater(:final reason, :final retryAfter):
          _lastUploadStatus = UploadStatus.retryLater;
          _lastError = reason?.toString();
          _scheduleRetry(retryAfter);
          _emit();
          return;
        case UploadTrackingStopped(:final code):
          await _serverStopped(code);
          return;
      }
      _emit();
    }
  }

  /// The server returns its current location settings with every answer,
  /// so a change made in the panel reaches riders already online.
  void _applyServerSettings(UploadAccepted result) {
    if (result.idleIntervals == null &&
        result.onTaskIntervals == null &&
        result.maxBatch == null) {
      return;
    }
    final next = _config.withServerIntervals(
      idle: result.idleIntervals,
      onTask: result.onTaskIntervals,
      maxBatchSize: result.maxBatch,
    );
    if (next != _config) updateConfig(next);
  }

  /// A successful exchange with the server: clears the backoff.
  void _onContact() {
    _contactInWindow = true;
    _backoff?.reset();
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// The backoff for the current upload interval. The first retry comes
  /// within one upload interval (jitter only shortens it), later ones back
  /// off to [TrackingConfig.maxRetryDelay].
  Backoff _ensureBackoff() {
    final initial = intervals.upload;
    final max = _config.maxRetryDelay > initial
        ? _config.maxRetryDelay
        : initial;
    final current = _backoff;
    if (current != null && current.initial == initial && current.max == max) {
      return current;
    }
    final fresh = Backoff(initial: initial, max: max, random: _random);
    for (var i = 0; i < (current?.failures ?? 0); i++) {
      fresh.fail();
    }
    return _backoff = fresh;
  }

  void _scheduleRetry(Duration? serverHint) {
    if (!_running) return;
    final delay = _ensureBackoff().fail(serverHint: serverHint);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!_running) return;
      // Nothing buffered: it was a heartbeat that failed.
      unawaited(_buffer.isEmpty ? _sendHeartbeat() : flush());
    });
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_config.heartbeat, (_) {
      final heardFrom = _contactInWindow;
      _contactInWindow = false;
      if (heardFrom || !_running) return;
      // Points waiting: the next upload (or its retry) is the heartbeat.
      if (_buffer.isNotEmpty || _retryTimer != null) return;
      unawaited(_sendHeartbeat());
    });
  }

  Future<void> _sendHeartbeat() async {
    if (!_running || _stoppedBy != null) return;
    UploadResult result;
    try {
      result = await _uploader.heartbeat(lastKnown: _lastPoint);
    } catch (error) {
      result = UploadRetryLater(error);
    }
    if (!_running) return;
    switch (result) {
      case UploadAccepted():
        _heartbeats++;
        _onContact();
        _applyServerSettings(result);
      case UploadRejected():
        _heartbeats++;
        _onContact();
      case UploadRetryLater(:final reason, :final retryAfter):
        _lastError = reason?.toString();
        _scheduleRetry(retryAfter);
      case UploadTrackingStopped(:final code):
        await _serverStopped(code);
        return;
    }
    _emit();
  }

  Future<void> _serverStopped(String code) async {
    if (_stoppedBy != null) return;
    _stoppedBy = code;
    _lastError = code;
    await stop();
    _onServerStop?.call(code);
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
    _uploadTimer = Timer.periodic(intervals.upload, (_) => _onUploadTick());
  }

  void _emit() => _onStats?.call(stats);
}
