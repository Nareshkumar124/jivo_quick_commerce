import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
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
