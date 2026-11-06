import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_history.dart';
import '../domain/order_track.dart';

/// The delivery OTP, shown prominently while the order is out for
/// delivery (`03 §2.10`; the server sends it only then, `06 §2.6`).
/// Used on live tracking and on the order detail.
class DeliveryOtpCard extends StatelessWidget {
  const DeliveryOtpCard({required this.otp, super.key});

  final String otp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('delivery-otp'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.lg),
        child: Column(
          children: [
            Text(l10n.trackingOtpTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: JivoSpacing.xs),
            Semantics(
              label: l10n.trackingOtpSemantics(otp.split('').join(' ')),
              child: ExcludeSemantics(
                child: Text(
                  otp,
                  key: const Key('delivery-otp-code'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: JivoSpacing.xs),
            Text(
              l10n.trackingOtpHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The assigned rider: photo (or a placeholder), name, when the location
/// was last seen, and a call button (`03 §2.10`).
class RiderCard extends ConsumerWidget {
  const RiderCard({required this.rider, super.key});

  final TrackRider rider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final phone = rider.phone;
    final updatedAt = rider.updatedAt;
    return ListTile(
      key: const Key('rider-card'),
      contentPadding: EdgeInsets.zero,
      leading: RiderAvatar(photoUrl: rider.photoUrl),
      title: Text(rider.name),
      subtitle: Text(
        [
          l10n.trackingRiderLabel,
          if (updatedAt != null) formatTime(updatedAt),
        ].join(' · '),
      ),
      trailing: phone == null || phone.isEmpty
          ? null
          : IconButton.filledTonal(
              key: const Key('call-rider'),
              tooltip: l10n.trackingCallRider(rider.name),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.call),
              onPressed: () => ref
                  .read(urlOpenerProvider)
                  .open(Uri(scheme: 'tel', path: phone)),
            ),
    );
  }
}

/// The rider's photo in a circle; a person icon without one or when it
/// fails to load. Only `https` photos are loaded. Decorative.
class RiderAvatar extends StatelessWidget {
  const RiderAvatar({required this.photoUrl, super.key});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    const placeholder = CircleAvatar(child: Icon(Icons.person));
    final url = photoUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return placeholder;
    }
    return ClipOval(
      child: SizedBox.square(
        dimension: 40,
        child: Image.network(
          url!,
          key: const Key('rider-photo'),
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => placeholder,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder,
        ),
      ),
    );
  }
}

/// The refund line for a failed or returned delivery, from the server's
/// payment status and `amount_refunded` (never computed here). Null when
/// the server has nothing to say yet.
String? refundNoteFor(AppLocalizations l10n, OrderDetail order) {
  if (order.paymentMethod == PaymentMethod.cod) {
    return order.paymentStatus == PaymentStatus.codCollected
        ? null
        : l10n.nothingToPay;
  }
  final refunded = formatRupeesOrNull(order.amountRefunded);
  return switch (order.paymentStatus) {
    PaymentStatus.refundPending => l10n.refundNoteStarted,
    PaymentStatus.refunded || PaymentStatus.partiallyRefunded
        when refunded != null =>
      l10n.refundNoteDone(refunded),
    _ => null,
  };
}

/// Explains the delivery step under the status: picked up, arriving,
/// delivery failed (with the refund note) or returned (`03 §2.10`).
class DeliveryStageCard extends StatelessWidget {
  const DeliveryStageCard({required this.stage, this.refundNote, super.key});

  final DeliveryStage stage;

  /// Shown for a failed or returned delivery only.
  final String? refundNote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed =
        stage == DeliveryStage.failed || stage == DeliveryStage.returned;
    final (icon, title, body) = switch (stage) {
      DeliveryStage.pickedUp => (
        Icons.delivery_dining,
        l10n.deliveryStagePickedUpTitle,
        l10n.deliveryStagePickedUpBody,
      ),
      DeliveryStage.arriving => (
        Icons.person_pin_circle_outlined,
        l10n.deliveryStageArrivingTitle,
        l10n.deliveryStageArrivingBody,
      ),
      DeliveryStage.failed => (
        Icons.error_outline,
        l10n.deliveryStageFailedTitle,
        l10n.deliveryStageFailedBody,
      ),
      DeliveryStage.returned => (
        Icons.assignment_return_outlined,
        l10n.deliveryStageReturnedTitle,
        l10n.deliveryStageReturnedBody,
      ),
    };
    final note = failed ? refundNote : null;
    final foreground = failed
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        key: Key('delivery-stage-${stage.name}'),
        margin: EdgeInsets.zero,
        color: failed ? scheme.errorContainer : scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(JivoSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, color: foreground)),
              const SizedBox(width: JivoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: JivoSpacing.xs),
                      Text(
                        note,
                        key: const Key('delivery-refund-note'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Pay ₹X to the rider" for a cash-on-delivery order, with the server's
/// amount ([OrderDetail.codAmountDue]) as sent.
class CodDueCard extends StatelessWidget {
  const CodDueCard({required this.amount, super.key});

  /// The server's 2-decimal amount string.
  final String amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('cod-due'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.md),
        child: Row(
          children: [
            const ExcludeSemantics(child: Icon(Icons.payments_outlined)),
            const SizedBox(width: JivoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.codPayRiderTitle(formatRupees(amount)),
                    key: const Key('cod-due-amount'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(l10n.codPayRiderHint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
