import 'dart:convert';

/// The Android notification channels (`03 §2.12`). Their ids are part of
/// the contract with the backend: an FCM message names one in
/// `android.notification.channel_id`; a message that names none goes to
/// [PushChannel.general] (the manifest's
/// `default_notification_channel_id`).
///
/// A channel's importance can't be changed once it exists on a device:
/// to change it, add a channel with a new id.
enum PushChannel {
  /// Order status, delivery (with the OTP) and support replies: high
  /// importance (sound and heads-up).
  orders('orders'),

  /// Offers, new products and anything else: default importance.
  general('general');

  const PushChannel(this.id);

  final String id;

  static PushChannel? byId(String? id) {
    for (final channel in values) {
      if (channel.id == id) return channel;
    }
    return null;
  }
}

/// The user-visible channel names (Android system settings), from l10n.
typedef PushChannelTexts = ({
  String ordersName,
  String ordersDescription,
  String generalName,
  String generalDescription,
});

/// A push received while the app is in the foreground.
class IncomingPush {
  const IncomingPush({
    this.messageId,
    this.title,
    this.body,
    this.androidChannelId,
    this.data = const {},
  });

  final String? messageId;
  final String? title;
  final String? body;

  /// `android.notification.channel_id` as the server sent it.
  final String? androidChannelId;

  /// The FCM `data` part (`06 §4.3`): `type` + `order_id` / `ticket_id` /
  /// `slug`, or `link`.
  final Map<String, Object?> data;

  /// Whether there is anything to show (data-only messages have no text).
  bool get hasText =>
      (title?.isNotEmpty ?? false) || (body?.isNotEmpty ?? false);
}

/// The channel a foreground push is shown on: the one the server named,
/// else by the payload (orders and support replies are [PushChannel.orders],
/// everything else [PushChannel.general]).
PushChannel channelFor(IncomingPush push) {
  final named = PushChannel.byId(push.androidChannelId);
  if (named != null) return named;
  final type = push.data['type'];
  if (type == 'order' || type == 'ticket') return PushChannel.orders;
  final link = push.data['link'];
  if (link is String &&
      (link.startsWith('jivo://orders') || link.startsWith('jivo://support'))) {
    return PushChannel.orders;
  }
  return PushChannel.general;
}

/// The local notification's payload: the FCM data as JSON, so a tap routes
/// exactly like a tap on the system notification.
String encodePushPayload(Map<String, Object?> data) => jsonEncode({
  for (final entry in data.entries)
    if (entry.value != null) entry.key: '${entry.value}',
});

/// The data map back from [encodePushPayload]; null for anything else.
Map<String, Object?>? decodePushPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      return {for (final e in decoded.entries) '${e.key}': e.value};
    }
  } on FormatException {
    // Not ours.
  }
  return null;
}

/// A stable, positive notification id per message, so a repeat of the
/// same message replaces the shown one instead of stacking.
int notificationIdFor(IncomingPush push) {
  final key = push.messageId ?? encodePushPayload(push.data);
  // Fowler–Noll–Vo (32-bit), stable across runs unlike String.hashCode.
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
