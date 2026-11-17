import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/errors/rider_error_codes.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../realtime/presentation/rider_socket_providers.dart';
import '../../shift/presentation/shift_controller.dart';
import '../../task/domain/task_repositories.dart';
import '../../task/presentation/task_flow_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../domain/delivery_offer.dart';

enum OfferPhase {
  /// No offer.
  none,

  /// Ringing, counting down; Accept / Reject.
  showing,
  accepting,
  rejecting,

  /// The countdown ran out (treated as a reject by the server).
  expired,

  /// `OFFER_TAKEN`: another rider was faster.
  taken,

  /// `offer.withdrawn`: the order was cancelled (04 §2.4 "Order cancelled").
  withdrawn,
}

@immutable
class OfferState {
  const OfferState({
    this.phase = OfferPhase.none,
    this.offer,
    this.countdown,
    this.error,
  });

  final OfferPhase phase;
  final DeliveryOffer? offer;
  final OfferCountdown? countdown;

  /// A failed accept that left the offer open (e.g. no network).
  final ApiError? error;

  /// The offer screen is the rider's screen.
  bool get isOpen => phase != OfferPhase.none;

  bool get isEnded =>
      phase == OfferPhase.expired ||
      phase == OfferPhase.taken ||
      phase == OfferPhase.withdrawn;
}

/// `GET /rider/offers/current/` every 5 s while online, idle, in the
/// foreground and the rider socket is down (the contract's polling
/// fallback, 06 §4.1).
const kOfferPollInterval = Duration(seconds: 5);

/// The poll interval ([kOfferPollInterval]); shortened in tests.
final offerPollIntervalProvider = Provider<Duration>(
  (ref) => kOfferPollInterval,
);

/// Tests that do not exercise the offer poll may turn it off.
final offerPollingEnabledProvider = Provider<bool>((ref) => true);

final offerControllerProvider = NotifierProvider<OfferController, OfferState>(
  OfferController.new,
);

/// The incoming offer (04 §2.4): arrives by push (FCM in P5, WebSocket in P6)
/// or by polling `GET /rider/offers/current/`, counts down to the server's
/// `expires_at`, and is accepted or rejected. The server settles every race:
/// `OFFER_EXPIRED`, `OFFER_TAKEN` and `offer.withdrawn` end the offer.
class OfferController extends Notifier<OfferState> {
  OfferRepository get _repo => ref.read(offerRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  OfferState build() {
    if (!ref.watch(riderWorkActiveProvider)) return const OfferState();
    final subscription = ref
        .watch(offerEventSourceProvider)
        .events
        .listen(_onEvent);
    final lifecycle = AppLifecycleListener(
      onResume: () {
        _startPolling();
        unawaited(refresh());
      },
      onHide: _stopPolling,
      onPause: _stopPolling,
    );
    ref.onDispose(() {
      subscription.cancel();
      lifecycle.dispose();
      _stopPolling();
    });
    // A task that starts (accepted here, or assigned by ops, `task.updated`
    // ASSIGNED) ends what the offer screen still holds: one order at a
    // time, and an unread "Order cancelled" must not come back once the
    // task is done (P8). An accept in flight closes the offer itself.
    ref.listen(taskFlowControllerProvider.select((s) => s.hasTask), (
      _,
      hasTask,
    ) {
      if (!hasTask ||
          state.phase == OfferPhase.none ||
          state.phase == OfferPhase.accepting) {
        return;
      }
      _forget(state.offer);
      _stopRinging();
      state = const OfferState();
    });
    _startPolling();
    // Polls once when the rider becomes active (app start, including a
    // start from an offer notification).
    Future.microtask(refresh);
    return const OfferState();
  }

  Timer? _poll;

  void _startPolling() {
    _poll?.cancel();
    if (!ref.read(offerPollingEnabledProvider)) return;
    _poll = Timer.periodic(ref.read(offerPollIntervalProvider), (_) {
      if (!ref.mounted) return;
      // Online only: an offline rider gets no offers (and is not tracked).
      if (!ref.read(shiftControllerProvider).isOnline) return;
      // The socket delivers offers while it is up.
      if (ref.read(riderSocketConnectedProvider)) return;
      unawaited(refresh());
    });
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  void _onEvent(OfferEvent event) {
    switch (event) {
      case OfferArrived(:final received):
        present(received);
      case OfferWithdrawn(:final offerId, :final reason):
        withdrawn(offerId, reason: reason);
    }
  }

  /// One order at a time (08 §5): no offers while a task is active.
  bool get _busyWithTask => ref.read(taskFlowControllerProvider).hasTask;

  /// Offers that ended on this phone (rejected, expired, taken, withdrawn,
  /// closed): never shown again, even if a poll still finds one pending on
  /// the server (a reject that never arrived, a server clock a little
  /// behind). Before P8 such an offer rang again after the rider said no.
  final _ended = <int>{};

  void _forget(DeliveryOffer? offer) {
    if (offer == null) return;
    _ended.add(offer.id);
    // A shift sees few offers; keep the set small anyway.
    if (_ended.length > 50) _ended.remove(_ended.first);
  }

  /// Shows [received] unless another offer or a task is in progress.
  void present(ReceivedOffer received) {
    if (_busyWithTask) return;
    if (state.phase != OfferPhase.none && !state.isEnded) return;
    if (_ended.contains(received.offer.id)) return;
    final countdown = OfferCountdown(
      expiresAt: received.offer.expiresAt,
      receivedAt: _now(),
      serverNow: received.serverNow,
    );
    if (countdown.isExpired(_now())) return;
    state = OfferState(
      phase: OfferPhase.showing,
      offer: received.offer,
      countdown: countdown,
    );
  }

  /// Polling fallback (and the app start from an offer notification).
  Future<void> refresh() async {
    if (!ref.read(riderWorkActiveProvider) || _busyWithTask) return;
    if (state.phase != OfferPhase.none) return;
    try {
      final received = await _repo.fetchCurrentOffer();
      if (received != null && ref.mounted) present(received);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (ref.mounted) reportAppControlError(ref, error);
      debugPrint('OfferController.refresh: ${error.code}');
    }
  }

  /// The rider tapped an offer notification (an FCM `offer.new`, or the
  /// offer alarm). The server decides: its current offer is shown; if it
  /// has none (the offer expired, was taken or withdrawn while the
  /// notification was up), the offer screen says "Offer expired" for
  /// [offerId]. An open offer, a task, or a failed fetch change nothing.
  Future<void> openFromNotification(int? offerId) async {
    if (!ref.read(riderWorkActiveProvider) || _busyWithTask) return;
    if (state.isOpen && !state.isEnded) return;
    if (state.isEnded && state.offer?.id != offerId) acknowledge();
    if (state.isEnded) return; // already says how this offer ended
    final ReceivedOffer? received;
    try {
      received = await _repo.fetchCurrentOffer();
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (ref.mounted) reportAppControlError(ref, error);
      debugPrint('OfferController.openFromNotification: ${error.code}');
      return;
    }
    if (!ref.mounted || _busyWithTask) return;
    if (received != null) present(received);
    if (state.isOpen || offerId == null) return;
    _ended.add(offerId);
    state = const OfferState(phase: OfferPhase.expired);
  }

  /// Called every second by the offer screen. Never ends an offer while the
  /// accept is in flight: the server's answer wins.
  void tick() {
    final countdown = state.countdown;
    if (state.phase != OfferPhase.showing || countdown == null) return;
    if (countdown.isExpired(_now())) _end(OfferPhase.expired);
  }

  Future<void> accept() async {
    final offer = state.offer;
    if (state.phase != OfferPhase.showing || offer == null) return;
    if (state.countdown?.isExpired(_now()) ?? false) {
      _end(OfferPhase.expired);
      return;
    }
    state = OfferState(
      phase: OfferPhase.accepting,
      offer: offer,
      countdown: state.countdown,
    );
    try {
      final task = await _repo.accept(offer.id);
      if (!ref.mounted) return;
      _stopRinging();
      ref.read(taskFlowControllerProvider.notifier).assigned(task);
      state = const OfferState();
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return;
      if (reportAppControlError(ref, error)) {
        _end(OfferPhase.expired);
        return;
      }
      if (error.riderCode == RiderErrorCode.riderOffline) {
        // Certain, not a lost answer: the server already set the rider
        // offline. Retrying the accept can never work (P8).
        _closeAfterServerOffline();
        return;
      }
      switch (error.code) {
        case ApiErrorCode.offerExpired:
          _end(OfferPhase.expired);
        case ApiErrorCode.offerTaken:
          _end(OfferPhase.taken);
        default:
          await _afterUncertainAccept(error);
      }
    }
  }

  /// The accept may have reached the server although the answer was lost:
  /// if a task is now assigned, go to it; otherwise keep the offer open
  /// while time is left.
  Future<void> _afterUncertainAccept(ApiError error) async {
    final tasks = ref.read(taskFlowControllerProvider.notifier);
    // Forced: a refresh already in flight must not swallow this answer.
    await tasks.load(force: true);
    if (!ref.mounted) return;
    if (ref.read(taskFlowControllerProvider).task != null) {
      _stopRinging();
      state = const OfferState();
      return;
    }
    final countdown = state.countdown;
    if (countdown == null || countdown.isExpired(_now())) {
      _end(OfferPhase.expired);
      return;
    }
    state = OfferState(
      phase: OfferPhase.showing,
      offer: state.offer,
      countdown: countdown,
      error: error,
    );
  }

  /// Declines with an optional reason. The offer closes on the phone even
  /// if the call fails: the server treats an unanswered offer as rejected.
  Future<void> reject({OfferRejectReason? reason}) async {
    final offer = state.offer;
    if (state.phase != OfferPhase.showing || offer == null) return;
    state = OfferState(
      phase: OfferPhase.rejecting,
      offer: offer,
      countdown: state.countdown,
    );
    _forget(offer);
    _stopRinging();
    try {
      await _repo.reject(offer.id, reason: reason);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (ref.mounted) reportAppControlError(ref, error);
      debugPrint('OfferController.reject: ${error.code}');
    }
    if (ref.mounted) state = const OfferState();
  }

  /// `offer.withdrawn` / `offer.expired`: the offer ended on the server.
  /// The text follows the reason: expired, taken, or cancelled.
  void withdrawn(
    int offerId, {
    OfferEndReason reason = OfferEndReason.cancelled,
  }) {
    if (state.offer?.id != offerId) return;
    // An accept in flight gets its own answer (OFFER_TAKEN or a task).
    if (state.phase == OfferPhase.showing ||
        state.phase == OfferPhase.rejecting) {
      switch (reason) {
        case OfferEndReason.riderOffline:
          _closeAfterServerOffline();
        case OfferEndReason.cancelled:
          _end(OfferPhase.withdrawn);
        case OfferEndReason.expired:
          _end(OfferPhase.expired);
        case OfferEndReason.taken:
          _end(OfferPhase.taken);
      }
    }
  }

  /// The server set the rider offline (`RIDER_OFFLINE`): no offer can be
  /// taken. The offer closes and the shift controller asks the server
  /// (`rider_heartbeat`), which stops tracking and shows home's "You were
  /// set offline" with the server's reason (auto-offline or ops).
  void _closeAfterServerOffline() {
    _forget(state.offer);
    _stopRinging();
    state = const OfferState();
    unawaited(ref.read(shiftControllerProvider.notifier).sync());
  }

  /// The rider read the expired / taken / withdrawn message.
  void acknowledge() {
    if (state.isEnded) state = const OfferState();
  }

  void _end(OfferPhase phase) {
    _forget(state.offer);
    _stopRinging();
    state = OfferState(phase: phase, offer: state.offer);
  }

  void _stopRinging() => unawaited(ref.read(offerAlerterProvider).stop());
}
