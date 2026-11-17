import 'dart:convert';

/// The rider app's Android push channels (D-19, 04 §2.10). Their ids are
/// part of the contract with the backend: an FCM message names one in
/// `android.notification.channel_id`; a message that names none goes to
/// [RiderPushChannel.general] (the manifest's
/// `default_notification_channel_id`).
///
/// Two other channels exist and are not push channels: the location
/// service's "You're online" channel (`rider_online`, owned by the
/// foreground service) and the in-app offer alarm (`offer_alerts_v1`, alarm
/// stream, full-screen intent; [OfferAlertNotifications]). Push never
/// touches either.
///
/// A channel's importance can't be changed once it exists on a device: to
/// change it, add a channel with a new id.
enum RiderPushChannel {
  /// `offer.new` (and its end): max importance, sound and vibration,
  /// heads-up, shown on the lock screen.
  offers('offers'),

  /// Task updates (`task.updated`: assigned, packed, amount changed,
  /// cancelled, return to store): high importance.
  orders('orders'),

  /// Cash (`cash.updated`), payouts, support replies and anything else:
  /// default importance.
  general('general');

  const RiderPushChannel(this.id);

  final String id;

  static RiderPushChannel? byId(String? id) {
    for (final channel in values) {
      if (channel.id == id) return channel;
    }
    return null;
  }
}

/// The user-visible channel names (Android system settings), from l10n.
typedef RiderPushChannelTexts = ({
  String offersName,
  String offersDescription,
  String ordersName,
  String ordersDescription,
  String generalName,
  String generalDescription,
});

extension RiderPushChannelNames on RiderPushChannelTexts {
  String nameOf(RiderPushChannel channel) => switch (channel) {
    RiderPushChannel.offers => offersName,
    RiderPushChannel.orders => ordersName,
    RiderPushChannel.general => generalName,
  };

  String descriptionOf(RiderPushChannel channel) => switch (channel) {
    RiderPushChannel.offers => offersDescription,
    RiderPushChannel.orders => ordersDescription,
    RiderPushChannel.general => generalDescription,
  };
}

/// A push received while the app runs (foreground) or in the background
/// isolate.
class IncomingPush {
  const IncomingPush({
    this.messageId,
    this.title,
    this.body,
    this.androidChannelId,
    this.data = const {},
  });

  final String? messageId;

  /// The `notification` part; both null for a data-only message.
  final String? title;
  final String? body;

  /// `android.notification.channel_id` as the server sent it.
  final String? androidChannelId;

  /// The FCM `data` part (06 §4.3): `type` plus `offer_id` / `task_id` /
  /// `ticket_id`, and possibly `link` (`jivo://rider/...`).
  final Map<String, String> data;

  /// Whether there is anything to show (data-only messages have no text).
  bool get hasText =>
      (title?.isNotEmpty ?? false) || (body?.isNotEmpty ?? false);

  String? get type => data['type'];

  /// `offer.new`, `offer.withdrawn`, `offer.expired`.
  bool get isOffer => type?.startsWith('offer.') ?? false;
}

/// The channel a push is shown on: the one the server named, else by the
/// payload type (`offer.*` [RiderPushChannel.offers], `task.updated`
/// [RiderPushChannel.orders], everything else [RiderPushChannel.general]).
RiderPushChannel channelForPush(IncomingPush push) {
  final named = RiderPushChannel.byId(push.androidChannelId);
  if (named != null) return named;
  if (push.isOffer) return RiderPushChannel.offers;
  if (push.type == 'task.updated') return RiderPushChannel.orders;
  final link = push.data['link'];
  if (link != null && link.startsWith('jivo://rider/task')) {
    return RiderPushChannel.orders;
  }
  return RiderPushChannel.general;
}

/// Payloads of local push notifications start with this, so a tap is told
/// apart from the offer alarm's `offer:<id>` payload (both go through the
/// one flutter_local_notifications callback).
const pushPayloadPrefix = 'push:';

/// The local notification's payload: the FCM data as JSON, so a tap routes
/// exactly like a tap on the system notification.
String encodePushPayload(Map<String, String> data) =>
    '$pushPayloadPrefix${jsonEncode(data)}';

/// The data map back from [encodePushPayload]; null for anything else
/// (an offer alarm payload, garbage).
Map<String, String>? decodePushPayload(String? payload) {
  if (payload == null || !payload.startsWith(pushPayloadPrefix)) return null;
  try {
    final decoded = jsonDecode(payload.substring(pushPayloadPrefix.length));
    if (decoded is Map) {
      return {
        for (final e in decoded.entries)
          if (e.value != null) '${e.key}': '${e.value}',
      };
    }
  } on FormatException {
    // Not ours.
  }
  return null;
}

/// A stable notification id per message, so a repeat of the same message
/// replaces the shown one instead of stacking. Always >= 2^30, so it never
/// collides with the app's fixed ids (location service 4201, offer alarm
/// 9001/9002).
int notificationIdFor(IncomingPush push) {
  final key = push.messageId ?? jsonEncode(push.data);
  // Fowler–Noll–Vo (32-bit), stable across runs unlike String.hashCode.
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return (hash & 0x3fffffff) | 0x40000000;
}
