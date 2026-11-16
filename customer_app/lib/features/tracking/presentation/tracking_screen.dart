import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_history.dart';
import '../../orders/presentation/order_history_controllers.dart';
import '../../orders/presentation/order_detail_screen.dart' show homeBackButton;
import '../../orders/presentation/order_texts.dart';
import '../../orders/presentation/order_timeline.dart';
import '../domain/order_track.dart';
import 'delivery_cards.dart';
import 'tracking_map.dart';
import 'tracking_providers.dart';

/// Live tracking (`03 §2.10`, screen #28): status timeline, ETA
/// countdown, the Mappls map (or the route sketch without Mappls) with the
/// store, the customer and the rider, the rider card with a call button,
/// and the delivery OTP. Updates arrive over the order socket (`06 §4`),
/// with `track/` polling while it is down.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The order itself, for the payment side (COD amount due, refund note);
    // best effort: tracking still shows without it.
    final order = ref.watch(orderDetailProvider(orderId)).value;
    ref.listen<AsyncValue<OrderTrack>>(trackProvider(orderId), (prev, next) {
      final status = next.value?.status;
      final before = prev?.value?.status;
      if (status != null && before != null && status != before) {
        ref.read(orderDetailProvider(orderId).notifier).refreshQuietly();
      }
    });
    return Scaffold(
      appBar: AppBar(
        leading: homeBackButton(context),
        title: Text(l10n.trackOrder),
      ),
      body: switch (ref.watch(trackProvider(orderId))) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.read(trackProvider(orderId).notifier).poll(),
          child: _TrackBody(track: value, order: order),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(trackProvider(orderId)),
        ),
        _ => const SkeletonList(rows: 4),
      },
    );
  }
}

/// The timeline steps for a tracked order (status only; the order detail
/// shows the full history).
List<TimelineStep> trackTimeline(OrderTrack track) => timelineFor(track.status);

class _TrackBody extends ConsumerWidget {
  const _TrackBody({required this.track, this.order});

  final OrderTrack track;
  final OrderDetail? order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rider = track.rider;
    final otp = track.deliveryOtp;
    final eta = track.etaAt;
    final stage = track.stage;
    final detail = order;
    final codDue = detail != null && detail.status == track.status
        ? detail.codAmountDue
        : null;
    final status = track.status;
    final active = status.isActive;
    final failed =
        status == OrderStatus.deliveryFailed || status == OrderStatus.returned;
    final cancelled =
        status == OrderStatus.cancelled || status == OrderStatus.paymentFailed;
    final delivered = status == OrderStatus.delivered;
    final deliveredAt = delivered && detail != null
        ? detail.history
              .where((e) => e.status == OrderStatus.delivered)
              .map((e) => e.at)
              .firstOrNull
        : null;
    final assigning =
        rider == null &&
        const {
          DeliveryTaskStatus.searching,
          DeliveryTaskStatus.offered,
          DeliveryTaskStatus.unassigned,
        }.contains(track.taskStatus);
    return ListView(
      key: const Key('tracking'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            orderStatusLabel(l10n, status),
            key: const Key('tracking-status'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (eta != null && active && !failed) ...[
          const SizedBox(height: JivoSpacing.md),
          EtaCountdown(etaAt: eta, status: status, orderId: track.orderId),
        ],
        if (deliveredAt != null) ...[
          const SizedBox(height: JivoSpacing.xs),
          Text(
            l10n.trackingDeliveredAt(formatTime(deliveredAt)),
            key: const Key('tracking-delivered-at'),
            style: theme.textTheme.titleMedium,
          ),
        ],
        if (cancelled) ...[
          const SizedBox(height: JivoSpacing.md),
          Text(
            l10n.trackingCancelledBody,
            key: const Key('tracking-cancelled'),
          ),
        ],
        if (active && !failed) ...[
          const SizedBox(height: JivoSpacing.md),
          _FreshnessLine(orderId: track.orderId),
        ],
        const SizedBox(height: JivoSpacing.lg),
        if (otp != null && status == OrderStatus.outForDelivery) ...[
          DeliveryOtpCard(otp: otp, atDoor: stage == DeliveryStage.arriving),
          const SizedBox(height: JivoSpacing.lg),
        ],
        if (codDue != null) ...[
          CodDueCard(amount: codDue),
          const SizedBox(height: JivoSpacing.lg),
        ],
        if (rider != null) ...[
          RiderCard(rider: rider),
          const SizedBox(height: JivoSpacing.lg),
        ] else if (assigning && active) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hourglass_top),
            title: Text(l10n.trackingRiderAssigning),
          ),
          const SizedBox(height: JivoSpacing.lg),
        ],
        if (stage != null) ...[
          DeliveryStageCard(
            stage: stage,
            refundNote: detail == null ? null : refundNoteFor(l10n, detail),
          ),
          const SizedBox(height: JivoSpacing.lg),
        ],
        if (active && !failed) ...[
          TrackMap(track: track),
          const SizedBox(height: JivoSpacing.lg),
        ],
        if (!cancelled)
          OrderTimeline(
            steps: detail == null
                ? trackTimeline(track)
                : timelineFor(
                    status,
                    history: detail.history,
                    placedAt: detail.placedAt,
                  ),
          ),
        if (delivered && ref.watch(ratingAvailableProvider)) ...[
          FilledButton(
            key: const Key('tracking-rate'),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => context.push(Routes.rateOrder(track.orderId)),
            child: Text(l10n.trackingRateOrder),
          ),
          const SizedBox(height: JivoSpacing.md),
        ],
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => context.push(Routes.order(track.orderId)),
          child: Text(l10n.trackingViewDetails),
        ),
      ],
    );
  }
}

/// "Live" / "Updated 3:45 pm" / "Can't update right now" (`§3`).
class _FreshnessLine extends ConsumerWidget {
  const _FreshnessLine({required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.jivoColors;
    final notifier = ref.read(trackProvider(orderId).notifier);
    return ValueListenableBuilder<TrackFreshness>(
      valueListenable: notifier.freshness,
      builder: (context, fresh, _) {
        final at = fresh.lastUpdatedAt;
        final time = at == null ? '' : formatTime(at);
        final small = theme.textTheme.bodySmall;
        switch (fresh.mode) {
          case TrackFreshMode.live:
            return Row(
              key: const Key('tracking-fresh-live'),
              children: [
                Icon(Icons.circle, size: 8, color: colors.success),
                const SizedBox(width: JivoSpacing.xs),
                Text(
                  l10n.trackingLive,
                  style: small?.copyWith(color: colors.success),
                ),
              ],
            );
          case TrackFreshMode.polling:
            return Row(
              key: const Key('tracking-fresh-polling'),
              children: [
                Icon(Icons.sync, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: JivoSpacing.xs),
                Flexible(
                  child: Text(l10n.trackingUpdatedAt(time), style: small),
                ),
              ],
            );
          case TrackFreshMode.stale:
            return Semantics(
              liveRegion: true,
              container: true,
              child: Container(
                key: const Key('tracking-fresh-stale'),
                padding: const EdgeInsets.all(JivoSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(JivoRadii.sm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, size: 16, color: colors.warning),
                    const SizedBox(width: JivoSpacing.sm),
                    Expanded(
                      child: Text(l10n.trackingStale(time), style: small),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}

/// "Arriving in 8 mins", counting down every 30 s from the server's ETA.
class EtaCountdown extends ConsumerStatefulWidget {
  const EtaCountdown({
    required this.etaAt,
    this.status,
    this.orderId,
    this.now,
    super.key,
  });

  final DateTime etaAt;

  /// Picks the late wording; null never shows the late notice.
  final OrderStatus? status;
  final int? orderId;

  /// The clock (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<EtaCountdown> createState() => _EtaCountdownState();
}

class _EtaCountdownState extends ConsumerState<EtaCountdown> {
  static const _lateAfter = Duration(minutes: 5);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = (widget.now ?? DateTime.now)().toUtc();
    final left = widget.etaAt.toUtc().difference(now);
    // Round up: 7 min 10 s left reads "8 mins".
    final minutes = (left.inSeconds + 59) ~/ 60;
    final status = widget.status;
    if (status != null && -left > _lateAfter) {
      return _lateNotice(context, status);
    }
    return Text(
      minutes <= 0
          ? l10n.trackingArrivingNow
          : l10n.trackingEtaMinutes(minutes),
      key: const Key('tracking-eta'),
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _lateNotice(BuildContext context, OrderStatus status) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.jivoColors;
    final preparing = status != OrderStatus.outForDelivery;
    final orderId = widget.orderId;
    final phone = ref.watch(launchStateProvider).config?.supportPhone;
    final VoidCallback? onHelp;
    final String helpLabel;
    if (orderId != null && ref.watch(supportAvailableProvider)) {
      helpLabel = l10n.trackingGetHelp;
      onHelp = () => context.push(Routes.newTicket(orderId: orderId));
    } else if (phone != null && phone.isNotEmpty) {
      helpLabel = l10n.callSupport;
      onHelp = () =>
          ref.read(urlOpenerProvider).open(Uri(scheme: 'tel', path: phone));
    } else {
      helpLabel = '';
      onHelp = null;
    }
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('tracking-late'),
        padding: const EdgeInsets.all(JivoSpacing.md),
        decoration: BoxDecoration(
          color: colors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(JivoRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, color: colors.warning),
                const SizedBox(width: JivoSpacing.sm),
                Expanded(
                  child: Text(
                    preparing
                        ? l10n.trackingLatePreparing
                        : l10n.trackingLateOnTheWay,
                    key: const Key('tracking-eta'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (onHelp != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('tracking-get-help'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onHelp,
                  child: Text(helpLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A store-to-customer line with the rider on it, until the Mappls map
/// arrives with live tracking (Phase 6).
class RouteSketch extends StatelessWidget {
  const RouteSketch({required this.progress, super.key});

  /// 0 at the store, 1 at the customer.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final success = context.jivoColors.success;
    return Semantics(
      label: l10n.trackingMapSemantics((progress * 100).round()),
      child: ExcludeSemantics(
        child: Container(
          key: const Key('route-sketch'),
          height: 120,
          padding: const EdgeInsets.all(JivoSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(JivoRadii.md),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const icon = 32.0;
              final track = constraints.maxWidth - icon;
              return Stack(
                children: [
                  Positioned(
                    left: icon / 2,
                    right: icon / 2,
                    top: icon / 2 - 1,
                    child: Container(height: 2, color: scheme.outline),
                  ),
                  Positioned(
                    left: icon / 2,
                    top: icon / 2 - 2,
                    width: track * progress,
                    child: Container(height: 4, color: success),
                  ),
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: Icon(Icons.storefront, size: icon),
                  ),
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.home_outlined, size: icon),
                  ),
                  Positioned(
                    left: track * progress,
                    top: icon + JivoSpacing.xs,
                    child: Icon(
                      Icons.delivery_dining,
                      size: icon,
                      color: scheme.primary,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text(l10n.trackingMapStore),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(l10n.trackingMapHome),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
