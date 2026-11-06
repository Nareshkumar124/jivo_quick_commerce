import 'package:jivo_core/jivo_core.dart';

import '../../../shared/fake_api_endpoint.dart';
import '../../../shared/paging.dart';
import '../domain/inbox.dart';

/// The inbox in `FAKE_API` builds and tests (dev flavor only).
class FakeInboxBackend extends FakeApiEndpoint implements InboxRepository {
  FakeInboxBackend({
    required DateTime Function() clock,
    super.delay = const Duration(milliseconds: 300),
    super.pageSize = 20,
    List<InboxEntry>? entries,
  }) : entries = entries ?? _seed(clock().toUtc());

  /// Newest first.
  final List<InboxEntry> entries;

  static List<InboxEntry> _seed(DateTime now) => [
    InboxEntry(
      id: 3,
      title: 'Order ready for pickup',
      body: 'JQ-1003 is packed at Jivo Sector 14.',
      category: 'order',
      read: false,
      createdAt: now.subtract(const Duration(minutes: 5)),
    ),
    InboxEntry(
      id: 2,
      title: 'Payout sent',
      body: 'Your weekly payout was transferred.',
      category: 'system',
      read: false,
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    InboxEntry(
      id: 1,
      title: 'Welcome to Jivo Rider',
      body: 'Go online to start receiving orders.',
      category: 'system',
      read: true,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Future<Page<InboxEntry>> fetchPage({int? page}) async {
    await recordCall('inbox ${page ?? 1}');
    return pageOf(List.of(entries), page ?? 1);
  }

  @override
  Future<InboxEntry> markRead(int id) async {
    await recordCall('read $id');
    final index = entries.indexWhere((e) => e.id == id);
    if (index < 0) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    return entries[index] = entries[index].asRead();
  }

  @override
  Future<int> markAllRead() async {
    await recordCall('read-all');
    var updated = 0;
    for (var i = 0; i < entries.length; i++) {
      if (!entries[i].read) {
        entries[i] = entries[i].asRead();
        updated++;
      }
    }
    return updated;
  }
}
