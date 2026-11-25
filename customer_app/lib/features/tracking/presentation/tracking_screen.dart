import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../location/presentation/delivery_controller.dart';
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
import 'tracking_sheet.dart';

/// Live tracking (`03 §2.10`, screen #28; Blinkit-style since T-821).
///
/// While the order is on its way and the build has a Maps key, a full-screen
/// map (store, you, the rider gliding along the server's road route) sits
/// behind a draggable sheet with the status, ETA, distance, freshness, the
/// delivery OTP, the rider (call), help and the 8-step timeline. Without a
/// key, or once the order is finished, the same content is one scrolling
/// page with the route sketch. Updates arrive over the order socket
/// (`06 §4`), with `track/` polling while it is down.
///
/// Rebuilds: the screen `select`s [OrderTrack.settled], so a rider ping
/// only rebuilds the map, the distance and the freshness line.
class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The order itself, for the payment side (COD amount due, refund note);
    // best effort: tracking still shows without it.
    final order = ref.watch(orderDetailProvider(orderId)).value;
    ref.listen<OrderStatus?>(
      trackProvider(orderId).select((a) => a.value?.status),
      (before, status) {
        if (status != null && before != null && status != before) {
          ref.read(orderDetailProvider(orderId).notifier).refreshQuietly();
        }
      },
    );
    final (track, error) = ref.watch(
      trackProvider(orderId)
          .select((a) => (a.value?.settled, a.hasValue ? null : a.error)),
    );
    final hasMaps = ref.watch(mapsAvailableProvider).value ?? false;
    final Widget body;
    if (track != null) {
      final onMap =
          hasMaps &&
          track.status.isActive &&
          track.status != OrderStatus.deliveryFailed;
      body = onMap
          ? _MapLayout(track: track, order: order)
          : RefreshIndicator(
              onRefresh: () => ref.read(trackProvider(orderId).notifier).poll(),
              child: ListView(
                key: const Key('tracking'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(JivoSpacing.gutter),
                children: trackSheetChildren(
                  context,
                  ref,
                  track,
                  order,
                  withSketch: true,
                ),
              ),
            );
    } else if (error != null) {
      body = ErrorRetryView(
        error: error,
        onRetry: () => ref.invalidate(trackProvider(orderId)),
      );
    } else {
      body = const SkeletonList(rows: 4);
    }
    return Theme(
      data: lightPageTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          leading: homeBackButton(context),
          title: Text(l10n.trackOrder),
        ),
        body: body,
      ),
    );
  }
}

/// The full-screen map with the floating, draggable sheet.
class _MapLayout extends ConsumerWidget {
  const _MapLayout({required this.track, this.order});

  final OrderTrack track;
  final OrderDetail? order;

  static const _initial = 0.42;
  static const _min = 0.22;
  static const _max = 0.92;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxHeight * _initial;
        return Stack(
          children: [
            Positioned.fill(
              child: TrackMap(orderId: track.orderId, bottomInset: inset),
            ),
            DraggableScrollableSheet(
              initialChildSize: _initial,
              minChildSize: _min,
              maxChildSize: _max,
              builder: (context, controller) => DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(JivoRadii.xl),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(trackProvider(track.orderId).notifier).poll(),
                  child: ListView(
                    key: const Key('tracking'),
                    controller: controller,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      JivoSpacing.gutter,
                      0,
                      JivoSpacing.gutter,
                      JivoSpacing.gutter,
                    ),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.symmetric(
                            vertical: JivoSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      ...trackSheetChildren(
                        context,
                        ref,
                        track,
                        order,
                        withSketch: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The timeline steps for a tracked order from its status only: the
/// fallback when the server sends no `progress` (an older server).
List<TimelineStep> trackTimeline(OrderTrack track) => timelineFor(track.status);

/// The sheet's content, shared by the map sheet and the no-map page:
/// status with ETA and distance, freshness, OTP, cash due, the rider,
/// the delivery stage, the route sketch ([withSketch], no-map page), the
/// 8 steps, help, rating and order details.
List<Widget> trackSheetChildren(
  BuildContext context,
  WidgetRef ref,
  OrderTrack track,
  OrderDetail? order, {
  required bool withSketch,
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final rider = track.rider;
  final otp = track.visibleDeliveryOtp;
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
  final timeline = track.timeline;
  const gap = SizedBox(height: JivoSpacing.lg);
  return [
    Semantics(
      liveRegion: true,
      child: Text(
        orderStatusLabel(l10n, status),
        key: const Key('tracking-status'),
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    const SizedBox(height: JivoSpacing.xs),
    Text(
      l10n.orderNumber(track.orderNumber),
      key: const Key('tracking-order-number'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    if (eta != null && active && !failed) ...[
      const SizedBox(height: JivoSpacing.md),
      Wrap(
        spacing: JivoSpacing.md,
        runSpacing: JivoSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          EtaCountdown(
            etaAt: eta,
            status: status,
            orderId: track.orderId,
            now: ref.read(trackClockProvider),
          ),
          TrackDistanceLeft(orderId: track.orderId),
        ],
      ),
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
      Text(l10n.trackingCancelledBody, key: const Key('tracking-cancelled')),
    ],
    if (active && !failed) ...[
      const SizedBox(height: JivoSpacing.md),
      TrackFreshnessLine(orderId: track.orderId),
    ],
    gap,
    if (otp != null && status == OrderStatus.outForDelivery) ...[
      DeliveryOtpCard(otp: otp, atDoor: stage == DeliveryStage.arriving),
      gap,
    ],
    if (codDue != null) ...[CodDueCard(amount: codDue), gap],
    if (rider != null) ...[
      RiderCard(rider: rider, canCall: track.outForDelivery),
      gap,
    ] else if (assigning && active) ...[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.hourglass_top),
        title: Text(l10n.trackingRiderAssigning),
      ),
      gap,
    ],
    if (stage != null) ...[
      DeliveryStageCard(
        stage: stage,
        refundNote: detail == null ? null : refundNoteFor(l10n, detail),
      ),
      gap,
    ],
    if (withSketch && active && !failed) ...[
      TrackMap(orderId: track.orderId, height: 220),
      gap,
    ],
    if (!cancelled) ...[
      if (timeline != null && timeline.steps.isNotEmpty)
        TrackProgressTimeline(timeline: timeline)
      else
        OrderTimeline(
          steps: detail == null
              ? trackTimeline(track)
              : timelineFor(
                  status,
                  history: detail.history,
                  placedAt: detail.placedAt,
                ),
        ),
      gap,
    ],
    TrackHelpButton(orderId: track.orderId),
    const SizedBox(height: JivoSpacing.md),
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
  ];
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
    final action = orderId == null
        ? null
        : trackHelpAction(context, ref, orderId);
    final VoidCallback? onHelp = action?.onTap;
    final String helpLabel = action == null
        ? ''
        : (action.ticket ? l10n.trackingGetHelp : l10n.callSupport);
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

/// A store-to-customer line with the rider on it: the map's fallback when
/// the build has no Maps API key.
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
