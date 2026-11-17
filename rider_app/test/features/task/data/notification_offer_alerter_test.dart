import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/offers/data/offer_alert_notifications.dart';
import 'package:rider_app/features/offers/domain/delivery_offer.dart';
import 'package:rider_app/features/task/data/platform_task_services.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/shared/platform/device_channel.dart';

/// Records the notification calls instead of posting them.
class _FakeAlerts extends OfferAlertNotifications {
  final calls = <String>[];

  @override
  Future<void> showOffer({
    required int offerId,
    required String title,
    required String body,
    required String channelName,
    required Duration timeout,
  }) async => calls.add('show:$offerId');

  @override
  Future<void> cancelOffer() async => calls.add('cancel');

  @override
  Future<void> dismiss({
    int id = OfferAlertNotifications.testNotificationId,
  }) async => calls.add('dismiss:$id');
}

class _FakeDevice extends DeviceChannel {
  _FakeDevice(this.calls);

  final List<String> calls;

  @override
  Future<void> startOfferRinging() async => calls.add('ring-in-app');

  @override
  Future<void> stopOfferRinging() async => calls.add('stop-in-app');
}

// Device test 2026-11-17: the heads-up covered the offer screen.
void main() {
  late _FakeAlerts alerts;
  late NotificationOfferAlerter alerter;
  final offer = DeliveryOffer(
    id: 7,
    storeName: 'Jivo Sector 18',
    dropLocality: 'Sector 21',
    distanceKm: '2.4',
    paymentType: PaymentType.prepaid,
    estimatedPayout: '45.00',
    expiresAt: DateTime.utc(2026, 11, 17, 6),
  );

  setUp(() {
    alerts = _FakeAlerts();
    alerter = NotificationOfferAlerter(
      alerts,
      channelName: 'Offers',
      device: _FakeDevice(alerts.calls),
    );
  });

  Future<void> ring({required bool inForeground}) => alerter.ring(
    offer,
    title: 'New order',
    body: 'body',
    timeout: const Duration(seconds: 20),
    inForeground: inForeground,
  );

  test('offer screen in front: no heads-up (removed if posted), rings in '
      'the app', () async {
    await ring(inForeground: true);
    expect(alerts.calls, ['cancel', 'ring-in-app']);
  });

  test(
    'app hidden: the high-priority notification, in-app ring stopped',
    () async {
      await ring(inForeground: false);
      expect(alerts.calls, ['stop-in-app', 'show:7']);
    },
  );

  test('stop ends both', () async {
    await alerter.stop();
    expect(alerts.calls, [
      'stop-in-app',
      'dismiss:${OfferAlertNotifications.offerNotificationId}',
    ]);
  });
}
