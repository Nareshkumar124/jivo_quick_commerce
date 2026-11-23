import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/data/api_location_uploader.dart';
import 'package:rider_app/features/location/domain/location_point.dart';
import 'package:rider_app/features/location/domain/location_uploader.dart';

import '../../../helpers/canned_http.dart';

const _locations = '/api/v1/rider/locations/';
const _heartbeat = '/api/v1/rider/heartbeat/';

final _point = LocationPoint(
  lat: 28.5706,
  lng: 77.3261,
  accuracy: 6,
  speed: 4.2,
  recordedAt: DateTime.utc(2026, 11, 4, 10, 0, 5),
  isMocked: false,
);

/// POST /rider/locations/ and /rider/heartbeat/ (P5 slice 5.2).
void main() {
  late CannedAdapter http;
  late ApiLocationUploader uploader;

  setUp(() {
    http = CannedAdapter();
    uploader = ApiLocationUploader(cannedApi(http));
  });

  test(
    'a batch is sent as {points: [...]} and the server periods come back',
    () async {
      http.answers[_locations] = const Canned(201, {
        'accepted': 1,
        'duplicates': 0,
        'rejected': 0,
        'rejected_reasons': noRejectReasons,
        'out_of_order': 0,
        'low_accuracy': 0,
        'active_task_id': null,
        'location': locationSettingsJson,
        'server_time': '2026-11-04T10:00:06Z',
      });

      final result = await uploader.upload([_point]);

      final points = http.jsonBody(_locations)['points'] as List;
      final first = points.single as Map<String, dynamic>;
      expect(first['lat'], 28.5706);
      expect(first['accuracy'], 6);
      expect(first['is_mocked'], false);
      expect(DateTime.parse('${first['recorded_at']}').isUtc, isTrue);

      expect(result, isA<UploadAccepted>());
      final accepted = result as UploadAccepted;
      expect(accepted.onTaskIntervals!.sample, const Duration(seconds: 5));
      expect(accepted.onTaskIntervals!.upload, const Duration(seconds: 10));
      expect(accepted.idleIntervals!.sample, const Duration(seconds: 20));
      expect(accepted.maxBatch, 40);
    },
  );

  test('409 RIDER_OFFLINE stops tracking', () async {
    http.answers[_locations] = Canned(409, errorBody('RIDER_OFFLINE'));
    final result = await uploader.upload([_point]);
    expect(
      result,
      isA<UploadTrackingStopped>().having(
        (r) => r.code,
        'code',
        'RIDER_OFFLINE',
      ),
    );
  });

  test('403 (rider not ACTIVE) stops tracking', () async {
    http.answers[_locations] = Canned(
      403,
      errorBody('PERMISSION_DENIED', {'rider_status': 'SUSPENDED'}),
    );
    expect(await uploader.upload([_point]), isA<UploadTrackingStopped>());
  });

  test('400 VALIDATION_ERROR drops the batch', () async {
    http.answers[_locations] = Canned(400, errorBody('VALIDATION_ERROR'));
    expect(
      await uploader.upload([_point]),
      isA<UploadRejected>().having((r) => r.code, 'code', 'VALIDATION_ERROR'),
    );
  });

  test('no network, 5xx and maintenance keep the points', () async {
    http.answers[_locations] = const Canned.offline();
    expect(await uploader.upload([_point]), isA<UploadRetryLater>());

    http.answers[_locations] = Canned(500, errorBody('SERVER_ERROR'));
    expect(await uploader.upload([_point]), isA<UploadRetryLater>());

    http.answers[_locations] = Canned(503, errorBody('MAINTENANCE'));
    expect(await uploader.upload([_point]), isA<UploadRetryLater>());
  });

  test(
    'heartbeat: online carries the periods; offline stops tracking',
    () async {
      http.answers[_heartbeat] = const Canned(200, {
        'is_online': true,
        'pending_offer_id': null,
        'active_task_id': null,
        'shift': null,
        'location': locationSettingsJson,
        'server_time': '2026-11-04T10:00:06Z',
      });
      expect(
        await uploader.heartbeat(lastKnown: _point),
        isA<UploadAccepted>(),
      );

      http.answers[_heartbeat] = const Canned(200, {
        'is_online': false,
        'pending_offer_id': null,
        'active_task_id': null,
        'shift': {
          'id': 4,
          'started_at': '2026-11-04T08:00:00Z',
          'ended_at': '2026-11-04T09:50:00Z',
          'end_reason': 'AUTO_OFFLINE',
          'ended_by': 'system',
        },
        'location': locationSettingsJson,
        'server_time': '2026-11-04T10:00:06Z',
      });
      expect(await uploader.heartbeat(), isA<UploadTrackingStopped>());
    },
  );

  group('T-821 live tracking', () {
    Map<String, Object?> result({
      int accepted = 1,
      int rejected = 0,
      int outOfOrder = 0,
      int lowAccuracy = 0,
      int? activeTaskId,
    }) => {
      'accepted': accepted,
      'duplicates': 0,
      'rejected': rejected,
      'rejected_reasons': {...noRejectReasons, 'implausible_jump': rejected},
      'out_of_order': outOfOrder,
      'low_accuracy': lowAccuracy,
      'active_task_id': activeTaskId,
      'location': locationSettingsJson,
      'server_time': '2026-11-04T10:00:06Z',
    };

    test('a ping carries heading, speed, accuracy, recorded_at and the '
        'task id', () async {
      http.answers[_locations] = Canned(201, result(activeTaskId: 7001));
      final point = LocationPoint(
        lat: 28.5706,
        lng: 77.3261,
        accuracy: 8.5,
        speed: 6.1,
        heading: 271.5,
        recordedAt: DateTime.utc(2026, 11, 4, 10, 0, 5),
      );

      final answer = await uploader.upload([point], taskId: 7001);

      final body = http.jsonBody(_locations);
      expect(body['task_id'], 7001);
      final sent = (body['points'] as List).single as Map<String, dynamic>;
      expect(sent['lat'], 28.5706);
      expect(sent['lng'], 77.3261);
      expect(sent['accuracy'], 8.5);
      expect(sent['speed'], 6.1);
      expect(sent['heading'], 271.5);
      expect(sent['recorded_at'], '2026-11-04T10:00:05.000Z');
      final accepted = answer as UploadAccepted;
      expect(accepted.reportsActiveTask, isTrue);
      expect(accepted.activeTaskId, 7001);
    });

    test('idle: no task id is sent', () async {
      http.answers[_locations] = Canned(201, result());
      await uploader.upload([_point]);
      expect(http.jsonBody(_locations)['task_id'], isNull);
    });

    test('values the contract refuses are sent as unknown, so one bad fix '
        'does not drop the batch', () {
      final sent = ApiLocationUploader.point(
        LocationPoint(
          lat: 28.5,
          lng: 77.2,
          accuracy: -1,
          speed: -1,
          heading: 360,
          recordedAt: DateTime.utc(2026, 11, 4),
        ),
      );
      expect(sent.accuracy, ApiLocationUploader.unknownAccuracyMeters);
      expect(sent.speed, isNull);
      expect(sent.heading, 0);
      final noHeading = ApiLocationUploader.point(
        LocationPoint(
          lat: 28.5,
          lng: 77.2,
          heading: -1,
          recordedAt: DateTime.utc(2026, 11, 4),
        ),
      );
      expect(noHeading.heading, isNull);
    });

    test('an unknown or invalid accuracy is never sent as precise', () {
      for (final accuracy in [null, -1.0, double.nan, double.infinity]) {
        final sent = ApiLocationUploader.point(
          LocationPoint(
            lat: 28.5,
            lng: 77.2,
            accuracy: accuracy,
            recordedAt: DateTime.utc(2026, 11, 4),
          ),
        );
        expect(sent.accuracy, 9999, reason: 'accuracy $accuracy');
        expect(sent.accuracy, greaterThan(300));
      }
      final zero = ApiLocationUploader.point(
        LocationPoint(
          lat: 28.5,
          lng: 77.2,
          accuracy: 0,
          recordedAt: DateTime.utc(2026, 11, 4),
        ),
      );
      expect(zero.accuracy, 0);
    });

    test('dropped, out-of-order and low-accuracy counts come back', () async {
      http.answers[_locations] = Canned(
        201,
        result(accepted: 3, rejected: 2, outOfOrder: 1, lowAccuracy: 1),
      );
      final answer = await uploader.upload([
        _point,
        _point,
        _point,
        _point,
        _point,
      ]) as UploadAccepted;
      expect(answer.dropped, 2);
      expect(answer.outOfOrder, 1);
      expect(answer.lowAccuracy, 1);
    });

    test('the heartbeat reports the server task too', () async {
      http.answers[_heartbeat] = const Canned(200, {
        'is_online': true,
        'pending_offer_id': null,
        'active_task_id': 7001,
        'shift': null,
        'location': locationSettingsJson,
        'server_time': '2026-11-04T10:00:06Z',
      });
      final beat = await uploader.heartbeat() as UploadAccepted;
      expect(beat.reportsActiveTask, isTrue);
      expect(beat.activeTaskId, 7001);
    });
  });
}
