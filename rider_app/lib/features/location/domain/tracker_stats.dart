import 'package:flutter/foundation.dart';

import 'location_point.dart';
import 'tracking_config.dart';

enum UploadStatus { none, accepted, retryLater, rejected }

/// Snapshot of the tracker, sent from the service isolate to the UI as JSON
/// (isolates can only exchange primitives, lists and maps).
@immutable
class TrackerStats {
  const TrackerStats({
    required this.running,
    required this.mode,
    required this.intervals,
    required this.buffered,
    required this.uploaded,
    required this.rejected,
    required this.droppedOverflow,
    this.serverDropped = 0,
    this.historyOnly = 0,
    this.taskId,
    this.lastPoint,
    this.lastUploadAt,
    this.lastUploadStatus = UploadStatus.none,
    this.lastError,
    this.consecutiveFailures = 0,
    this.heartbeats = 0,
    this.stoppedBy,
  });

  factory TrackerStats.fromJson(Map<String, dynamic> json) => TrackerStats(
    running: json['running'] as bool,
    mode: TrackingMode.values.byName(json['mode'] as String),
    intervals: TrackingIntervals.fromJson(
      (json['intervals'] as Map).cast<String, dynamic>(),
    ),
    buffered: json['buffered'] as int,
    uploaded: json['uploaded'] as int,
    rejected: json['rejected'] as int,
    droppedOverflow: json['dropped_overflow'] as int,
    serverDropped: json['server_dropped'] as int? ?? 0,
    historyOnly: json['history_only'] as int? ?? 0,
    taskId: json['task_id'] as int?,
    lastPoint: json['last_point'] == null
        ? null
        : LocationPoint.fromJson(
            (json['last_point'] as Map).cast<String, dynamic>(),
          ),
    lastUploadAt: json['last_upload_at'] == null
        ? null
        : DateTime.parse(json['last_upload_at'] as String),
    lastUploadStatus: UploadStatus.values.byName(
      json['last_upload_status'] as String,
    ),
    lastError: json['last_error'] as String?,
    consecutiveFailures: json['consecutive_failures'] as int? ?? 0,
    heartbeats: json['heartbeats'] as int? ?? 0,
    stoppedBy: json['stopped_by'] as String?,
  );

  final bool running;
  final TrackingMode mode;
  final TrackingIntervals intervals;

  /// Points waiting for upload.
  final int buffered;

  /// Points the server accepted, this session.
  final int uploaded;

  /// Points dropped because the server rejected their batch.
  final int rejected;

  /// Points dropped because the offline buffer was full.
  final int droppedOverflow;

  /// Points the server dropped from accepted batches (`rejected`: too old,
  /// in the future, (0, 0), a GPS jump). Never resent.
  final int serverDropped;

  /// Points the server kept as history only (`out_of_order`,
  /// `low_accuracy`): they do not move the rider on the maps.
  final int historyOnly;

  /// The task sent with the batches, or null when idle.
  final int? taskId;

  final LocationPoint? lastPoint;
  final DateTime? lastUploadAt;
  final UploadStatus lastUploadStatus;
  final String? lastError;

  /// Failed uploads in a row (the backoff level). 0 when the link is fine.
  final int consecutiveFailures;

  /// Heartbeats the server accepted, this session.
  final int heartbeats;

  /// The error code the server stopped tracking with (for example
  /// `RIDER_OFFLINE` after an auto-offline), or null.
  final String? stoppedBy;

  Map<String, dynamic> toJson() => {
    'running': running,
    'mode': mode.name,
    'intervals': intervals.toJson(),
    'buffered': buffered,
    'uploaded': uploaded,
    'rejected': rejected,
    'dropped_overflow': droppedOverflow,
    'server_dropped': serverDropped,
    'history_only': historyOnly,
    'task_id': taskId,
    'last_point': lastPoint?.toJson(),
    'last_upload_at': lastUploadAt?.toUtc().toIso8601String(),
    'last_upload_status': lastUploadStatus.name,
    'last_error': lastError,
    'consecutive_failures': consecutiveFailures,
    'heartbeats': heartbeats,
    'stopped_by': stoppedBy,
  };
}
