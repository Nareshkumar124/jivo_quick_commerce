import 'package:flutter/foundation.dart';

import '../../../shared/paging.dart';

/// One in-app inbox entry (`GET /me/notifications/`, 06 §3): the rider
/// app's entries only (the server scopes by the token's `app` claim).
@immutable
class InboxEntry {
  const InboxEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.read,
    required this.createdAt,
    this.link,
  });

  final int id;
  final String title;
  final String body;

  /// The server's category wire value (shown as an icon; unknown values
  /// get the generic one).
  final String category;

  /// `jivo://...` or null.
  final String? link;
  final bool read;
  final DateTime createdAt;

  InboxEntry asRead() => InboxEntry(
    id: id,
    title: title,
    body: body,
    category: category,
    read: true,
    createdAt: createdAt,
    link: link,
  );
}

/// The inbox endpoints. Every method throws jivo_core's `ApiError`.
abstract interface class InboxRepository {
  /// Newest first, page-numbered ([page] from 1).
  Future<Page<InboxEntry>> fetchPage({int? page});

  /// `POST /me/notifications/{id}/read/`: the entry as now stored.
  Future<InboxEntry> markRead(int id);

  /// `POST /me/notifications/read-all/`: how many were unread.
  Future<int> markAllRead();

  /// `GET /me/notifications/unread-count/` (`me_notifications_unread_count`,
  /// api-requests #45/#50): every unread entry of the rider app.
  Future<int> fetchUnreadCount();
}

/// The home bell's badge. [count] is the server's unread count (P8; the
/// home badge uses it). [of] counts the unread entries of a page and shows
/// "N+" when the whole page is unread and more pages exist (kept for a
/// list on screen).
@immutable
class InboxBadge {
  const InboxBadge({required this.unread, required this.more});

  /// The server's unread count.
  factory InboxBadge.count(int unread) =>
      InboxBadge(unread: unread < 0 ? 0 : unread, more: false);

  static const none = InboxBadge(unread: 0, more: false);

  final int unread;

  /// There may be more unread entries than [unread].
  final bool more;

  bool get isEmpty => unread == 0;

  static InboxBadge of(Page<InboxEntry> firstPage) {
    final unread = firstPage.items.where((e) => !e.read).length;
    return InboxBadge(
      unread: unread,
      more: firstPage.hasMore && unread > 0 && unread == firstPage.items.length,
    );
  }

  /// "3", "9+", "20+".
  String get label => unread > 9 ? '9+' : (more ? '$unread+' : '$unread');
}
