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
}
