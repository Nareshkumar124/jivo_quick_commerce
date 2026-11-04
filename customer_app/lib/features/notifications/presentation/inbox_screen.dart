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

/// The inbox (first page; Phase 6 adds paging with the real endpoints).
class InboxController extends AsyncNotifier<List<InboxNotification>> {
  @override
  Future<List<InboxNotification>> build() async =>
      (await ref.read(notificationRepositoryProvider).list()).items;

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Marks [id] read here at once; the server call is best effort.
  Future<void> markRead(int id) async {
    final items = state.value;
    if (items == null) return;
    state = AsyncData([for (final n in items) n.id == id ? n.markedRead() : n]);
    try {
      await ref.read(notificationRepositoryProvider).markRead(id);
    } catch (_) {
      // The next load shows the server's state.
    }
  }
}

final inboxProvider =
    AsyncNotifierProvider.autoDispose<InboxController, List<InboxNotification>>(
      InboxController.new,
    );

/// The notification inbox (`03 §2.11`, screen #29; Phase 6 lookahead on
/// fake data). A tap marks the entry read and follows its deep link.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: switch (ref.watch(inboxProvider)) {
        AsyncData(:final value) when value.isEmpty => EmptyView(
          key: const Key('inbox-empty'),
          message: l10n.notificationsEmpty,
          icon: Icons.notifications_none,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: ref.read(inboxProvider.notifier).refresh,
          child: ListView.separated(
            key: const Key('inbox-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _InboxTile(notification: value[i]),
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
