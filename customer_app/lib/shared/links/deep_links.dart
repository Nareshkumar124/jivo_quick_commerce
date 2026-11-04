import '../../app/redirect.dart';

/// Where a deep link opens (`03 §2.12`: notification taps open order
/// tracking, a product or a collection). Accepts `jivo://<path>` and
/// `https://<any host>/<path>` with these paths:
///
/// - `orders/<id>`: the order's tracking, or its detail when tracking isn't
///   available in this build ([trackingAvailable])
/// - `orders/<id>/detail`: the order detail
/// - `product/<slug>`, `collection/<slug>`, `category/<slug>`
/// - `orders`, `notifications`, `cart`, `home`
///
/// Returns null for anything else (the caller stays where it is).
String? deepLinkLocation(Uri uri, {bool trackingAvailable = false}) {
  if (uri.scheme != 'jivo' && uri.scheme != 'https') return null;
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
}) {
  final link = data['link'];
  if (link is String) {
    final uri = Uri.tryParse(link);
    if (uri != null) {
      return deepLinkLocation(uri, trackingAvailable: trackingAvailable);
    }
  }
  final type = data['type'];
  final orderId = data['order_id'];
  final slug = data['slug'];
  final path = switch (type) {
    'order' when orderId != null => 'orders/$orderId',
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

int? _id(String value) {
  final id = int.tryParse(value);
  return id == null || id <= 0 ? null : id;
}
