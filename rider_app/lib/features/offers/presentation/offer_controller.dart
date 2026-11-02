import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../auth/presentation/rider_account_controller.dart';
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
      onResume: () => unawaited(refresh()),
    );
    ref.onDispose(() {
      subscription.cancel();
      lifecycle.dispose();
    });
    // Polls once when the rider becomes active (app start, including a
    // start from an offer notification).
    Future.microtask(refresh);
    return const OfferState();
  }

  void _onEvent(OfferEvent event) {
    switch (event) {
      case OfferArrived(:final received):
        present(received);
      case OfferWithdrawn(:final offerId):
        withdrawn(offerId);
    }
  }

  /// One order at a time (08 §5): no offers while a task is active.
  bool get _busyWithTask => ref.read(taskFlowControllerProvider).hasTask;

  /// Shows [received] unless another offer or a task is in progress.
  void present(ReceivedOffer received) {
    if (_busyWithTask) return;
    if (state.phase != OfferPhase.none && !state.isEnded) return;
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

  /// `offer.withdrawn`: the order was cancelled before pickup.
  void withdrawn(int offerId) {
    if (state.offer?.id != offerId) return;
    // An accept in flight gets its own answer (OFFER_TAKEN or a task).
    if (state.phase == OfferPhase.showing ||
        state.phase == OfferPhase.rejecting) {
      _end(OfferPhase.withdrawn);
    }
  }

  /// The rider read the expired / taken / withdrawn message.
  void acknowledge() {
    if (state.isEnded) state = const OfferState();
  }

  void _end(OfferPhase phase) {
    _stopRinging();
    state = OfferState(phase: phase, offer: state.offer);
  }

  void _stopRinging() => unawaited(ref.read(offerAlerterProvider).stop());
}
