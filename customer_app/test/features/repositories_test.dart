import 'package:customer_app/features/addresses/data/address_repository.dart';
import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/domain/auth_models.dart';
import 'package:customer_app/features/profile/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../helpers/fake_http.dart';

final meJson = {
  'id': 7,
  'phone': '+919000000002',
  'name': '',
  'email': null,
  'is_profile_complete': false,
  'rider_status': 'NONE',
  'created_at': '2026-11-02T10:15:00Z',
};

final addressJson = {
  'id': 3,
  'label': 'home',
  'custom_label': '',
  'receiver_name': 'Asha',
  'receiver_phone': '+919000000002',
  'house': 'Flat 4B',
  'building_street': 'MG Road',
  'landmark': '',
  'area': null,
  'city': 'New Delhi',
  'state': 'Delhi',
  'pincode': '110001',
  'lat': 28.613939,
  'lng': 77.209023,
  'is_default': true,
  'created_at': '2026-11-02T10:15:00Z',
  'updated_at': '2026-11-02T10:15:00Z',
};

void main() {
  test('verify sends the consent version and maps the session', () async {
    final http = FakeHttp(
      (_) => (
        200,
        {
          'access': 'a',
          'refresh': 'r',
          'user': meJson,
          'is_new_user': true,
          'rider_status': 'NONE',
          'deletion_cancelled': true,
        },
      ),
    );

    final result = await ApiAuthRepository(http.api()).verifyOtp(
      phone: '+919000000002',
      otp: '123456',
      termsVersion: '2026-11-01',
    );

    expect(http.requests.single.path, '/api/v1/auth/otp/verify/');
    expect(http.body(0), {
      'phone': '+919000000002',
      'otp': '123456',
      'app': 'customer',
      'terms_version': '2026-11-01',
    });
    expect(result.tokens, const AuthTokens(access: 'a', refresh: 'r'));
    expect(result.needsProfile, isTrue);
    expect(result.deletionCancelled, isTrue);
  });

  test(
    'OTP requests carry the purpose; errors become ApiError with details',
    () async {
      final http = FakeHttp(
        (_) => (
          429,
          {
            'error': {
              'code': 'OTP_RATE_LIMITED',
              'message': 'x',
              'details': {'retry_after_seconds': 540},
            },
          },
        ),
      );

      final error = await ApiAuthRepository(http.api())
          .requestOtp('+919000000002', purpose: OtpPurpose.deleteAccount)
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(http.body(0), {
        'phone': '+919000000002',
        'app': 'customer',
        'purpose': 'delete_account',
      });
      expect(
        error,
        isA<ApiError>().having((e) => e.retryAfterSeconds, 'retryAfter', 540),
      );
    },
  );

  test('profile update sends an empty string to remove the email', () async {
    final http = FakeHttp(
      (_) => (200, {...meJson, 'name': 'Asha', 'is_profile_complete': true}),
    );

    final user = await ApiProfileRepository(http.api())
        .updateProfile(name: ' Asha ', email: null);

    expect(http.requests.single.method, 'PATCH');
    expect(http.body(0), {'name': 'Asha', 'email': ''});
    expect(user.isProfileComplete, isTrue);
    expect(user.email, isNull);
  });

  test(
    'addresses: coordinates rounded to 6 places, cleared fields sent as empty',
    () async {
      final http = FakeHttp((_) => (200, addressJson));
      const input = AddressInput(
        label: AddressLabel.home,
        house: 'Flat 4B',
        buildingStreet: 'MG Road',
        city: 'New Delhi',
        state: 'Delhi',
        pincode: '110001',
        lat: 28.61393912345,
        lng: 77.2090236,
      );

      final created = await ApiAddressRepository(http.api()).create(input);
      await ApiAddressRepository(http.api()).update(3, input);

      final create = http.body(0);
      expect((create['lat'], create['lng']), (28.613939, 77.209024));
      expect(
        create.containsKey('landmark'),
        isFalse,
        reason: 'unset optional fields are omitted on create',
      );
      final patch = http.body(1);
      expect(http.requests[1].method, 'PATCH');
      expect(
        patch['landmark'],
        '',
        reason: 'a cleared landmark is removed on update',
      );
      expect(created.isDefault, isTrue);
      expect(
        created.input.landmark,
        isNull,
        reason: 'blank strings map to null',
      );
    },
  );

  test('logout sends the refresh token', () async {
    final http = FakeHttp((_) => (204, null));

    await ApiAuthRepository(http.api()).logout('r1');

    expect(http.requests.single.path, '/api/v1/auth/logout/');
    expect(http.body(0), {'refresh': 'r1'});
  });
}
