import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
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

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(offerControllerProvider.notifier).tick();
      if (mounted) setState(() {});
    });
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
    if (reason == null || !mounted) return;
    await ref
        .read(offerControllerProvider.notifier)
        .reject(reason: reason.reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(offerControllerProvider);
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
              Center(
                child: SizedBox.square(
                  dimension: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: fraction.clamp(0, 1),
                        strokeWidth: 10,
                      ),
                      Center(
                        child: Text(
                          '$seconds',
                          key: const Key('offer-countdown'),
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _OfferRow(icon: Icons.store, text: offer.storeName),
              _OfferRow(icon: Icons.place, text: offer.dropLocality),
              _OfferRow(
                icon: Icons.route,
                text: distanceText(l10n, offer.distanceKm),
              ),
              _OfferRow(
                key: const Key('offer-payment'),
                icon: Icons.payments,
                text: offer.paymentType == PaymentType.cod
                    ? l10n.offerCod(formatRupees(offer.codAmount ?? ''))
                    : l10n.offerPrepaid,
                emphasise: offer.paymentType == PaymentType.cod,
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

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.icon,
    required this.text,
    this.emphasise = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style:
                  (emphasise
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                        fontWeight: emphasise ? FontWeight.w700 : null,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
