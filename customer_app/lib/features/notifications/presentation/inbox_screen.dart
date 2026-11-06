import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/links/deep_links.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/notification_repository.dart';

/// The loaded inbox pages.
@immutable
class InboxState {
  const InboxState({
    this.items = const [],
    this.nextPage,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<InboxNotification> items;
  final int? nextPage;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextPage != null;

  bool get hasUnread => items.any((n) => !n.read);

  InboxState copyWith({
    List<InboxNotification>? items,
    int? nextPage,
    bool clearNextPage = false,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearError = false,
  }) => InboxState(
    items: items ?? this.items,
    nextPage: clearNextPage ? null : (nextPage ?? this.nextPage),
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
  );
}

/// The inbox (`/me/notifications/`, newest first) with infinite scroll,
/// mark one read and mark all read.
class InboxController extends AsyncNotifier<InboxState> {
  @override
  Future<InboxState> build() async {
    final first = await ref.read(notificationRepositoryProvider).list();
    return InboxState(items: first.items, nextPage: first.nextPage);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
    if (ref.mounted) ref.invalidate(inboxUnreadProvider);
  }

  /// Loads the next page, one at a time.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref
          .read(notificationRepositoryProvider)
          .list(page: current.nextPage!);
      if (!ref.mounted) return;
      final seen = {for (final n in current.items) n.id};
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            for (final n in page.items)
              if (!seen.contains(n.id)) n,
          ],
          nextPage: page.nextPage,
          clearNextPage: page.nextPage == null,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: error),
      );
    }
  }

  /// Marks [id] read here at once; the server call is best effort.
  Future<void> markRead(int id) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [for (final n in current.items) n.id == id ? n.markedRead() : n],
      ),
    );
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
    } catch (_) {
      // The next load shows the server's state.
    }
    if (ref.mounted) ref.invalidate(inboxUnreadProvider);
  }

  /// Marks everything read. Throws [ApiError] (the list is unchanged).
  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    if (!ref.mounted) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(
          items: [for (final n in current.items) n.read ? n : n.markedRead()],
        ),
      );
    }
    ref.invalidate(inboxUnreadProvider);
  }
}

final inboxProvider =
    AsyncNotifierProvider.autoDispose<InboxController, InboxState>(
      InboxController.new,
    );

/// Unread entries for the badge, counted on the first page only.
/// TODO(api): an `unread_count` on the list response would make this exact
/// (api-requests, T-613). Zero when the inbox can't be read: the badge is
/// never an error.
final inboxUnreadProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final first = await ref.read(notificationRepositoryProvider).list();
    return first.items.where((n) => !n.read).length;
  } catch (_) {
    return 0;
  }
});

/// The unread count as a badge label: "3", or "9+".
String unreadBadgeLabel(int count) => count > 9 ? '9+' : '$count';

/// The notification inbox (`03 §2.11`, screen #29). A tap marks the entry
/// read and follows its deep link.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inbox = ref.watch(inboxProvider);
    final controller = ref.read(inboxProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notificationsTitle),
        actions: [
          if (inbox.value?.hasUnread ?? false)
            IconButton(
              key: const Key('inbox-mark-all'),
              tooltip: l10n.notificationsMarkAllRead,
              icon: const Icon(Icons.done_all),
              onPressed: () async {
                try {
                  await controller.markAllRead();
                } on Object catch (error) {
                  if (context.mounted) {
                    showMessage(context, describeError(context, error));
                  }
                }
              },
            ),
        ],
      ),
      body: switch (inbox) {
        AsyncData(:final value) when value.items.isEmpty => EmptyView(
          key: const Key('inbox-empty'),
          message: l10n.notificationsEmpty,
          icon: Icons.notifications_none,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400 &&
                  value.hasMore &&
                  value.loadMoreError == null) {
                controller.loadMore();
              }
              return false;
            },
            child: ListView.separated(
              key: const Key('inbox-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: value.items.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => i < value.items.length
                  ? _InboxTile(notification: value.items[i])
                  : _InboxFooter(state: value),
            ),
          ),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(inboxProvider),
        ),
        _ => const SkeletonList(rows: 4),
      },
    );
  }
}

class _InboxFooter extends ConsumerWidget {
  const _InboxFooter({required this.state});

  final InboxState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(JivoSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreError == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(JivoSpacing.lg),
      child: Column(
        children: [
          Text(l10n.notificationsLoadMoreFailed),
          TextButton(
            onPressed: ref.read(inboxProvider.notifier).loadMore,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

/// The account row's unread badge (nothing when there is nothing unread).
class InboxUnreadBadge extends ConsumerWidget {
  const InboxUnreadBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(inboxUnreadProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Semantics(
      label: AppLocalizations.of(context).notificationsUnreadCount(count),
      child: ExcludeSemantics(
        child: Badge(
          key: const Key('inbox-unread-badge'),
          label: Text(unreadBadgeLabel(count)),
        ),
      ),
    );
  }
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({required this.notification});

  final InboxNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unread = !notification.read;
    return Semantics(
      value: unread ? l10n.notificationUnread : null,
      child: ListTile(
        key: Key('inbox-${notification.id}'),
        minVerticalPadding: JivoSpacing.md,
        leading: Icon(
          unread ? Icons.circle : Icons.circle_outlined,
          size: 12,
          color: unread ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text(
          notification.title,
          style: TextStyle(fontWeight: unread ? FontWeight.w700 : null),
        ),
        subtitle: Text(
          '${notification.body}\n${formatDateTime(notification.createdAt)}',
        ),
        isThreeLine: true,
        onTap: () {
          if (unread) {
            ref.read(inboxProvider.notifier).markRead(notification.id);
          }
          final link = notification.link;
          final location = link == null
              ? null
              : deepLinkLocation(
                  link,
                  trackingAvailable: ref.read(trackingAvailableProvider),
                );
          if (location != null) context.push(location);
        },
      ),
    );
  }
}
