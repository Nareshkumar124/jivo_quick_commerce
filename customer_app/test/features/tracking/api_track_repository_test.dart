import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/domain/order_track.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../../helpers/fake_http.dart';
import '../../helpers/test_config.dart';

/// `GET /orders/{id}/track/` (P5) against the contract's own examples.
void main() {
  Future<(FakeHttp, Object)> fetch(String example, {int id = 1203}) async {
    final key = 'orders_track/$example';
    final status = int.parse(key.split('/')[1]);
    final http = FakeHttp((_) => (status, contractExample(key)));
    try {
      return (http, await ApiTrackRepository(http.api()).fetch(id));
    } catch (error) {
      return (http, error);
    }
  }

  test('accepted, no rider yet: no rider, no OTP', () async {
    final (http, result) = await fetch('200/Accepted,NoRiderYet');
    expect(http.requests.single.path, '/api/v1/orders/1203/track/');
    expect(http.requests.single.method, 'GET');
    final track = result as OrderTrack;
    expect(track.orderId, 1203);
    expect(track.orderNumber, 'JV-261110-001203');
    expect(track.status, OrderStatus.accepted);
    expect(track.storeName, 'Jivo Sector 14');
    expect(track.store.lat, 28.4718);
    expect(track.destination.lng, 77.0688);
    expect(track.etaAt, DateTime.utc(2026, 11, 10, 9, 58));
    expect(track.rider, isNull);
    expect(track.deliveryOtp, isNull);
  });

  test('rider heading to the store: rider shown, still no OTP', () async {
    final (_, result) = await fetch('200/RiderHeadingToTheStore');
    final track = result as OrderTrack;
    expect(track.rider, isNotNull);
    expect(track.rider!.name, 'Ravi K.');
    // DL-56: the phone is sent only while OUT_FOR_DELIVERY.
    expect(track.rider!.phone, isNull);
    expect(track.deliveryOtp, isNull);
  });

  test('out for delivery: rider with signed https photo, location, OTP',
      () async {
    final (_, result) = await fetch('200/OutForDelivery(OTPShown)');
    final track = result as OrderTrack;
    expect(track.status, OrderStatus.outForDelivery);
    expect(track.deliveryOtp, '4821');
    expect(track.rider!.name, 'Ravi K.');
    expect(track.rider!.phone, '+919811122233');
    expect(Uri.parse(track.rider!.photoUrl!).scheme, 'https');
    expect(track.rider!.location!.lat, 28.489);
    expect(track.rider!.updatedAt, DateTime.utc(2026, 11, 10, 9, 44, 55));
    expect(track.progress, greaterThan(0));
  });

  test('delivered: no OTP; polling stops (status not active)', () async {
    final (_, result) = await fetch('200/Delivered');
    final track = result as OrderTrack;
    expect(track.status, OrderStatus.delivered);
    expect(track.deliveryOtp, isNull);
    expect(track.status.isActive, isFalse);
  });

  test("another user's order is NOT_FOUND", () async {
    final (_, result) = await fetch('404/NOTFOUND');
    expect(
      result,
      isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
    );
  });

  test('a non-https photo and a blank OTP are dropped', () async {
    final body =
        Map<String, Object?>.from(
            contractExample('orders_track/200/OutForDelivery(OTPShown)')!
                as Map,
          )
          ..['delivery_otp'] = '  '
          ..['rider'] = {
            ...(contractExample('orders_track/200/OutForDelivery(OTPShown)')!
                    as Map)['rider']
                as Map,
            'photo': 'http://insecure.example/p.jpg',
            'lat': null,
            'lng': null,
          };
    final http = FakeHttp((_) => (200, body));
    final track = await ApiTrackRepository(http.api()).fetch(1203);
    expect(track.deliveryOtp, isNull);
    expect(track.rider!.photoUrl, isNull);
    expect(track.rider!.location, isNull);
  });

  test('providers: tracking is on wherever orders are (dev), on the API',
      () {
    ProviderContainer make({required bool cart}) => ProviderContainer(
      overrides: [
        appEnvProvider.overrideWithValue(testEnv),
        jivoApiProvider.overrideWithValue(FakeHttp((_) => (200, null)).api()),
        cartAvailableProvider.overrideWithValue(cart),
      ],
    );
    final dev = make(cart: true);
    addTearDown(dev.dispose);
    expect(dev.read(trackingAvailableProvider), isTrue);
    expect(dev.read(trackRepositoryProvider), isA<ApiTrackRepository>());

    final staging = make(cart: false);
    addTearDown(staging.dispose);
    expect(staging.read(trackingAvailableProvider), isFalse);
    expect(
      staging.read(trackRepositoryProvider),
      isA<UnavailableTrackRepository>(),
    );
  });
}
