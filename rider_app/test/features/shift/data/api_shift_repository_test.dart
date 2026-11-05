import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/shift/data/api_shift_repository.dart';
import 'package:rider_app/features/shift/data/api_today_summary.dart';
import 'package:rider_app/features/shift/domain/shift_repository.dart';
import 'package:rider_app/features/shift/presentation/shift_controller.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';

import '../../../helpers/canned_http.dart';

const _start = '/api/v1/rider/shift/start/';
const _end = '/api/v1/rider/shift/end/';
const _heartbeat = '/api/v1/rider/heartbeat/';

Map<String, Object?> _shiftState({
  bool online = true,
  bool prepaidOnly = false,
  Map<String, Object?>? shift,
}) => {
  'is_online': online,
  'shift': shift,
  'prepaid_only': prepaidOnly,
  'cash': {
    'cash_in_hand': '5200.00',
    'cash_limit': '5000.00',
    'limit_reached': prepaidOnly,
  },
  'location': locationSettingsJson,
  'server_time': '2026-11-04T10:00:00Z',
};

/// `rider_shift_start/end`, `rider_heartbeat` and `GET /rider/me/` today.
void main() {
  late CannedAdapter http;
  late ApiShiftRepository repo;

  setUp(() {
    http = CannedAdapter();
    repo = ApiShiftRepository(cannedApi(http));
  });

  test(
    'start sends {lat, lng} and returns the periods and prepaid_only',
    () async {
      http.answers[_start] = Canned(200, _shiftState(prepaidOnly: true));
      final started = await repo.start(const GeoPoint(28.57, 77.32));

      final body = http.jsonBody(_start);
      expect(body['lat'], 28.57);
      expect(body['lng'], 77.32);
      expect(started.prepaidOnly, isTrue);
      expect(started.onTaskIntervals!.sample, const Duration(seconds: 5));
      expect(started.idleIntervals!.upload, const Duration(seconds: 30));
      expect(started.maxBatch, 40);
    },
  );

  test('a refusal keeps details.reason for the guard card', () async {
    http.answers[_start] = Canned(
      422,
      errorBody('OUTSIDE_GEOFENCE', {
        'reason': 'TOO_FAR_FROM_STORE',
        'distance_m': 3400,
        'radius_m': 2000,
      }),
    );
    final error = await repo
        .start(const GeoPoint(28.57, 77.32))
        .then<ApiError?>((_) => null, onError: (Object e) => e as ApiError);
    expect(error!.code, ApiErrorCode.outsideGeofence);
    expect(ShiftRefusal.of(error), ShiftRefusal.tooFarFromStore);
    expect(error.details['distance_m'], 3400);

    http.answers[_start] = Canned(
      409,
      errorBody('INVALID_STATE_TRANSITION', {
        'reason': 'DOCUMENTS_NOT_APPROVED',
        'doc_types': ['DL'],
      }),
    );
    final docs = await repo
        .start(const GeoPoint(28.57, 77.32))
        .then<ApiError?>((_) => null, onError: (Object e) => e as ApiError);
    expect(ShiftRefusal.of(docs), ShiftRefusal.documentsNotApproved);
  });

  test('end posts shift/end', () async {
    http.answers[_end] = Canned(200, _shiftState(online: false));
    await repo.end();
    expect(http.requests.single.path, _end);
  });

  test('status: auto-offline is ended_by system', () async {
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
    final status = await repo.status();
    expect(status.isOnline, isFalse);
    expect(status.endedBy, ShiftEndedBy.system);
  });

  test(
    'GET /rider/me/: today, cash and home store for the home tiles',
    () async {
      http.answers['/api/v1/rider/me/'] = Canned(200, _riderMe);
      final summary = await ApiTodaySummary(cannedApi(http)).fetch();
      expect(summary.deliveredCount, 6);
      expect(summary.earnedToday, '640.00');
      expect(summary.onlineSeconds, 11100);
      expect(summary.cashInHand, '1840.00');
      expect(summary.limitReached, isFalse);
      expect(summary.homeStoreName, 'Sector 18');
    },
  );
}

const _riderMe = {
  'id': 3,
  'phone': '+919811122231',
  'status': 'ACTIVE',
  'rejection_reason': '',
  'suspension_reason': '',
  'full_name': 'Ravi Kumar',
  'dob': '1998-04-02',
  'emergency_contact_name': 'Sita',
  'emergency_contact_phone': '+919811100000',
  'vehicle_type': 'MOTORBIKE',
  'vehicle_number': 'DL01AB1234',
  'preferred_store': {'id': 1, 'name': 'Sector 18', 'city': 'Noida'},
  'home_store': {'id': 1, 'name': 'Sector 18', 'city': 'Noida'},
  'photo_url': null,
  'photo_url_expires_at': null,
  'rating_avg': null,
  'documents': <Object>[],
  'required_documents': <Object>[],
  'missing_documents': <Object>[],
  'bank_account': null,
  'ready_for_review': false,
  'is_online': false,
  'cash': {
    'cash_in_hand': '1840.00',
    'cash_limit': '5000.00',
    'limit_reached': false,
  },
  'today': {
    'date': '2026-11-04',
    'orders_delivered': 6,
    'earnings': '640.00',
    'cash_in_hand': '1840.00',
    'online_seconds': 11100,
  },
  'created_at': '2026-11-01T10:00:00Z',
};
