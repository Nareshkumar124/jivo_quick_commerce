import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../shared/paged_list_controller.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../onboarding/domain/image_compression.dart';
import '../../onboarding/domain/image_picking.dart';
import '../../onboarding/presentation/onboarding_providers.dart';
import '../data/support_repository.dart';
import '../domain/support_models.dart';

/// The fake FAQs and tickets (`FAKE_API` builds). Overridden in tests.
final fakeSupportBackendProvider = Provider<FakeSupportBackend>(
  (ref) => FakeSupportBackend(clock: ref.watch(clockProvider)),
);

/// FAQs and tickets: the shared support API in every flavor; the fake only
/// in the dev flavor with `FAKE_API` (DL-30, DL-32).
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  if (ref.watch(appEnvProvider).useRiderFakes) {
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

/// Why a photo could not be attached.
sealed class PhotoProblem {
  const PhotoProblem();
}

/// The file is not an image the phone can read.
class PhotoUnreadable extends PhotoProblem {
  const PhotoUnreadable();
}

/// Even compressed, or the server/proxy refused its size (413).
class PhotoTooLarge extends PhotoProblem {
  const PhotoTooLarge();
}

/// The upload failed (network, closed ticket, rate limit, ...).
class PhotoUploadFailed extends PhotoProblem {
  const PhotoUploadFailed(this.error);

  final ApiError error;
}

/// The result of [TicketThreadController.attachPhoto]: the uploaded photo,
/// or why not. Both null when the rider cancelled the picker.
typedef PhotoResult = ({UploadedAttachment? photo, PhotoProblem? problem});

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

  /// Sends [message] with the photos [attachmentKeys]. Returns null when
  /// sent (the thread is the server's answer), else the error to show; the
  /// typed text and photos are kept by the screen.
  Future<ApiError?> reply(
    String message, {
    List<String> attachmentKeys = const [],
  }) async {
    final text = message.trim();
    if (text.isEmpty) return null;
    try {
      final thread = await ref
          .read(supportRepositoryProvider)
          .reply(ticketId, text, attachmentKeys: attachmentKeys);
      if (ref.mounted) state = AsyncData(thread);
      return null;
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (ref.mounted) reportAppControlError(ref, error);
      return error;
    }
  }

  /// Takes or picks a photo, compresses it on the phone (EXIF dropped, at
  /// most [kTicketPhotoMaxBytes]) and uploads it to this ticket. The
  /// original file is always deleted.
  Future<PhotoResult> attachPhoto(ImagePickSource source) async {
    final picker = ref.read(kycImagePickerProvider);
    final codec = ref.read(imageCodecProvider);
    final repo = ref.read(supportRepositoryProvider);
    final PickedImage? picked;
    try {
      picked = await picker.pick(source, selfie: false);
    } on Object {
      // No camera, or the picker failed: nothing was taken.
      return (photo: null, problem: const PhotoUnreadable());
    }
    if (picked == null) return (photo: null, problem: null);
    final CompressedImage image;
    try {
      image = await compressToLimit(
        codec: codec,
        sourcePath: picked.path,
        maxBytes: kTicketPhotoMaxBytes,
      );
    } on ImageTooLargeException {
      return (photo: null, problem: const PhotoTooLarge());
    } on Object {
      return (photo: null, problem: const PhotoUnreadable());
    } finally {
      await picker.discard(picked);
    }
    try {
      final photo = await repo.uploadPhoto(ticketId, image.bytes);
      return (photo: photo, problem: null);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (error.statusCode == 413) {
        return (photo: null, problem: const PhotoTooLarge());
      }
      if (ref.mounted) reportAppControlError(ref, error);
      return (photo: null, problem: PhotoUploadFailed(error));
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

/// What the form opens with: from the help screen (nothing), "Get help with
/// this order" on a past task (TASK, its id and order number) or "Get help"
/// on a payout (PAYOUT, its id and period).
typedef NewTicketArgs = ({
  RiderTicketTopic? topic,
  int? taskId,
  int? payoutId,
  String? label,
});

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
      taskId: args.taskId,
      payoutId: args.payoutId,
      label: args.label,
    ),
  );

  void _edit(TicketDraft draft) =>
      state = state.copyWith(draft: draft, clearError: true);

  void setTopic(RiderTicketTopic topic) =>
      _edit(state.draft.copyWith(topic: topic));

  void setText(String text) => _edit(state.draft.copyWith(text: text));

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
