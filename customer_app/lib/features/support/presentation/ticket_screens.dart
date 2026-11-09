import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../orders/domain/order_history.dart';
import '../../orders/presentation/order_history_controllers.dart';
import '../domain/support_models.dart';
import 'support_controllers.dart';
import 'ticket_photos.dart';

String ticketCategoryLabel(AppLocalizations l10n, TicketCategory category) =>
    switch (category) {
      TicketCategory.missingItems => l10n.ticketMissingItems,
      TicketCategory.damagedItems => l10n.ticketDamagedItems,
      TicketCategory.wrongItems => l10n.ticketWrongItems,
      TicketCategory.lateDelivery => l10n.ticketLateDelivery,
      TicketCategory.paymentRefund => l10n.ticketPaymentRefund,
      TicketCategory.account => l10n.ticketAccount,
      TicketCategory.other => l10n.ticketOther,
    };

String ticketStatusLabel(AppLocalizations l10n, TicketStatus status) =>
    switch (status) {
      TicketStatus.open => l10n.ticketStatusOpen,
      TicketStatus.inProgress => l10n.ticketStatusInProgress,
      TicketStatus.resolved => l10n.ticketStatusResolved,
      TicketStatus.closed => l10n.ticketStatusClosed,
      TicketStatus.unknown => l10n.ticketStatusOpen,
    };

/// "My tickets": newest activity first, with status chips.
class TicketListScreen extends ConsumerWidget {
  const TicketListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myTickets)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('tickets-new'),
        onPressed: () => context.push(Routes.newTicket()),
        icon: const Icon(Icons.add),
        label: Text(l10n.newTicket),
      ),
      body: switch (ref.watch(ticketListProvider)) {
        AsyncData(:final value) when value.items.isEmpty => EmptyView(
          key: const Key('tickets-empty'),
          icon: Icons.forum_outlined,
          message: l10n.ticketsEmpty,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.read(ticketListProvider.notifier).reload(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) {
                ref.read(ticketListProvider.notifier).loadMore();
              }
              return false;
            },
            child: ListView.separated(
              key: const Key('tickets'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: value.items.length + (value.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == value.items.length) {
                  return value.loadMoreError == null
                      ? const Padding(
                          padding: EdgeInsets.all(JivoSpacing.lg),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : TextButton(
                          onPressed: () =>
                              ref.read(ticketListProvider.notifier).loadMore(),
                          child: Text(l10n.retry),
                        );
                }
                return _TicketTile(ticket: value.items[i]);
              },
            ),
          ),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(ticketListProvider),
        ),
        _ => const SkeletonList(rows: 4),
      },
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final orderNumber = ticket.orderNumber;
    return ListTile(
      key: Key('ticket-${ticket.id}'),
      title: Text(ticketCategoryLabel(l10n, ticket.category)),
      subtitle: Text(
        [
          ticket.number,
          ?orderNumber,
          formatDateTime(ticket.updatedAt),
          ?ticket.lastMessage,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: TicketStatusChip(status: ticket.status),
      onTap: () => context.push(Routes.ticket(ticket.id)),
      titleTextStyle: theme.textTheme.titleSmall,
    );
  }
}

class TicketStatusChip extends StatelessWidget {
  const TicketStatusChip({required this.status, super.key});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final done =
        status == TicketStatus.resolved || status == TicketStatus.closed;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JivoSpacing.sm,
        vertical: JivoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: done ? scheme.surfaceContainerHighest : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Text(
        ticketStatusLabel(l10n, status),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// New ticket (`03 §2.11` "choose an order, then an issue type"). Opened
/// from an order ([orderId]) or from Help, where an order can be picked.
/// Up to [ticketPhotosPerMessage] optional photos go up once the ticket
/// exists (the API takes photos on a reply), as a second message.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({this.orderId, super.key});

  final int? orderId;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  TicketCategory? _category;
  late int? _orderId = widget.orderId;
  String? _orderNumber;
  bool _categoryMissing = false;
  final List<PendingTicketPhoto> _photos = [];

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final photo = await pickTicketPhoto(
      context,
      ref,
      alreadyPicked: _photos.length,
    );
    if (photo == null || !mounted) return;
    setState(() => _photos.add(photo));
  }

  Future<void> _pickOrder() async {
    final picked = await showModalBottomSheet<OrderListItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _OrderPickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _orderId = picked.id;
      _orderNumber = picked.number;
    });
  }

  void _clearOrder() => setState(() {
    _orderId = null;
    _orderNumber = null;
    if (_category?.needsOrder ?? false) _category = null;
  });

  Future<void> _submit() async {
    final category = _category;
    setState(() => _categoryMissing = category == null);
    if (!_formKey.currentState!.validate() || category == null) return;
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(newTicketProvider.notifier)
        .submit(
          category: category,
          message: _message.text,
          orderId: _orderId,
          photos: List.of(_photos),
          photosMessage: l10n.ticketPhotosMessage,
        );
    if (result == null || !mounted) return;
    final photoError = result.photoError;
    showMessage(
      context,
      photoError == null
          ? l10n.ticketCreated
          : l10n.ticketPhotosNotAdded(
              describeSupportError(context, photoError),
            ),
    );
    context.pushReplacement(Routes.ticket(result.thread.ticket.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(newTicketProvider);
    final error = state.error;
    final orderId = _orderId;
    // The number of an order opened from its detail screen.
    final orderNumber =
        _orderNumber ??
        (orderId == null || orderId != widget.orderId
            ? null
            : ref.watch(orderDetailProvider(orderId)).value?.number);
    final categories = TicketCategory.offered(withOrder: orderId != null);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newTicket)),
      body: Form(
        key: _formKey,
        child: ListView(
          key: const Key('new-ticket'),
          padding: const EdgeInsets.all(JivoSpacing.gutter),
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.ticketOrderLabel,
                style: theme.textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const Key('ticket-order'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(
                orderId == null
                    ? l10n.ticketChooseOrder
                    : l10n.orderTitle(orderNumber ?? '#$orderId'),
              ),
              trailing: orderId == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      tooltip: l10n.ticketRemoveOrder,
                      icon: const Icon(Icons.close),
                      onPressed: state.submitting ? null : _clearOrder,
                    ),
              onTap: state.submitting ? null : _pickOrder,
            ),
            const SizedBox(height: JivoSpacing.md),
            Semantics(
              header: true,
              child: Text(
                l10n.ticketIssueLabel,
                style: theme.textTheme.titleMedium,
              ),
            ),
            RadioGroup<TicketCategory>(
              groupValue: _category,
              onChanged: (value) {
                if (state.submitting) return;
                setState(() {
                  _category = value;
                  _categoryMissing = false;
                });
              },
              child: Column(
                children: [
                  for (final category in categories)
                    RadioListTile<TicketCategory>(
                      key: Key('category-${category.wireValue}'),
                      contentPadding: EdgeInsets.zero,
                      value: category,
                      title: Text(ticketCategoryLabel(l10n, category)),
                    ),
                ],
              ),
            ),
            if (_categoryMissing)
              Text(
                l10n.ticketChooseIssue,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            const SizedBox(height: JivoSpacing.md),
            TextFormField(
              key: const Key('ticket-message'),
              controller: _message,
              enabled: !state.submitting,
              minLines: 4,
              maxLines: 8,
              maxLength: ticketMessageMaxLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.ticketMessageLabel,
                hintText: l10n.ticketMessageHint,
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  (value ?? '').trim().length < ticketMessageMinLength
                  ? l10n.ticketMessageTooShort(ticketMessageMinLength)
                  : null,
            ),
            const SizedBox(height: JivoSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                l10n.ticketPhotosHint(ticketPhotosPerMessage),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            if (_photos.isNotEmpty) ...[
              PickedPhotoStrip(
                photos: _photos,
                enabled: !state.submitting,
                onRemove: (photo) => setState(() => _photos.remove(photo)),
              ),
              const SizedBox(height: JivoSpacing.sm),
            ],
            if (_photos.length < ticketPhotosPerMessage)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('ticket-add-photo'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: state.submitting ? null : _addPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(l10n.ticketAddPhoto),
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: JivoSpacing.sm),
              Text(
                describeSupportError(context, error),
                key: const Key('ticket-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: JivoSpacing.lg),
            BusyButton(
              key: const Key('ticket-submit'),
              label: l10n.ticketSubmit,
              busy: state.submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Recent orders to attach to a ticket (the first page of "My orders").
class _OrderPickerSheet extends ConsumerWidget {
  const _OrderPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: switch (ref.watch(orderListProvider)) {
        AsyncData(:final value) when value.items.isEmpty => EmptyView(
          message: l10n.ordersEmpty,
        ),
        AsyncData(:final value) => ListView(
          key: const Key('order-picker'),
          children: [
            for (final order in value.items)
              ListTile(
                key: Key('pick-order-${order.id}'),
                title: Text(l10n.orderTitle(order.number)),
                subtitle: Text(
                  formatDateTime(order.placedAt ?? order.createdAt),
                ),
                onTap: () => Navigator.pop(context, order),
              ),
          ],
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(orderListProvider),
        ),
        _ => const SkeletonList(rows: 4),
      },
    );
  }
}

/// A ticket's thread with the reply box (none once closed).
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({required this.ticketId, super.key});

  final int ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();
  final List<PendingTicketPhoto> _photos = [];
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final photo = await pickTicketPhoto(
      context,
      ref,
      alreadyPicked: _photos.length,
    );
    if (photo == null || !mounted) return;
    setState(() => _photos.add(photo));
  }

  /// Sends the text with the picked photos. The API needs text, so photos
  /// alone go with "Photos of the issue".
  Future<void> _send() async {
    var text = _reply.text.trim();
    if (text.isEmpty && _photos.isNotEmpty) {
      text = AppLocalizations.of(context).ticketPhotosMessage;
    }
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(ticketThreadProvider(widget.ticketId).notifier)
          .reply(text, photos: List.of(_photos));
      _reply.clear();
      if (mounted) setState(_photos.clear);
    } catch (error) {
      if (mounted) showMessage(context, describeSupportError(context, error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final thread = ref.watch(ticketThreadProvider(widget.ticketId));
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (thread) {
          AsyncData(:final value) => value.ticket.number,
          _ => l10n.myTickets,
        }),
      ),
      body: switch (thread) {
        AsyncData(:final value) => Column(
          children: [
            _TicketHeader(ticket: value.ticket),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(ticketThreadProvider(widget.ticketId).notifier)
                    .reload(),
                child: ListView(
                  key: const Key('ticket-thread'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(JivoSpacing.gutter),
                  children: [
                    for (final message in value.messages)
                      _MessageBubble(message: message),
                  ],
                ),
              ),
            ),
            if (value.canReply)
              _ReplyBox(
                controller: _reply,
                sending: _sending,
                onSend: _send,
                photos: _photos,
                onAddPhoto: _addPhoto,
                onRemovePhoto: (photo) => setState(() => _photos.remove(photo)),
              )
            else
              Padding(
                key: const Key('ticket-closed'),
                padding: const EdgeInsets.all(JivoSpacing.gutter),
                child: Text(l10n.ticketClosedNote, textAlign: TextAlign.center),
              ),
          ],
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(ticketThreadProvider(widget.ticketId)),
        ),
        _ => const SkeletonList(rows: 4),
      },
    );
  }
}

class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final orderId = ticket.orderId;
    return ListTile(
      title: Text(ticketCategoryLabel(l10n, ticket.category)),
      subtitle: orderId == null
          ? Text(formatDateTime(ticket.createdAt))
          : Text(l10n.orderTitle(ticket.orderNumber ?? '#$orderId')),
      trailing: TicketStatusChip(status: ticket.status),
      onTap: orderId == null ? null : () => context.push(Routes.order(orderId)),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mine = !message.fromSupport;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: JivoSpacing.sm),
          padding: const EdgeInsets.all(JivoSpacing.md),
          decoration: BoxDecoration(
            color: mine
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(JivoRadii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine ? l10n.ticketYou : l10n.ticketSupport,
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: JivoSpacing.xs),
              Text(message.body),
              if (message.photos.isNotEmpty) ...[
                const SizedBox(height: JivoSpacing.sm),
                MessagePhotos(photos: message.photos),
              ],
              const SizedBox(height: JivoSpacing.xs),
              Text(
                formatDateTime(message.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyBox extends StatelessWidget {
  const _ReplyBox({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.photos,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final List<PendingTicketPhoto> photos;
  final VoidCallback onAddPhoto;
  final ValueChanged<PendingTicketPhoto> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          JivoSpacing.sm,
          JivoSpacing.sm,
          JivoSpacing.sm,
          JivoSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (photos.isNotEmpty) ...[
              PickedPhotoStrip(
                photos: photos,
                enabled: !sending,
                onRemove: onRemovePhoto,
              ),
              const SizedBox(height: JivoSpacing.sm),
            ],
            _replyRow(l10n),
          ],
        ),
      ),
    );
  }

  Widget _replyRow(AppLocalizations l10n) => Row(
    children: [
      IconButton(
        key: const Key('ticket-reply-photo'),
        tooltip: l10n.ticketAddPhoto,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: sending || photos.length >= ticketPhotosPerMessage
            ? null
            : onAddPhoto,
        icon: const Icon(Icons.add_a_photo_outlined),
      ),
      Expanded(
        child: TextField(
          key: const Key('ticket-reply'),
          controller: controller,
          enabled: !sending,
          minLines: 1,
          maxLines: 4,
          maxLength: ticketMessageMaxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: l10n.ticketReplyHint,
            counterText: '',
          ),
        ),
      ),
      const SizedBox(width: JivoSpacing.sm),
      sending
          ? const SizedBox.square(
              dimension: 48,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton.filled(
              key: const Key('ticket-send'),
              tooltip: l10n.ticketSend,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onSend,
              icon: const Icon(Icons.send),
            ),
    ],
  );
}
