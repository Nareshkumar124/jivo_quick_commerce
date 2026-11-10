import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        PatchedRiderProfileUpdateRequest,
        RiderRegisterRequest,
        VehicleTypeEnum;

import '../helpers/fake_http.dart';

/// api-request #38: OpenAPI `format: date` goes out as `YYYY-MM-DD`
/// (packages/tool/patch_dates.py), and still parses on the way in.
void main() {
  RiderRegisterRequest register(DateTime dob) => RiderRegisterRequest(
    fullName: 'Ravi Kumar',
    dob: dob,
    emergencyContactName: 'Sita',
    emergencyContactPhone: '+919811122233',
    preferredStoreId: 1,
    vehicleType: VehicleTypeEnum.BICYCLE,
  );

  test('a required date field is sent as YYYY-MM-DD', () {
    expect(register(DateTime(1998, 4, 2)).toJson()['dob'], '1998-04-02');
    // A UTC value late in the day keeps its own calendar date.
    expect(
      register(DateTime.utc(1998, 4, 2, 23, 30)).toJson()['dob'],
      '1998-04-02',
    );
    expect(register(DateTime(998, 1, 9)).toJson()['dob'], '0998-01-09');
  });

  test('an optional date field: YYYY-MM-DD, or left out when null', () {
    expect(
      PatchedRiderProfileUpdateRequest(dob: DateTime(2001, 12, 31)).toJson(),
      containsPair('dob', '2001-12-31'),
    );
    expect(
      PatchedRiderProfileUpdateRequest().toJson().containsKey('dob'),
      isFalse,
    );
  });

  test('a YYYY-MM-DD value still parses into the same date', () {
    final parsed = RiderRegisterRequest.fromJson({
      ...register(DateTime(1998, 4, 2)).toJson(),
    });
    expect(parsed.dob, DateTime(1998, 4, 2));
    expect(parsed.toJson()['dob'], '1998-04-02');
  });

  test('date query parameters are sent as YYYY-MM-DD', () async {
    final http = FakeHttp((_) => (200, <String, Object?>{}));
    try {
      await http.api().getRiderApi().riderEarnings(
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 4),
      );
    } catch (_) {
      // The empty body doesn't parse; only the request matters here.
    }
    final uri = http.requests.single.uri;
    expect(uri.queryParameters['from'], '2026-11-01');
    expect(uri.queryParameters['to'], '2026-11-04');
  });
}
