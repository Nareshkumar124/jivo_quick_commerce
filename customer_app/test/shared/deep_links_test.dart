import 'package:customer_app/shared/links/deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hosts = {'jivo.in'};
  String? loc(String link, {bool tracking = false}) => deepLinkLocation(
    Uri.parse(link),
    trackingAvailable: tracking,
    allowedHosts: hosts,
  );

  test('orders open tracking when available, else the detail', () {
    expect(loc('jivo://orders/12'), '/orders/12');
    expect(loc('jivo://orders/12', tracking: true), '/orders/12/track');
    expect(
      loc('https://jivo.in/orders/12', tracking: true),
      '/orders/12/track',
    );
    expect(loc('jivo://orders/12/detail', tracking: true), '/orders/12');
    expect(loc('jivo://orders'), '/account/orders');
  });

  test('catalog, inbox, cart and home links', () {
    expect(loc('jivo://product/jivo-canola-oil'), '/product/jivo-canola-oil');
    expect(loc('jivo://collection/offers'), '/collection/offers');
    expect(loc('https://jivo.in/category/ghee'), '/category/ghee');
    expect(loc('jivo://notifications'), '/account/notifications');
    expect(loc('jivo://cart'), '/home/cart');
    expect(loc('jivo://home'), '/home');
  });

  test('anything else is ignored', () {
    expect(loc('jivo://orders/abc'), isNull);
    expect(loc('jivo://orders/0'), isNull);
    expect(loc('jivo://product/Bad Slug'), isNull);
    expect(loc('http://jivo.in/orders/1'), isNull);
    expect(loc('jivo://unknown/1'), isNull);
    expect(loc('jivo://'), isNull);
  });

  test('FCM payloads: link, or type with id/slug', () {
    expect(
      notificationLocation({
        'link': 'jivo://orders/5',
      }, trackingAvailable: true),
      '/orders/5/track',
    );
    expect(notificationLocation({'type': 'order', 'order_id': 5}), '/orders/5');
    expect(
      notificationLocation({'type': 'product', 'slug': 'jivo-ghee'}),
      '/product/jivo-ghee',
    );
    expect(notificationLocation({'type': 'promo'}), isNull);
    expect(notificationLocation({'type': 'collection'}), isNull);
  });

  test('https only for allowed App Links hosts', () {
    expect(loc('https://evil.example/orders/12'), isNull);
    expect(loc('https://JIVO.in/orders/12'), '/orders/12');
    // The build default is empty until APP_LINK_HOSTS is configured.
    expect(appLinkHosts, isEmpty);
    expect(deepLinkLocation(Uri.parse('https://jivo.in/orders/12')), isNull);
    expect(deepLinkLocation(Uri.parse('jivo://orders/12')), '/orders/12');
    expect(parseAppLinkHosts(' jivo.in, Shop.Jivo.in ,,'), {
      'jivo.in',
      'shop.jivo.in',
    });
    expect(parseAppLinkHosts(''), isEmpty);
  });

  test('ids are plain positive digits only', () {
    expect(loc('jivo://orders/+5'), isNull);
    expect(loc('jivo://orders/5%2Fdetail'), isNull);
    expect(loc('jivo://orders/%35'), '/orders/5');
    expect(loc('jivo://orders/05'), isNull);
    expect(loc('jivo://orders/1234567890123456789'), isNull);
    expect(
      notificationLocation({'type': 'order', 'order_id': '5/detail'}),
      isNull,
    );
    expect(notificationLocation({'type': 'order', 'order_id': '+5'}), isNull);
    expect(
      notificationLocation({'type': 'order', 'order_id': '5'}),
      '/orders/5',
    );
    expect(
      notificationLocation({
        'link': 'https://evil.example/orders/5',
      }, allowedHosts: hosts),
      isNull,
    );
  });
}
