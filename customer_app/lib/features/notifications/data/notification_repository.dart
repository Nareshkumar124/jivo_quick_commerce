import 'package:flutter/foundation.dart';
import 'package:jivo_core/jivo_core.dart';

/// An inbox entry (`03 §2.11`, `§2.12`; the Phase 6 inbox endpoints).
@immutable
class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.link,
  });

  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// Where a tap goes (`jivo://orders/123`, `jivo://product/<slug>`, …);
  /// see `deepLinkLocation`.
  final Uri? link;

  InboxNotification markedRead() => InboxNotification(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    read: true,
    link: link,
  );
}

@immutable
class InboxPage {
  const InboxPage({required this.items, this.nextPage});

  final List<InboxNotification> items;
  final int? nextPage;
}

/// The notification inbox. TODO(api): the inbox endpoints are Phase 6
/// (`06 §2`, not in jivo_api yet); the screen runs on
/// [FakeNotificationRepository] until then.
abstract interface class NotificationRepository {
  Future<InboxPage> list({int page = 1});

  Future<void> markRead(int id);
}

/// The real-API build until the Phase 6 inbox exists: an empty inbox.
class UnavailableNotificationRepository implements NotificationRepository {
  const UnavailableNotificationRepository();

  @override
  Future<InboxPage> list({int page = 1}) async => const InboxPage(items: []);

  @override
  Future<void> markRead(int id) async {}
}

/// Demo inbox (`FAKE_API=true` and tests).
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({
    List<InboxNotification>? items,
    this.pageSize = 20,
  }) : _items = items ?? _demo(DateTime.now().toUtc());

  final List<InboxNotification> _items;
  final int pageSize;

  /// When set, the next call throws it once.
  Object? failNext;

  final List<int> readCalls = [];

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<InboxPage> list({int page = 1}) async {
    _maybeFail();
    final start = (page - 1) * pageSize;
    if (start > _items.length) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    final end = (start + pageSize).clamp(0, _items.length);
    return InboxPage(
      items: _items.sublist(start, end),
      nextPage: end < _items.length ? page + 1 : null,
    );
  }

  @override
  Future<void> markRead(int id) async {
    _maybeFail();
    readCalls.add(id);
    final i = _items.indexWhere((n) => n.id == id);
    if (i >= 0) _items[i] = _items[i].markedRead();
  }

  static List<InboxNotification> _demo(DateTime now) => [
    InboxNotification(
      id: 3,
      title: 'Your order is on the way',
      body: 'Ravi is bringing order JV-261104-001003. Share OTP 4821 at the door.',
      createdAt: now.subtract(const Duration(minutes: 5)),
      link: Uri.parse('jivo://orders/1003'),
    ),
    InboxNotification(
      id: 2,
      title: 'Refund completed',
      body: '₹899 is back in your original payment method.',
      createdAt: now.subtract(const Duration(days: 1)),
      read: true,
      link: Uri.parse('jivo://orders/1002'),
    ),
    InboxNotification(
      id: 1,
      title: 'Up to 20% off on olive oils',
      body: 'Fresh offers on Jivo olive oils this week.',
      createdAt: now.subtract(const Duration(days: 2)),
      link: Uri.parse('jivo://collection/offers'),
    ),
  ];
}
