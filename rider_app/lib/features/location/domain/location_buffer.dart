import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'location_point.dart';
import 'point_store.dart';

/// A slice of the buffer handed to the uploader. Pass it back to
/// [LocationBuffer.acknowledge] once the server has taken it.
@immutable
class BufferedBatch {
  const BufferedBatch._(this.points, this._lastSeq);

  final List<LocationPoint> points;
  final int _lastSeq;

  int get length => points.length;
}

class _Entry {
  const _Entry(this.seq, this.point);

  final int seq;
  final LocationPoint point;
}

/// FIFO buffer of location points waiting for upload (04 §3: "points are
/// buffered offline and flushed on reconnect").
///
/// - Oldest first, so the server receives points in `recorded_at` order.
/// - Capped at [maxPoints]. When full, the **oldest** points are dropped.
/// - Persisted through a [PointStore]. Adding a point appends to the store;
///   acknowledging a batch rewrites it. The store is compacted when it holds
///   more than twice [maxPoints] lines, so a long offline spell costs one
///   append per fix, not a full rewrite.
///
/// Memory is the source of truth. A failed store write is retried as a full
/// rewrite on the next change; it never stops tracking.
class LocationBuffer {
  LocationBuffer({required this._store, required this.maxPoints})
    : assert(maxPoints > 0);

  final PointStore _store;
  final int maxPoints;

  final _entries = ListQueue<_Entry>();
  int _nextSeq = 0;

  /// Lines in the store since its last full rewrite.
  int _storedLines = 0;
  bool _storeDirty = false;
  Future<void> _storeQueue = Future.value();

  /// Points dropped because the buffer was full, since this buffer was created.
  int droppedOverflow = 0;

  /// The last persistence error, for diagnostics.
  Object? lastStoreError;

  int get length => _entries.length;
  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Snapshot of the buffered points, oldest first.
  List<LocationPoint> get points =>
      List.unmodifiable(_entries.map((e) => e.point));

  /// Loads points persisted by an earlier session (for example, the service
  /// was killed while offline). Call once, before [add].
  Future<void> restore() async {
    final stored = await _store.load();
    final keepFrom = stored.length > maxPoints ? stored.length - maxPoints : 0;
    droppedOverflow += keepFrom;
    for (final point in stored.skip(keepFrom)) {
      _entries.add(_Entry(_nextSeq++, point));
    }
    _storedLines = stored.length;
    if (keepFrom > 0) await _rewrite();
  }

  /// Appends [point], dropping the oldest points if the buffer is full.
  Future<void> add(LocationPoint point) {
    _entries.add(_Entry(_nextSeq++, point));
    while (_entries.length > maxPoints) {
      _entries.removeFirst();
      droppedOverflow++;
    }
    if (_storeDirty || _storedLines + 1 > 2 * maxPoints) return _rewrite();
    _storedLines++;
    return _enqueue(() => _store.append([point]));
  }

  /// The oldest [maxSize] points, or null if the buffer is empty. The points
  /// stay in the buffer until [acknowledge] is called.
  BufferedBatch? peekBatch(int maxSize) {
    if (_entries.isEmpty) return null;
    final entries = _entries.take(maxSize).toList(growable: false);
    return BufferedBatch._(
      List.unmodifiable(entries.map((e) => e.point)),
      entries.last.seq,
    );
  }

  /// Removes [batch] after the server has accepted (or permanently rejected)
  /// it. Safe if points were added, or old ones dropped for space, while the
  /// upload was in flight.
  Future<void> acknowledge(BufferedBatch batch) {
    var removed = 0;
    while (_entries.isNotEmpty && _entries.first.seq <= batch._lastSeq) {
      _entries.removeFirst();
      removed++;
    }
    return removed > 0 ? _rewrite() : _storeQueue;
  }

  /// Waits until every pending store write has finished.
  Future<void> settle() => _storeQueue;

  Future<void> _rewrite() {
    // Snapshot now, so queued writes apply in call order.
    final snapshot = _entries.map((e) => e.point).toList(growable: false);
    _storedLines = snapshot.length;
    _storeDirty = false;
    return _enqueue(() => _store.replaceAll(snapshot));
  }

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _storeQueue.then((_) => op()).catchError((Object error) {
      lastStoreError = error;
      _storeDirty = true;
      debugPrint('LocationBuffer: store write failed: $error');
    });
    _storeQueue = next;
    return next;
  }
}
