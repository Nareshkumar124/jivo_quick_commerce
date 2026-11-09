import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/rider_error_text.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../onboarding/domain/image_picking.dart';
import '../domain/support_models.dart';
import 'support_providers.dart';

String ticketTopicName(AppLocalizations l10n, RiderTicketTopic topic) =>
    switch (topic) {
      RiderTicketTopic.task => l10n.ticketTopicTask,
      RiderTicketTopic.payout => l10n.ticketTopicPayout,
      RiderTicketTopic.cash => l10n.ticketTopicCash,
      RiderTicketTopic.account => l10n.ticketTopicAccount,
      RiderTicketTopic.other => l10n.ticketTopicOther,
    };

String ticketStatusName(AppLocalizations l10n, TicketStatus status) =>
    switch (status) {
      TicketStatus.open => l10n.ticketStatusOpen,
      TicketStatus.inProgress => l10n.ticketStatusInProgress,
      TicketStatus.resolved => l10n.ticketStatusResolved,
      TicketStatus.closed => l10n.ticketStatusClosed,
      TicketStatus.unknown => l10n.ticketStatusOpen,
    };

/// What a ticket is about, as one line: the topic, then the linked order
/// number or payout period when there is one.
String ticketSubject(
  AppLocalizations l10n,
  RiderTicketTopic? topic, {
  String? orderNumber,
  String? payoutPeriod,
}) => [
  if (topic != null) ticketTopicName(l10n, topic),
  if (orderNumber != null) l10n.ticketLinkedOrder(orderNumber),
  if (payoutPeriod != null) l10n.ticketLinkedPayout(payoutPeriod),
].join(' · ');

/// Raise a ticket: pick a topic and describe the problem. Opened from a
/// past task or a payout, the ticket is linked to it (`task_id` /
/// `payout_id`) while that topic stays selected. One primary action.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({
    this.topic,
    this.taskId,
    this.payoutId,
    this.label,
    super.key,
  });

  final RiderTicketTopic? topic;
  final int? taskId;
  final int? payoutId;

  /// How to show the linked task or payout (order number, payout period).
  final String? label;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  late final NewTicketArgs _args = (
    topic: widget.topic,
    taskId: widget.taskId,
    payoutId: widget.payoutId,
    label: widget.label,
  );
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final thread = await ref
        .read(newTicketControllerProvider(_args).notifier)
        .submit();
    if (thread == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.ticketSent(thread.ticket.number))),
    );
    context.pushReplacement(Routes.ticket(thread.ticket.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(newTicketControllerProvider(_args));
    final notifier = ref.read(newTicketControllerProvider(_args).notifier);
    final draft = state.draft;
    final problem = state.showProblems ? draft.problem : null;
    final error = state.error;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newTicketTitle)),
      body: ListView(
        key: const Key('new-ticket-list'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.newTicketTopic, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in RiderTicketTopic.values)
                ChoiceChip(
                  key: Key('ticket-topic-${topic.code}'),
                  label: Text(ticketTopicName(l10n, topic)),
                  selected: draft.topic == topic,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: state.sending
                      ? null
                      : (_) => notifier.setTopic(topic),
                ),
            ],
          ),
          if (draft.linkedLabel case final label?) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                minTileHeight: 56,
                leading: Icon(
                  draft.linkedTaskId != null
                      ? Icons.local_shipping
                      : Icons.receipt_long,
                ),
                title: Text(
                  key: const Key('ticket-linked'),
                  draft.linkedTaskId != null
                      ? l10n.ticketLinkedOrder(label)
                      : l10n.ticketLinkedPayout(label),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('ticket-text'),
            controller: _text,
            enabled: !state.sending,
            minLines: 4,
            maxLines: 8,
            maxLength: ticketMessageMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.ticketDescribe,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              errorText: switch (problem) {
                TicketDraftProblem.tooShort => l10n.ticketTooShort(
                  ticketMessageMinLength,
                ),
                TicketDraftProblem.tooLong => l10n.ticketTooLong,
                null => null,
              },
            ),
            onChanged: notifier.setText,
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              riderApiErrorMessage(context, error),
              key: const Key('new-ticket-error'),
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('ticket-send'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: state.sending ? null : _send,
            child: state.sending
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Text(l10n.ticketSend),
          ),
        ],
      ),
    );
  }
}

/// "My tickets", newest activity first.
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(ticketsProvider);
    final notifier = ref.read(ticketsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.ticketsTitle)),
      body: PagedListView(
        state: state,
        onRefresh: notifier.refresh,
        onLoadMore: notifier.loadMore,
        emptyText: l10n.ticketsEmpty,
        itemBuilder: (context, ticket) => _TicketTile(
          ticket: ticket,
          onTap: () async {
            await context.push(Routes.ticket(ticket.id));
            await notifier.refresh();
          },
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preview = ticket.lastMessage;
    final subject = ticketSubject(
      l10n,
      ticket.topic,
      orderNumber: ticket.orderNumber,
    );
    return Card(
      key: Key('ticket-${ticket.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.number,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(status: ticket.status),
                ],
              ),
              if (subject.isNotEmpty)
                Text(subject, style: theme.textTheme.bodyMedium),
              if (preview != null) ...[
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 4),
              Text(
                l10n.ticketUpdated(istDateTime(context, ticket.updatedAt)),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done =
        status == TicketStatus.resolved || status == TicketStatus.closed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done ? scheme.surfaceContainerHighest : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        ticketStatusName(AppLocalizations.of(context), status),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: done ? scheme.onSurface : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// One ticket: the messages, oldest first, and a reply box (with up to
/// [maxAttachmentsPerReply] photos) while the server allows replies.
class TicketThreadScreen extends ConsumerStatefulWidget {
  const TicketThreadScreen({required this.ticketId, super.key});

  final int ticketId;

  @override
  ConsumerState<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends ConsumerState<TicketThreadScreen> {
  final _reply = TextEditingController();
  final List<UploadedAttachment> _photos = [];
  bool _sending = false;
  bool _uploading = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  TicketThreadController get _controller =>
      ref.read(ticketThreadProvider(widget.ticketId).notifier);

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send() async {
    if (_sending || _uploading) return;
    if (_reply.text.trim().isEmpty) {
      if (_photos.isNotEmpty) {
        _snack(AppLocalizations.of(context).ticketPhotoNeedsText);
      }
      return;
    }
    setState(() => _sending = true);
    final error = await _controller.reply(
      _reply.text,
      attachmentKeys: [for (final p in _photos) p.key],
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _reply.clear();
      setState(_photos.clear);
    } else {
      _snack(riderApiErrorMessage(context, error));
    }
  }

  Future<void> _addPhoto() async {
    final l10n = AppLocalizations.of(context);
    if (_photos.length >= maxAttachmentsPerReply) {
      _snack(l10n.ticketPhotoLimit(maxAttachmentsPerReply));
      return;
    }
    final source = await showModalBottomSheet<ImagePickSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('ticket-photo-camera'),
              minTileHeight: 56,
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.ticketPhotoCamera),
              onTap: () => Navigator.pop(context, ImagePickSource.camera),
            ),
            ListTile(
              key: const Key('ticket-photo-gallery'),
              minTileHeight: 56,
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.ticketPhotoGallery),
              onTap: () => Navigator.pop(context, ImagePickSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _uploading = true);
    final result = await _controller.attachPhoto(source);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (result.photo case final photo?) _photos.add(photo);
    });
    switch (result.problem) {
      case PhotoTooLarge():
        _snack(l10n.ticketPhotoTooLarge);
      case PhotoUnreadable():
        _snack(l10n.ticketPhotoUnreadable);
      case PhotoUploadFailed(:final error):
        _snack(riderApiErrorMessage(context, error));
      case null:
        break;
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
          _ => l10n.ticketsTitle,
        }),
      ),
      body: switch (thread) {
        AsyncData(:final value) => _ThreadBody(
          thread: value,
          reply: _reply,
          photos: _photos,
          sending: _sending,
          uploading: _uploading,
          onSend: _send,
          onAddPhoto: _addPhoto,
          onRemovePhoto: (photo) => setState(() => _photos.remove(photo)),
        ),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  riderApiErrorMessage(context, ApiError.from(error)),
                  key: const Key('ticket-error'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('ticket-retry'),
                  onPressed: _controller.reload,
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ThreadBody extends StatelessWidget {
  const _ThreadBody({
    required this.thread,
    required this.reply,
    required this.photos,
    required this.sending,
    required this.uploading,
    required this.onSend,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final TicketThread thread;
  final TextEditingController reply;
  final List<UploadedAttachment> photos;
  final bool sending;
  final bool uploading;
  final VoidCallback onSend;
  final VoidCallback onAddPhoto;
  final ValueChanged<UploadedAttachment> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ticket = thread.ticket;
    final busy = sending || uploading;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('ticket-messages'),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticketSubject(
                        l10n,
                        ticket.topic,
                        orderNumber: ticket.orderNumber,
                      ),
                      key: const Key('ticket-topic'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(status: ticket.status),
                ],
              ),
              const SizedBox(height: 12),
              for (final message in thread.messages) _Bubble(message: message),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: thread.canReply
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (photos.isNotEmpty || uploading)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final (i, photo) in photos.indexed)
                                InputChip(
                                  key: Key('ticket-photo-${i + 1}'),
                                  avatar: const Icon(Icons.image),
                                  label: Text(l10n.ticketPhoto(i + 1)),
                                  deleteButtonTooltipMessage: l10n
                                      .ticketPhotoRemove(i + 1),
                                  onDeleted: busy
                                      ? null
                                      : () => onRemovePhoto(photo),
                                ),
                              if (uploading)
                                const Padding(
                                  key: Key('ticket-photo-uploading'),
                                  padding: EdgeInsets.all(8),
                                  child: SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox.square(
                            dimension: 56,
                            child: IconButton(
                              key: const Key('ticket-add-photo'),
                              tooltip: l10n.ticketAddPhoto,
                              onPressed: busy ? null : onAddPhoto,
                              icon: const Icon(Icons.add_a_photo),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextField(
                              key: const Key('ticket-reply'),
                              controller: reply,
                              enabled: !sending,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: ticketMessageMaxLength,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: l10n.ticketReplyHint,
                                border: const OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox.square(
                            dimension: 56,
                            child: IconButton.filled(
                              key: const Key('ticket-reply-send'),
                              tooltip: l10n.ticketSend,
                              onPressed: busy ? null : onSend,
                              icon: sending
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Text(
                    l10n.ticketClosedNote,
                    key: const Key('ticket-closed'),
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mine = !message.fromSupport;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('ticket-message-${message.id}'),
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mine ? l10n.ticketFromYou : l10n.ticketFromSupport,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(message.body, style: theme.textTheme.bodyLarge),
            // Photos open outside the app: the signed URLs expire, so they
            // are never cached on the phone.
            for (final (i, url) in message.attachments.indexed)
              TextButton.icon(
                key: Key('ticket-message-${message.id}-photo-${i + 1}'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => ref.read(urlOpenerProvider).open(url),
                icon: const Icon(Icons.image),
                label: Text(l10n.ticketPhoto(i + 1)),
              ),
            const SizedBox(height: 4),
            Text(
              istDateTime(context, message.createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
