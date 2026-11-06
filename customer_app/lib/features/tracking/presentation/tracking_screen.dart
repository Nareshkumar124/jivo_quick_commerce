import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../orders/domain/order_history.dart';
import '../../orders/presentation/order_history_controllers.dart';
import '../../orders/presentation/order_detail_screen.dart' show homeBackButton;
import '../../orders/presentation/order_texts.dart';
import '../../orders/presentation/order_timeline.dart';
import '../domain/order_track.dart';
import 'delivery_cards.dart';
import 'tracking_providers.dart';

/// Live tracking (`03 §2.10`, screen #28; Phase 6, built ahead on fake
/// data): status timeline, ETA countdown, a route sketch with the store,
/// the customer and the rider, the rider card with a call button, and the
/// delivery OTP. The Mappls map replaces the sketch when tracking is bound
/// (Phase 6).
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
    return ListView(
      key: const Key('tracking'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            orderStatusLabel(l10n, track.status),
            key: const Key('tracking-status'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (eta != null && track.status.isActive) EtaCountdown(etaAt: eta),
        if (stage != null) ...[
          const SizedBox(height: JivoSpacing.md),
          DeliveryStageCard(
            stage: stage,
            refundNote: detail == null ? null : refundNoteFor(l10n, detail),
          ),
        ],
        const SizedBox(height: JivoSpacing.lg),
        RouteSketch(progress: track.progress),
        const SizedBox(height: JivoSpacing.lg),
        if (otp != null) ...[
          DeliveryOtpCard(otp: otp),
          const SizedBox(height: JivoSpacing.lg),
        ],
        if (codDue != null) ...[
          CodDueCard(amount: codDue),
          const SizedBox(height: JivoSpacing.lg),
        ],
        if (rider != null)
          RiderCard(rider: rider)
        else if (track.status.isActive)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.hourglass_top),
            title: Text(l10n.trackingRiderAssigning),
          ),
        const SizedBox(height: JivoSpacing.lg),
        OrderTimeline(steps: trackTimeline(track)),
        OutlinedButton(
          onPressed: () => context.push(Routes.order(track.orderId)),
          child: Text(l10n.trackingViewDetails),
        ),
      ],
    );
  }
}

/// "Arriving in 8 mins", counting down every 30 s from the server's ETA.
class EtaCountdown extends StatefulWidget {
  const EtaCountdown({required this.etaAt, this.now, super.key});

  final DateTime etaAt;

  /// The clock (tests).
  final DateTime Function()? now;

  @override
  State<EtaCountdown> createState() => _EtaCountdownState();
}

class _EtaCountdownState extends State<EtaCountdown> {
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
    return Text(
      minutes <= 0
          ? l10n.trackingArrivingNow
          : l10n.trackingEtaMinutes(minutes),
      key: const Key('tracking-eta'),
      style: Theme.of(context).textTheme.titleMedium,
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
