import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../data/support_repository.dart';
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

  /// Re-reads the thread in the background (CA-30: support replies while
  /// the screen is open). A failure keeps the thread on screen; the next
  /// poll tries again.
  /// One poll at a time; [_writes] counts sends and reloads, so a poll
  /// that started before one of them can't overwrite its newer thread.
  bool _polling = false;
  int _writes = 0;

  Future<void> refreshQuietly() async {
    if (_polling) return;
    _polling = true;
    final started = _writes;
    try {
      final thread = await ref.read(supportRepositoryProvider).ticket(ticketId);
      if (!ref.mounted || started != _writes) return;
      final shown = state.value;
      // Never go back to an older thread than the one on screen.
      if (shown != null && thread.messages.length < shown.messages.length) {
        return;
      }
      state = AsyncData(thread);
    } catch (_) {
      // Keep what is shown.
    } finally {
      _polling = false;
    }
  }

  Future<void> reload() async {
    _writes++;
    ref.invalidateSelf();
    await future;
  }

  /// Sends [message] with [photos] (uploaded first, each once); the thread
  /// shows the server's copy. Throws `ApiError` or `TicketPhotoException`
  /// for the screen to show (the typed text and photos stay).
  Future<void> reply(
    String message, {
    List<PendingTicketPhoto> photos = const [],
  }) async {
    final repository = ref.read(supportRepositoryProvider);
    final keys = await uploadTicketPhotos(
      photos,
      (file) => repository.uploadPhoto(ticketId, file),
    );
    _writes++;
    final thread = await repository.reply(
      ticketId,
      message.trim(),
      photoKeys: keys,
    );
    if (!ref.mounted) return;
    _writes++;
    state = AsyncData(thread);
    ref.invalidate(ticketListProvider);
  }
}

/// Uploads the [photos] not uploaded yet with [upload], in order, and
/// returns all their keys. Throws on the first failure (earlier uploads
/// keep their keys).
Future<List<String>> uploadTicketPhotos(
  List<PendingTicketPhoto> photos,
  Future<TicketPhoto> Function(TicketPhotoFile file) upload,
) async {
  if (photos.length > ticketPhotosPerMessage) {
    throw const TicketPhotoException(TicketPhotoProblem.tooMany);
  }
  for (final photo in photos) {
    photo.uploadedKey ??= (await upload(photo.file)).key;
  }
  return [for (final photo in photos) photo.uploadedKey!];
}

final ticketThreadProvider = AsyncNotifierProvider.autoDispose
    .family<TicketThreadController, TicketThread, int>(
      TicketThreadController.new,
    );

/// A created ticket, and why its photos weren't added (null when they
/// were, or there were none).
@immutable
class NewTicketResult {
  const NewTicketResult(this.thread, {this.photoError});

  final TicketThread thread;
  final Object? photoError;
}

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

  /// Opens the ticket with [photos].
  ///
  /// When the API takes photos on create
  /// ([SupportRepository.photosOnCreate]) they are uploaded first and
  /// attach to the first message; a failed upload means no ticket (the
  /// error is kept, uploaded photos keep their keys for the retry).
  /// Otherwise (older API) the ticket is opened first and the photos go up
  /// as a second message, [photosMessage].
  ///
  /// Returns the ticket (with [NewTicketResult.photoError] when only the
  /// photos failed, older API only), or null when the ticket wasn't created
  /// (the error is kept in [NewTicketState.error]) or while a submit runs.
  Future<NewTicketResult?> submit({
    required TicketCategory category,
    required String message,
    int? orderId,
    List<PendingTicketPhoto> photos = const [],
    String photosMessage = '',
  }) async {
    if (state.submitting) return null;
    state = const NewTicketState(submitting: true);
    final repository = ref.read(supportRepositoryProvider);
    final photosOnCreate = repository.photosOnCreate && photos.isNotEmpty;
    TicketThread thread;
    try {
      thread = await repository.createTicket(
        category: category,
        message: message.trim(),
        orderId: orderId,
        photoKeys: photosOnCreate
            ? await uploadTicketPhotos(photos, repository.uploadNewTicketPhoto)
            : const [],
      );
    } catch (error) {
      if (ref.mounted) state = NewTicketState(error: error);
      return null;
    }
    Object? photoError;
    if (photos.isNotEmpty && !photosOnCreate) {
      try {
        final ticketId = thread.ticket.id;
        final keys = await uploadTicketPhotos(
          photos,
          (file) => repository.uploadPhoto(ticketId, file),
        );
        thread = await repository.reply(
          ticketId,
          photosMessage,
          photoKeys: keys,
        );
      } catch (error) {
        photoError = error;
      }
    }
    if (ref.mounted) {
      state = const NewTicketState();
      ref.invalidate(ticketListProvider);
    }
    return NewTicketResult(thread, photoError: photoError);
  }
}

final newTicketProvider =
    NotifierProvider.autoDispose<NewTicketController, NewTicketState>(
      NewTicketController.new,
    );
