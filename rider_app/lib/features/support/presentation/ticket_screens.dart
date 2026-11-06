import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/rider_error_text.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../domain/support_models.dart';
import 'support_providers.dart';

String ticketTopicName(AppLocalizations l10n, RiderTicketTopic topic) =>
    switch (topic) {
      RiderTicketTopic.task => l10n.ticketTopicTask,
      RiderTicketTopic.payout => l10n.ticketTopicPayout,
      RiderTicketTopic.cash => l10n.ticketTopicCash,
      RiderTicketTopic.account => l10n.ticketTopicAccount,
      RiderTicketTopic.app => l10n.ticketTopicApp,
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

/// Raise a ticket: pick a topic, an optional order number or payout
/// reference, and describe the problem. One primary action.
class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({this.topic, this.reference, super.key});

  final RiderTicketTopic? topic;
  final String? reference;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  late final NewTicketArgs _args = (
    topic: widget.topic,
    reference: widget.reference,
  );
  late final _reference = TextEditingController(text: widget.reference ?? '');
  final _text = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
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
          if (draft.topic.takesReference) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('ticket-reference'),
              controller: _reference,
              enabled: !state.sending,
              maxLength: ticketReferenceMaxLength,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: draft.topic == RiderTicketTopic.payout
                    ? l10n.ticketReferencePayout
                    : l10n.ticketReferenceOrder,
                helperText: l10n.ticketReferenceOptional,
                border: const OutlineInputBorder(),
              ),
              onChanged: notifier.setReference,
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const Key('ticket-text'),
            controller: _text,
            enabled: !state.sending,
            minLines: 4,
            maxLines: 8,
            maxLength: riderTicketTextMaxLength,
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
                TicketDraftProblem.referenceTooLong => l10n.ticketTooLong,
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
    final preview = ticket.lastMessage == null
        ? null
        : parseRiderMessage(ticket.lastMessage!).text;
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

/// One ticket: the messages, oldest first, and a reply box while the
/// server allows replies.
class TicketThreadScreen extends ConsumerStatefulWidget {
  const TicketThreadScreen({required this.ticketId, super.key});

  final int ticketId;

  @override
  ConsumerState<TicketThreadScreen> createState() => _TicketThreadScreenState();
}

class _TicketThreadScreenState extends ConsumerState<TicketThreadScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await ref
        .read(ticketThreadProvider(widget.ticketId).notifier)
        .reply(_reply.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _reply.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(riderApiErrorMessage(context, error))),
      );
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
          sending: _sending,
          onSend: _send,
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
                  onPressed: ref
                      .read(ticketThreadProvider(widget.ticketId).notifier)
                      .reload,
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
    required this.sending,
    required this.onSend,
  });

  final TicketThread thread;
  final TextEditingController reply;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final topic = thread.topic;
    final first = thread.messages.isEmpty
        ? null
        : parseRiderMessage(thread.messages.first.body);
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
                      [
                        if (topic != null) ticketTopicName(l10n, topic),
                        ?first?.reference,
                      ].join(' · '),
                      key: const Key('ticket-topic'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(status: thread.ticket.status),
                ],
              ),
              const SizedBox(height: 12),
              for (final (index, message) in thread.messages.indexed)
                _Bubble(
                  message: message,
                  // The first message is shown without its topic tag.
                  text: index == 0 ? first!.text : message.body,
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: thread.canReply
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                          onPressed: sending ? null : onSend,
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.text});

  final TicketMessage message;
  final String text;

  @override
  Widget build(BuildContext context) {
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
            Text(text, style: theme.textTheme.bodyLarge),
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
