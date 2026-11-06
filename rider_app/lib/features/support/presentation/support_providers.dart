import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../../shared/paging.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../data/support_repository.dart';
import '../domain/support_models.dart';

/// The fake FAQs and tickets (`FAKE_API` builds). Overridden in tests.
final fakeSupportBackendProvider = Provider<FakeSupportBackend>(
  (ref) => FakeSupportBackend(clock: ref.watch(clockProvider)),
);

/// FAQs and tickets: the shared support API, the fake with `FAKE_API`.
/// Where the rider work screens run (dev flavor, DL-30/DL-32).
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeSupportBackendProvider);
  }
  return ApiSupportRepository(ref.watch(jivoApiProvider));
});

/// `GET /faqs/?app=rider`.
final faqsProvider = FutureProvider.autoDispose<List<Faq>>(
  (ref) => ref.watch(supportRepositoryProvider).faqs(),
);

/// "My tickets", newest activity first, paged.
final ticketsProvider =
    NotifierProvider.autoDispose<
      PagedListNotifier<SupportTicket, void>,
      PagedListState<SupportTicket, void>
    >(
      () => PagedListNotifier((ref, cursor) async {
        final page = await ref
            .read(supportRepositoryProvider)
            .tickets(page: cursor);
        return (page, null);
      }, keyOf: (ticket) => ticket.id),
    );

/// One ticket with its messages, and the rider's reply.
final ticketThreadProvider = AsyncNotifierProvider.autoDispose
    .family<TicketThreadController, TicketThread, int>(
      TicketThreadController.new,
    );

class TicketThreadController extends AsyncNotifier<TicketThread> {
  TicketThreadController(this.ticketId);

  final int ticketId;

  @override
  Future<TicketThread> build() =>
      ref.read(supportRepositoryProvider).ticket(ticketId);

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(supportRepositoryProvider).ticket(ticketId),
    );
  }

  /// Sends [message]. Returns null when sent (the thread is the server's
  /// answer), else the error to show; the typed text is kept by the screen.
  Future<ApiError?> reply(String message) async {
    final text = message.trim();
    if (text.isEmpty) return null;
    try {
      final thread = await ref
          .read(supportRepositoryProvider)
          .reply(ticketId, text);
      if (ref.mounted) state = AsyncData(thread);
      return null;
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (ref.mounted) reportAppControlError(ref, error);
      return error;
    }
  }
}

/// The new-ticket form.
@immutable
class NewTicketState {
  const NewTicketState({
    required this.draft,
    this.sending = false,
    this.showProblems = false,
    this.error,
  });

  final TicketDraft draft;
  final bool sending;

  /// Set after a send attempt, so the form doesn't complain while typing.
  final bool showProblems;
  final ApiError? error;

  NewTicketState copyWith({
    TicketDraft? draft,
    bool? sending,
    bool? showProblems,
    ApiError? error,
    bool clearError = false,
  }) => NewTicketState(
    draft: draft ?? this.draft,
    sending: sending ?? this.sending,
    showProblems: showProblems ?? this.showProblems,
    error: clearError ? null : (error ?? this.error),
  );
}

/// What the form opens with (from the help screen, or "Get help with this
/// order" on a past task).
typedef NewTicketArgs = ({RiderTicketTopic? topic, String? reference});

final newTicketControllerProvider = NotifierProvider.autoDispose
    .family<NewTicketController, NewTicketState, NewTicketArgs>(
      NewTicketController.new,
    );

class NewTicketController extends Notifier<NewTicketState> {
  NewTicketController(this.args);

  final NewTicketArgs args;

  @override
  NewTicketState build() => NewTicketState(
    draft: TicketDraft(
      topic: args.topic ?? RiderTicketTopic.task,
      reference: args.reference ?? '',
    ),
  );

  void _edit(TicketDraft draft) =>
      state = state.copyWith(draft: draft, clearError: true);

  void setTopic(RiderTicketTopic topic) => _edit(
    TicketDraft(
      topic: topic,
      reference: state.draft.reference,
      text: state.draft.text,
    ),
  );

  void setReference(String reference) => _edit(
    TicketDraft(
      topic: state.draft.topic,
      reference: reference,
      text: state.draft.text,
    ),
  );

  void setText(String text) => _edit(
    TicketDraft(
      topic: state.draft.topic,
      reference: state.draft.reference,
      text: text,
    ),
  );

  /// Sends the ticket. Returns the new thread, or null when the form has a
  /// problem or the call failed (shown on the form).
  Future<TicketThread?> submit() async {
    if (state.sending) return null;
    if (state.draft.problem != null) {
      state = state.copyWith(showProblems: true);
      return null;
    }
    state = state.copyWith(sending: true, showProblems: true, clearError: true);
    try {
      final thread = await ref
          .read(supportRepositoryProvider)
          .create(state.draft);
      if (ref.mounted) state = state.copyWith(sending: false);
      return thread;
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return null;
      reportAppControlError(ref, error);
      state = state.copyWith(sending: false, error: error);
      return null;
    }
  }
}

/// Staging and prod while gated: never reached; every call fails.
class _Unavailable implements SupportRepository {
  const _Unavailable();

  static const _error = ApiError(code: ApiErrorCode.notFound, statusCode: 404);

  @override
  Future<List<Faq>> faqs() async => throw _error;

  @override
  Future<Page<SupportTicket>> tickets({int? page}) async => throw _error;

  @override
  Future<TicketThread> ticket(int id) async => throw _error;

  @override
  Future<TicketThread> create(TicketDraft draft) async => throw _error;

  @override
  Future<TicketThread> reply(int ticketId, String message) async =>
      throw _error;
}
