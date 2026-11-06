import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jivo_api/jivo_api.dart' as api show InboxNotification, JivoApi;
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

/// The notification inbox (`GET /me/notifications/`, `06 §2.2`), scoped
/// by the server to this user and the customer app.
abstract interface class NotificationRepository {
  Future<InboxPage> list({int page = 1});

  Future<void> markRead(int id);

  /// Marks every entry read; returns how many changed.
  Future<int> markAllRead();
}

/// `me_notifications_list`, `me_notifications_read`,
/// `me_notifications_read_all`. Another user's id is 404.
class ApiNotificationRepository implements NotificationRepository {
  const ApiNotificationRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<InboxPage> list({int page = 1}) async {
    try {
      final result = (await _api.getNotificationsApi().meNotificationsList(
        page: page,
      )).data!;
      return InboxPage(
        items: [for (final n in result.results) inboxNotificationFromApi(n)],
        nextPage: result.next == null ? null : page + 1,
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<void> markRead(int id) async {
    try {
      await _api.getNotificationsApi().meNotificationsRead(id: id);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<int> markAllRead() async {
    try {
      final result = await _api.getNotificationsApi().meNotificationsReadAll();
      return result.data?.updated ?? 0;
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// Maps the generated entry. Only a `jivo://` link is kept (anything else
/// is never followed).
InboxNotification inboxNotificationFromApi(api.InboxNotification n) {
  final link = n.link == null ? null : Uri.tryParse(n.link!.trim());
  return InboxNotification(
    id: n.id,
    title: n.title,
    body: n.body,
    createdAt: n.createdAt,
    read: n.read,
    link: link != null && link.scheme == 'jivo' ? link : null,
  );
}

/// The build without an inbox: empty.
class UnavailableNotificationRepository implements NotificationRepository {
  const UnavailableNotificationRepository();

  @override
  Future<InboxPage> list({int page = 1}) async => const InboxPage(items: []);

  @override
  Future<void> markRead(int id) async {}

  @override
  Future<int> markAllRead() async => 0;
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

  @override
  Future<int> markAllRead() async {
    _maybeFail();
    var updated = 0;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].markedRead();
        updated++;
      }
    }
    return updated;
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
