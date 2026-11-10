import 'package:jivo_core/jivo_core.dart';

import '../../task/domain/rider_task.dart';
import '../domain/shift_repository.dart';

/// The shift API for `FAKE_API` builds and tests. Accepts every call unless
/// a test sets [nextStartError] / [nextEndError].
class FakeShiftBackend implements ShiftRepository {
  FakeShiftBackend({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  /// Whether the fake server thinks the rider is online.
  bool online = false;

  /// Who ended the last shift, for [status] (e.g. `system` = auto-offline).
  ShiftEndedBy? endedBy;

  /// Thrown (once) by the next [start] / [end].
  ApiError? nextStartError;
  ApiError? nextEndError;

  /// Calls, for tests: `start(lat,lng)`, `end` and `status`.
  final calls = <String>[];

  /// What [start] answers.
  ShiftStart startResponse = const ShiftStart();

  /// The server ends the shift by itself (10 min without location).
  void autoOffline() {
    online = false;
    endedBy = ShiftEndedBy.system;
  }

  @override
  Future<ShiftStart> start(GeoPoint at, {double? accuracy}) async {
    calls.add('start(${at.lat},${at.lng})');
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = nextStartError;
    if (error != null) {
      nextStartError = null;
      throw error;
    }
    online = true;
    endedBy = null;
    return startResponse;
  }

  @override
  Future<void> end() async {
    calls.add('end');
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = nextEndError;
    if (error != null) {
      nextEndError = null;
      throw error;
    }
    online = false;
    endedBy = ShiftEndedBy.rider;
  }

  @override
  Future<ShiftStatus> status() async {
    calls.add('status');
    return ShiftStatus(isOnline: online, endedBy: online ? null : endedBy);
  }
}

/// Builds without the rider work screens: every call fails with
/// `NOT_FOUND`. Never reached, because the toggle is only shown where they
/// run.
class UnavailableShiftRepository implements ShiftRepository {
  const UnavailableShiftRepository();

  static const _error = ApiError(code: ApiErrorCode.notFound, statusCode: 404);

  @override
  Future<ShiftStart> start(GeoPoint at, {double? accuracy}) async =>
      throw _error;

  @override
  Future<void> end() async => throw _error;

  @override
  Future<ShiftStatus> status() async => throw _error;
}
