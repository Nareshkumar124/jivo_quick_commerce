import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offer_alert_notifications.dart';

final offerAlertNotificationsProvider = Provider<OfferAlertNotifications>(
  (ref) => OfferAlertNotifications(),
);
