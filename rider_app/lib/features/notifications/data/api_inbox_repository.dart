import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' show InboxNotification, JivoApi;
import 'package:jivo_core/jivo_core.dart';

import '../../../shared/paging.dart';
import '../domain/inbox.dart';

/// The inbox through the generated client (`me_notifications_*`, P6).
class ApiInboxRepository implements InboxRepository {
  ApiInboxRepository(this._api);

  final JivoApi _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<Page<InboxEntry>> fetchPage({int? page}) => _call(() async {
    final body = (await _api.getNotificationsApi().meNotificationsList(
      page: page,
    )).data!;
    return Page(
      items: [for (final entry in body.results) inboxEntryOf(entry)],
      nextPage: pageOfNext(body.next),
      count: body.count,
    );
  });

  @override
  Future<InboxEntry> markRead(int id) => _call(
    () async => inboxEntryOf(
      (await _api.getNotificationsApi().meNotificationsRead(id: id)).data!,
    ),
  );

  @override
  Future<int> markAllRead() => _call(
    () async => (await _api.getNotificationsApi().meNotificationsReadAll())
        .data!
        .updated,
  );
}

InboxEntry inboxEntryOf(InboxNotification entry) => InboxEntry(
  id: entry.id,
  title: entry.title,
  body: entry.body,
  category: entry.category.value,
  link: entry.link,
  read: entry.read,
  createdAt: entry.createdAt,
);
