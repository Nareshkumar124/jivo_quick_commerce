import '../../app/redirect.dart';

/// The App Links hosts this build trusts for `https` deep links, from
/// `--dart-define=APP_LINK_HOSTS=host1,host2`. Empty by default (the
/// domain isn't decided yet), so every `https` link is rejected and only
/// `jivo://` links work.
final Set<String> appLinkHosts = parseAppLinkHosts(
  const String.fromEnvironment('APP_LINK_HOSTS'),
);

/// `"a.in, B.in,"` → `{a.in, b.in}`.
Set<String> parseAppLinkHosts(String value) => {
  for (final host in value.split(','))
    if (host.trim().isNotEmpty) host.trim().toLowerCase(),
};

/// Where a deep link opens (`03 §2.12`: notification taps open order
/// tracking, a product or a collection). Accepts `jivo://<path>` and
/// `https://<host>/<path>` for a host in [allowedHosts] (default
/// [appLinkHosts]), with these paths:
///
/// - `orders/<id>`: the order's tracking, or its detail when tracking isn't
///   available in this build ([trackingAvailable])
/// - `orders/<id>/detail`: the order detail
/// - `product/<slug>`, `collection/<slug>`, `category/<slug>`
/// - `orders`, `notifications`, `cart`, `home`
///
/// Returns null for anything else (the caller stays where it is).
String? deepLinkLocation(
  Uri uri, {
  bool trackingAvailable = false,
  Set<String>? allowedHosts,
}) {
  switch (uri.scheme) {
    case 'jivo':
      break;
    case 'https':
      final hosts = allowedHosts ?? appLinkHosts;
      if (uri.host.isEmpty || !hosts.contains(uri.host.toLowerCase())) {
        return null;
      }
    default:
      return null;
  }
  // `jivo://orders/12`: "orders" is the host; `https://jivo.in/orders/12`:
  // it is the first path segment.
  final segments = [
    if (uri.scheme == 'jivo' && uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((s) => s.isNotEmpty),
  ];
  if (segments.isEmpty) return null;
  final slug = RegExp(r'^[a-z0-9][a-z0-9-]*$');

  switch (segments) {
    case ['orders']:
      return Routes.orders;
    case ['notifications']:
      return Routes.notifications;
    case ['cart']:
      return Routes.cart;
    case ['home']:
      return Routes.home;
    case ['orders', final id]:
      final orderId = _id(id);
      if (orderId == null) return null;
      return trackingAvailable
          ? Routes.orderTracking(orderId)
          : Routes.order(orderId);
    case ['orders', final id, 'detail']:
      final orderId = _id(id);
      return orderId == null ? null : Routes.order(orderId);
    case ['product', final s] when slug.hasMatch(s):
      return Routes.product(s);
    case ['collection', final s] when slug.hasMatch(s):
      return Routes.collection(s);
    case ['category', final s] when slug.hasMatch(s):
      return Routes.category(s);
  }
  return null;
}

/// The location for an FCM data payload (`type` + `order_id` / `slug`), as
/// sent from Phase 6 (`08 §9`).
String? notificationLocation(
  Map<String, Object?> data, {
  bool trackingAvailable = false,
  Set<String>? allowedHosts,
}) {
  final link = data['link'];
  if (link is String) {
    final uri = Uri.tryParse(link);
    if (uri != null) {
      return deepLinkLocation(
        uri,
        trackingAvailable: trackingAvailable,
        allowedHosts: allowedHosts,
      );
    }
  }
  final type = data['type'];
  final orderId = data['order_id'];
  final slug = data['slug'];
  final path = switch (type) {
    'order' when orderId != null && _id('$orderId') != null =>
      'orders/$orderId',
    'product' ||
    'collection' ||
    'category' when slug is String => '$type/$slug',
    _ => null,
  };
  return path == null
      ? null
      : deepLinkLocation(
          Uri.parse('jivo://$path'),
          trackingAvailable: trackingAvailable,
        );
}

/// A positive id in plain digits only (no sign, spaces or encoded
/// separators).
final _idPattern = RegExp(r'^[1-9][0-9]{0,17}$');

int? _id(String value) => _idPattern.hasMatch(value) ? int.parse(value) : null;
