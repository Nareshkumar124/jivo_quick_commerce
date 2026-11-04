import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../domain/support_models.dart';

/// The customer-app FAQs.
final faqsProvider = FutureProvider.autoDispose<List<Faq>>(
  (ref) => ref.watch(supportRepositoryProvider).faqs(),
);

/// The loaded pages of "My tickets".
@immutable
class TicketListState {
  const TicketListState({
    this.items = const [],
    this.nextPage,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<SupportTicket> items;
  final int? nextPage;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextPage != null;
}

/// "My tickets" with infinite scroll.
class TicketListController extends AsyncNotifier<TicketListState> {
  @override
  Future<TicketListState> build() async {
    final first = await ref.read(supportRepositoryProvider).listTickets();
    return TicketListState(items: first.items, nextPage: first.nextPage);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      TicketListState(
        items: current.items,
        nextPage: current.nextPage,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(supportRepositoryProvider)
          .listTickets(page: current.nextPage!);
      if (!ref.mounted) return;
      final seen = {for (final t in current.items) t.id};
      state = AsyncData(
        TicketListState(
          items: [
            ...current.items,
            for (final t in page.items)
              if (!seen.contains(t.id)) t,
          ],
          nextPage: page.nextPage,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(
        TicketListState(
          items: current.items,
          nextPage: current.nextPage,
          loadMoreError: error,
        ),
      );
    }
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final ticketListProvider =
    AsyncNotifierProvider.autoDispose<TicketListController, TicketListState>(
      TicketListController.new,
    );

/// One ticket's thread, with the customer's reply.
class TicketThreadController extends AsyncNotifier<TicketThread> {
  TicketThreadController(this.ticketId);

  final int ticketId;

  @override
  Future<TicketThread> build() =>
      ref.read(supportRepositoryProvider).ticket(ticketId);

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  /// Sends [message]; the thread shows the server's copy. Throws
  /// `ApiError` for the screen to show (the typed text stays).
  Future<void> reply(String message) async {
    final thread = await ref
        .read(supportRepositoryProvider)
        .reply(ticketId, message.trim());
    if (!ref.mounted) return;
    state = AsyncData(thread);
    ref.invalidate(ticketListProvider);
  }
}

final ticketThreadProvider = AsyncNotifierProvider.autoDispose
    .family<TicketThreadController, TicketThread, int>(
      TicketThreadController.new,
    );

/// The new-ticket form's submit state.
@immutable
class NewTicketState {
  const NewTicketState({this.submitting = false, this.error});

  final bool submitting;
  final Object? error;
}

class NewTicketController extends Notifier<NewTicketState> {
  @override
  NewTicketState build() => const NewTicketState();

  /// Opens the ticket. Returns its thread, or null on failure (kept in
  /// [NewTicketState.error]) or while a submit runs.
  Future<TicketThread?> submit({
    required TicketCategory category,
    required String message,
    int? orderId,
  }) async {
    if (state.submitting) return null;
    state = const NewTicketState(submitting: true);
    try {
      final thread = await ref
          .read(supportRepositoryProvider)
          .createTicket(
            category: category,
            message: message.trim(),
            orderId: orderId,
          );
      if (ref.mounted) {
        state = const NewTicketState();
        ref.invalidate(ticketListProvider);
      }
      return thread;
    } catch (error) {
      if (ref.mounted) state = NewTicketState(error: error);
      return null;
    }
  }
}

final newTicketProvider =
    NotifierProvider.autoDispose<NewTicketController, NewTicketState>(
      NewTicketController.new,
    );
