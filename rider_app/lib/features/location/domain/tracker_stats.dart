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
    this.lastPoint,
    this.lastUploadAt,
    this.lastUploadStatus = UploadStatus.none,
    this.lastError,
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

  final LocationPoint? lastPoint;
  final DateTime? lastUploadAt;
  final UploadStatus lastUploadStatus;
  final String? lastError;

  Map<String, dynamic> toJson() => {
    'running': running,
    'mode': mode.name,
    'intervals': intervals.toJson(),
    'buffered': buffered,
    'uploaded': uploaded,
    'rejected': rejected,
    'dropped_overflow': droppedOverflow,
    'last_point': lastPoint?.toJson(),
    'last_upload_at': lastUploadAt?.toUtc().toIso8601String(),
    'last_upload_status': lastUploadStatus.name,
    'last_error': lastError,
  };
}
