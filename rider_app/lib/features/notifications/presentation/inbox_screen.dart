import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../domain/inbox.dart';
import 'inbox_providers.dart';

/// The in-app inbox (04 §2.10): newest first, unread in bold with a dot. A
/// tap marks the entry read; "Mark all read" clears the badge.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(inboxControllerProvider);
    final notifier = ref.read(inboxControllerProvider.notifier);
    final anyUnread = state.items.any((e) => !e.read);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.inboxTitle),
        actions: [
          if (anyUnread)
            TextButton(
              key: const Key('inbox-mark-all'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (!await notifier.markAllRead()) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.inboxMarkAllFailed)),
                  );
                }
              },
              child: Text(l10n.inboxMarkAllRead),
            ),
        ],
      ),
      body: PagedListView(
        state: state,
        onRefresh: notifier.refresh,
        onLoadMore: notifier.loadMore,
        emptyText: l10n.inboxEmpty,
        itemBuilder: (context, entry) =>
            _InboxTile(entry: entry, onTap: () => notifier.markRead(entry.id)),
      ),
    );
  }
}

IconData inboxIconOf(String category) => switch (category) {
  'order' => Icons.local_shipping,
  'promo' => Icons.campaign,
  _ => Icons.info_outline,
};

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.entry, required this.onTap});

  final InboxEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !entry.read;
    return Card(
      key: Key('inbox-${entry.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(inboxIconOf(entry.category), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(entry.body, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(
                      istDateTime(context, entry.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 6),
                  child: Icon(
                    Icons.circle,
                    key: Key('inbox-${entry.id}-unread'),
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home app bar's bell with the unread badge.
class InboxBellButton extends ConsumerWidget {
  const InboxBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final badge = ref.watch(inboxUnreadCountProvider).value ?? InboxBadge.none;
    return IconButton(
      key: const Key('home-appbar-inbox'),
      tooltip: badge.isEmpty
          ? l10n.inboxTitle
          : '${l10n.inboxTitle}, ${l10n.inboxUnreadBadge(badge.label)}',
      iconSize: 28,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () async {
        await context.push(Routes.inbox);
        ref.invalidate(inboxUnreadCountProvider);
      },
      icon: Badge(
        key: const Key('home-inbox-badge'),
        isLabelVisible: !badge.isEmpty,
        label: Text(badge.label),
        child: const Icon(Icons.notifications),
      ),
    );
  }
}
