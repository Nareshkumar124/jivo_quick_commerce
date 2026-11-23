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
import '../domain/order_track.dart';
import 'tracking_providers.dart';

/// The live tracking sheet's parts (T-821): freshness, distance, the 8-step
/// timeline and help. Each part `select`s only the fields it shows, so a
/// rider ping rebuilds the distance and freshness lines, not the sheet.

/// Ticks once a second while a widget shows a relative time ("12 sec ago")
/// or the rider fix's staleness. Auto-disposed with the last listener.
final trackTickProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (i) => i),
);

/// Whether the rider's position must not be shown as live: the server
/// tracks the rider but there is no fix, or it is older than
/// [riderFixStaleAfter] on the server's clock. False when no rider is
/// tracked (nothing to show).
final riderFixStaleProvider = Provider.autoDispose.family<bool, int>((
  ref,
  orderId,
) {
  ref.watch(trackTickProvider);
  final (tracked, rider) = ref.watch(
    trackProvider(orderId)
        .select((a) => (a.value?.riderTracked ?? false, a.value?.rider)),
  );
  if (!tracked || rider == null) return false;
  return rider.isStaleAt(ref.read(trackProvider(orderId).notifier).serverNow());
});

/// "just now" (under 10 s), "12 sec ago", "5 min ago" or "at 3:45 pm".
String agoText(AppLocalizations l10n, DateTime at, DateTime now) {
  final age = now.toUtc().difference(at.toUtc());
  if (age.inSeconds < 10) return l10n.trackingJustNow;
  if (age.inSeconds < 60) return l10n.trackingSecondsAgo(age.inSeconds);
  if (age.inMinutes < 60) return l10n.trackingMinutesAgo(age.inMinutes);
  return l10n.trackingAtTime(formatTime(at));
}

/// The server's road distance in words: "450 m away" (to 10 m) or
/// "1.8 km away". Display only; the number is the server's.
String distanceText(AppLocalizations l10n, int metres) {
  if (metres < 1000) {
    final m = (metres / 10).round() * 10;
    return l10n.trackingDistanceM(m < 10 ? 10 : m);
  }
  return l10n.trackingDistanceKm((metres / 1000).toStringAsFixed(1));
}

/// "1.8 km away" while the rider is tracked and the server sent a
/// distance; nothing otherwise.
class TrackDistanceLeft extends ConsumerWidget {
  const TrackDistanceLeft({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (tracked, metres) = ref.watch(
      trackProvider(orderId).select(
        (a) => (a.value?.riderTracked ?? false, a.value?.distanceRemainingM),
      ),
    );
    if (!tracked || metres == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Row(
      key: const Key('tracking-distance'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.route_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: JivoSpacing.xs),
        Flexible(
          child: Text(
            distanceText(AppLocalizations.of(context), metres),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// How current the screen is (`tracking-layout` §3, T-821): "Live ·
/// Updated 5 sec ago", "Updated 1 min ago" while polling, the rider's old
/// position ("Rider's location last updated 2 min ago", never shown as
/// live) or "Can't update right now".
class TrackFreshnessLine extends ConsumerWidget {
  const TrackFreshnessLine({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.jivoColors;
    final notifier = ref.read(trackProvider(orderId).notifier);
    // No 1 s tick here: only the "… ago" texts (_AgoText) tick; this line
    // rebuilds on a new fix, a staleness flip or a freshness change.
    final (tracked, rider) = ref.watch(
      trackProvider(orderId)
          .select((a) => (a.value?.riderTracked ?? false, a.value?.rider)),
    );
    final riderStale = ref.watch(riderFixStaleProvider(orderId));
    final small = theme.textTheme.bodySmall;
    return ValueListenableBuilder<TrackFreshness>(
      valueListenable: notifier.freshness,
      builder: (context, fresh, _) {
        final at = fresh.lastUpdatedAt;
        // "… ago" for the last data, on the phone's clock.
        Widget dataAgo(String Function(String ago) words) => _AgoText(
          orderId: orderId,
          at: at,
          serverClock: false,
          words: words,
          style: small,
        );
        if (fresh.mode == TrackFreshMode.stale) {
          return _banner(
            key: const Key('tracking-fresh-stale'),
            icon: Icons.cloud_off,
            color: colors.warning,
            text: dataAgo(l10n.trackingStaleAgo),
          );
        }
        final fix = tracked ? rider?.updatedAt : null;
        if (tracked && rider != null && rider.location == null) {
          return _row(
            key: const Key('tracking-fresh-no-fix'),
            icon: Icon(
              Icons.location_searching,
              size: 16,
              color: theme.colorScheme.outline,
            ),
            text: Text(l10n.trackingRiderNoFix, style: small),
          );
        }
        if (riderStale && fix != null) {
          return _banner(
            key: const Key('tracking-fresh-rider-stale'),
            icon: Icons.location_disabled,
            color: theme.colorScheme.outline,
            text: _AgoText(
              orderId: orderId,
              at: fix,
              serverClock: true,
              words: l10n.trackingRiderStale,
              style: small,
            ),
          );
        }
        if (fresh.mode == TrackFreshMode.live) {
          final agoAt = fix ?? at;
          return _row(
            key: const Key('tracking-fresh-live'),
            icon: Icon(Icons.circle, size: 8, color: colors.success),
            text: Wrap(
              spacing: JivoSpacing.sm,
              children: [
                Text(
                  l10n.trackingLive,
                  style: small?.copyWith(
                    color: colors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (agoAt != null)
                  _AgoText(
                    orderId: orderId,
                    at: agoAt,
                    serverClock: fix != null,
                    words: l10n.trackingLiveUpdatedAgo,
                    style: small,
                  ),
              ],
            ),
          );
        }
        return _row(
          key: const Key('tracking-fresh-polling'),
          icon: Icon(Icons.sync, size: 16, color: theme.colorScheme.outline),
          text: dataAgo(l10n.trackingUpdatedAgo),
        );
      },
    );
  }

  Widget _row({required Key key, required Widget icon, required Widget text}) =>
      Row(
        key: key,
        children: [
          icon,
          const SizedBox(width: JivoSpacing.xs),
          Flexible(child: text),
        ],
      );

  Widget _banner({
    required Key key,
    required IconData icon,
    required Color color,
    required Widget text,
  }) => Semantics(
    liveRegion: true,
    container: true,
    child: Container(
      key: key,
      padding: const EdgeInsets.all(JivoSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: JivoSpacing.sm),
          Expanded(child: text),
        ],
      ),
    ),
  );
}

/// "[words](12 sec ago)", redrawn every second (trackTickProvider) on its
/// own, so the tick never rebuilds the rest of the sheet. [serverClock]
/// measures against the server's clock (rider fixes), else the phone's.
/// No [at]: the words with an empty time.
class _AgoText extends ConsumerWidget {
  const _AgoText({
    required this.orderId,
    required this.at,
    required this.serverClock,
    required this.words,
    this.style,
  });

  final int orderId;
  final DateTime? at;
  final bool serverClock;
  final String Function(String ago) words;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(trackTickProvider);
    final when = at;
    var ago = '';
    if (when != null) {
      final now = serverClock
          ? ref.read(trackProvider(orderId).notifier).serverNow()
          : ref.read(trackClockProvider)();
      ago = agoText(AppLocalizations.of(context), when, now);
    }
    return Text(words(ago), style: style);
  }
}

/// The step's name in the app's words; the server's label for a step this
/// build doesn't know.
String trackStepLabel(AppLocalizations l10n, TrackStepState state) =>
    switch (state.step) {
      TrackStep.confirmed => l10n.trackStepConfirmed,
      TrackStep.preparing => l10n.trackStepPreparing,
      TrackStep.packed => l10n.trackStepPacked,
      TrackStep.riderAssigned => l10n.trackStepRiderAssigned,
      TrackStep.pickedUp => l10n.trackStepPickedUp,
      TrackStep.onTheWay => l10n.trackStepOnTheWay,
      TrackStep.arriving => l10n.trackStepArriving,
      TrackStep.delivered => l10n.trackStepDelivered,
      null => state.label,
    };

/// The 8 tracking steps exactly as the server reports them (`progress`,
/// T-821): done steps ticked with their time, the current one highlighted,
/// the rest greyed. Nothing is derived on the phone.
class TrackProgressTimeline extends StatelessWidget {
  const TrackProgressTimeline({required this.timeline, super.key});

  final TrackTimeline timeline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = timeline.steps;
    return Column(
      key: const Key('track-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.trackingProgressTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: JivoSpacing.sm),
        for (final (i, step) in steps.indexed)
          _StepRow(
            state: step,
            current: step.key == timeline.current,
            first: i == 0,
            last: i == steps.length - 1,
            nextDone: i + 1 < steps.length && steps[i + 1].done,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.state,
    required this.current,
    required this.first,
    required this.last,
    required this.nextDone,
  });

  final TrackStepState state;
  final bool current;
  final bool first;
  final bool last;
  final bool nextDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = state.done;
    final label = trackStepLabel(l10n, state);
    final at = state.at;
    final dotColor = done ? scheme.primary : scheme.outlineVariant;
    final semantics = current
        ? l10n.trackStepCurrentSemantics(label)
        : done
        ? l10n.trackStepDoneSemantics(label)
        : l10n.trackStepPendingSemantics(label);
    return Semantics(
      key: Key('track-step-${state.key}'),
      label: semantics,
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Container(
                    width: 2,
                    height: 6,
                    color: first
                        ? Colors.transparent
                        : (done ? scheme.primary : scheme.outlineVariant),
                  ),
                  Container(
                    key: done ? Key('track-step-${state.key}-done') : null,
                    width: current ? 22 : 18,
                    height: current ? 22 : 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? dotColor : scheme.surface,
                      border: Border.all(color: dotColor, width: 2),
                    ),
                    child: done
                        ? Icon(Icons.check, size: 12, color: scheme.onPrimary)
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: last
                          ? Colors.transparent
                          : (nextDone ? scheme.primary : scheme.outlineVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: JivoSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: JivoSpacing.md),
                child: Wrap(
                  spacing: JivoSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: current ? FontWeight.w800 : null,
                        color: done
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (done && at != null)
                      Text(
                        formatTime(at),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where "help" goes for an order: the new-ticket form with the order
/// attached when support is on, else a call to the support phone, else
/// nowhere (null).
({bool ticket, VoidCallback onTap})? trackHelpAction(
  BuildContext context,
  WidgetRef ref,
  int orderId,
) {
  if (ref.watch(supportAvailableProvider)) {
    return (
      ticket: true,
      onTap: () => context.push(Routes.newTicket(orderId: orderId)),
    );
  }
  final phone = ref.watch(launchStateProvider).config?.supportPhone;
  if (phone != null && phone.isNotEmpty) {
    return (
      ticket: false,
      onTap: () =>
          ref.read(urlOpenerProvider).open(Uri(scheme: 'tel', path: phone)),
    );
  }
  return null;
}

/// "Need help with this order?" on the sheet: support with the order
/// attached (or a call to support). Hidden when neither is available.
class TrackHelpButton extends ConsumerWidget {
  const TrackHelpButton({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final action = trackHelpAction(context, ref, orderId);
    if (action == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const Key('tracking-help'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: action.onTap,
      icon: Icon(action.ticket ? Icons.support_agent : Icons.call_outlined),
      label: Text(action.ticket ? l10n.trackingHelp : l10n.callSupport),
    );
  }
}
