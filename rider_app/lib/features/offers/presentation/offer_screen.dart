import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../launch/presentation/blocking_message.dart';
import '../../task/domain/rider_task.dart';
import '../../task/domain/task_rules.dart';
import '../../task/presentation/task_providers.dart';
import '../../task/presentation/task_text.dart';
import '../domain/delivery_offer.dart';
import 'offer_controller.dart';

/// The incoming offer, full screen (04 §2.4, screen 9): store, drop
/// locality, distance, Prepaid / COD amount, estimated payout and the
/// countdown to the server's `expires_at`. Rings through the offer channel.
class OfferScreen extends ConsumerStatefulWidget {
  const OfferScreen({super.key});

  @override
  ConsumerState<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<OfferScreen> {
  Timer? _ticker;
  int? _rangFor;
  int? _lastHapticSecond;

  /// The reject-reason sheet is open; it is closed when the offer ends
  /// (expired, taken, withdrawn) so no reject is sent for a dead offer.
  bool _sheetOpen = false;

  /// The last 10 s get the danger colour, the "s" unit and a haptic tick;
  /// the last 5 s also say "Expiring" (UX audit RD-04).
  static const urgentSeconds = 10;
  static const expiringSeconds = 5;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(offerControllerProvider.notifier).tick();
      _hapticTick();
      if (mounted) setState(() {});
    });
  }

  void _hapticTick() {
    final state = ref.read(offerControllerProvider);
    final countdown = state.countdown;
    if (state.phase != OfferPhase.showing || countdown == null) return;
    final seconds = countdown.secondsLeft(ref.read(clockProvider)());
    if (seconds > 0 &&
        seconds <= urgentSeconds &&
        seconds != _lastHapticSecond) {
      _lastHapticSecond = seconds;
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Rings once per offer, for the time it has left.
  void _ringIfNew(OfferState state) {
    final offer = state.offer;
    final countdown = state.countdown;
    if (state.phase != OfferPhase.showing ||
        offer == null ||
        countdown == null ||
        _rangFor == offer.id) {
      return;
    }
    _rangFor = offer.id;
    final l10n = AppLocalizations.of(context);
    unawaited(
      ref
          .read(offerAlerterProvider)
          .ring(
            offer,
            title: l10n.offerAlertTitle,
            body: l10n.offerAlertBody(offer.storeName, offer.dropLocality),
            timeout: countdown.remaining(ref.read(clockProvider)()),
          ),
    );
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    _sheetOpen = true;
    final reason = await showModalBottomSheet<_RejectChoice>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.offerRejectTitle)),
            for (final reason in OfferRejectReason.values)
              ListTile(
                key: Key('reject-${reason.wireValue}'),
                minTileHeight: 56,
                title: Text(_rejectReasonText(l10n, reason)),
                onTap: () => Navigator.of(sheet).pop(_RejectChoice(reason)),
              ),
            ListTile(
              key: const Key('reject-skip'),
              minTileHeight: 56,
              title: Text(l10n.offerRejectSkip),
              onTap: () => Navigator.of(sheet).pop(const _RejectChoice(null)),
            ),
          ],
        ),
      ),
    );
    _sheetOpen = false;
    if (reason == null || !mounted) return;
    if (ref.read(offerControllerProvider).phase != OfferPhase.showing) return;
    await ref
        .read(offerControllerProvider.notifier)
        .reject(reason: reason.reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(offerControllerProvider);
    ref.listen(offerControllerProvider.select((s) => s.phase), (_, phase) {
      if (_sheetOpen && phase != OfferPhase.showing) {
        _sheetOpen = false;
        Navigator.of(context).pop();
      }
    });
    _ringIfNew(state);
    final controller = ref.read(offerControllerProvider.notifier);
    final offer = state.offer;

    if (!state.isEnded && offer == null) {
      // Accepted or rejected: the router is leaving this screen. Never show
      // an end message here (it would read "Offer expired" while leaving).
      return const Scaffold(body: SizedBox.shrink());
    }
    if (state.isEnded || offer == null) {
      final (icon, title, body) = switch (state.phase) {
        OfferPhase.taken => (
          Icons.directions_bike,
          l10n.offerTakenTitle,
          l10n.offerTakenBody,
        ),
        OfferPhase.withdrawn => (
          Icons.cancel_outlined,
          l10n.offerWithdrawnTitle,
          l10n.offerWithdrawnBody,
        ),
        _ => (Icons.timer_off, l10n.offerExpiredTitle, l10n.offerExpiredBody),
      };
      return Scaffold(
        body: BlockingMessage(
          icon: icon,
          title: title,
          body: body,
          actions: [
            FilledButton(
              key: const Key('offer-ok'),
              onPressed: controller.acknowledge,
              child: Text(l10n.offerOk),
            ),
          ],
        ),
      );
    }

    final now = ref.read(clockProvider)();
    final seconds = state.countdown?.secondsLeft(now) ?? 0;
    final fraction =
        (state.countdown?.remaining(now).inMilliseconds ?? 0) /
        kOfferWindow.inMilliseconds;
    final accepting = state.phase == OfferPhase.accepting;
    final rejecting = state.phase == OfferPhase.rejecting;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.offerTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              _Countdown(seconds: seconds, fraction: fraction),
              const SizedBox(height: 24),
              _OfferRow(icon: Icons.store, text: offer.storeName),
              _OfferRow(
                key: const Key('offer-drop'),
                icon: Icons.place,
                text: l10n.offerDrop(
                  offer.dropLocality,
                  distanceText(l10n, offer.distanceKm),
                ),
              ),
              if (offer.paymentType == PaymentType.cod)
                Container(
                  key: const Key('offer-payment'),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: riderCodDecoration(context),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments,
                        size: 28,
                        color: RiderColors.of(context).codText,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          switch (tryFormatRupees(offer.codAmount)) {
                            final amount? => l10n.offerCod(amount),
                            null => l10n.offerCodAmountMissing,
                          },
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: RiderColors.of(context).codText,
                              ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  key: const Key('offer-payment'),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: RiderColors.of(context).neutralContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.payments,
                        size: 28,
                        color: RiderColors.of(context).textPrimary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          l10n.offerPrepaid,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: RiderColors.of(context).textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _OfferRow(
                icon: Icons.account_balance_wallet,
                text: l10n.offerPayout(formatRupees(offer.estimatedPayout)),
              ),
            ],
          ),
        ),
        bottomNavigationBar: PrimaryActionBar(
          buttonKey: const Key('offer-accept'),
          label: l10n.offerAccept,
          // Accept is the bottom-most, 64 dp target; Reject sits above it
          // with 16 dp between (RD-04).
          secondaryAbove: true,
          primaryHeight: kRiderAcceptHeight,
          busy: accepting,
          onPressed: rejecting ? null : controller.accept,
          errorKey: const Key('offer-error'),
          error: state.error == null
              ? null
              : taskErrorText(context, state.error!),
          secondary: [
            OutlinedButton(
              key: const Key('offer-reject'),
              onPressed: accepting || rejecting ? null : _reject,
              child: Text(l10n.offerReject),
            ),
          ],
        ),
      ),
    );
  }
}

/// The countdown ring (RD-04): green until the last 10 s, then the danger
/// colour with the "s" unit, plus "Expiring" in the last 5 s. TalkBack
/// reads "Time left to accept: N seconds"; "Expiring" is a live region, so
/// it is announced when it appears.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds, required this.fraction});

  final int seconds;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final urgent = seconds <= _OfferScreenState.urgentSeconds;
    final expiring = seconds <= _OfferScreenState.expiringSeconds;
    final color = urgent
        ? RiderColors.of(context).danger
        : RiderColors.of(context).onlineBg;
    // The number must fit at large text sizes (RD-12).
    final scaled = 72 * MediaQuery.textScalerOf(context).scale(1);
    final dimension = scaled > 120 ? scaled : 120.0;
    return Column(
      children: [
        Semantics(
          label: l10n.offerTimeLeft(seconds),
          container: true,
          excludeSemantics: true,
          child: SizedBox.square(
            dimension: dimension,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: fraction.clamp(0, 1),
                  strokeWidth: 10,
                  color: color,
                  backgroundColor: RiderColors.of(context).neutralContainer,
                ),
                Center(
                  child: Text(
                    urgent ? l10n.offerSecondsShort(seconds) : '$seconds',
                    key: const Key('offer-countdown'),
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expiring)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l10n.offerExpiring,
                key: const Key('offer-expiring'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: RiderColors.of(context).danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RejectChoice {
  const _RejectChoice(this.reason);

  final OfferRejectReason? reason;
}

String _rejectReasonText(AppLocalizations l10n, OfferRejectReason reason) =>
    switch (reason) {
      OfferRejectReason.tooFar => l10n.offerRejectTooFar,
      OfferRejectReason.vehicleIssue => l10n.offerRejectVehicle,
      OfferRejectReason.onBreak => l10n.offerRejectBreak,
      OfferRejectReason.other => l10n.offerRejectOther,
    };

/// One offer fact: a 28 dp icon in the text colour (not the primary, for
/// sun legibility) and 18 sp text, at least 48 dp high (offer.md §1).
class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = RiderColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 28, color: colors.textPrimary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 18, color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
