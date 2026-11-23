import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/map/rider_map.dart';
import '../domain/rider_task.dart';
import '../domain/task_navigation.dart';

export '../../../shared/map/rider_map.dart' show mapsAvailableProvider;

/// Builds the map for a task's navigation. A provider, so widget tests swap
/// the Google Maps platform view for a plain widget.
typedef TaskMapBuilder = Widget Function(
  TaskNavigation navigation,
  GeoPoint destination,
);

final taskMapBuilderProvider = Provider<TaskMapBuilder>(
  (ref) =>
      (navigation, destination) =>
          GoogleTaskMap(navigation: navigation, destination: destination),
);

/// A server position older than this is called out: the rider's GPS or
/// network may be off (uploads every 5–10 s on a task, 04 §3).
const navigationStaleAfter = Duration(minutes: 2);

/// The active leg (T-821): a map with the rider (blue dot), the
/// destination and the server's route when the build has a Maps key, and
/// always the distance and ETA from `navigation`. Display only: the server
/// still decides the geofences and every step.
///
/// Shows nothing when the task has no `navigation` (an older server, or a
/// state outside ASSIGNED .. AT_CUSTOMER).
class NavigationPanel extends ConsumerWidget {
  const NavigationPanel({required this.task, super.key});

  final RiderTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = task.navigation;
    if (navigation == null) return const SizedBox.shrink();
    final hasMap = ref.watch(mapsAvailableProvider).value ?? false;
    final l10n = AppLocalizations.of(context);
    final place = navigation.leg == NavigationLeg.toStore
        ? task.store.name
        : (task.customer?.name ?? l10n.navToCustomer);
    // Small phones: the map never takes more than about a quarter of the
    // screen, so the step's cards and actions stay in view.
    final height = (MediaQuery.sizeOf(context).height * 0.26).clamp(
      140.0,
      240.0,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        key: const Key('nav-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasMap)
            Semantics(
              label: l10n.navMapSemantics(place),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  key: const Key('nav-map'),
                  height: height,
                  child: ref.watch(taskMapBuilderProvider)(
                    navigation,
                    navigation.destination,
                  ),
                ),
              ),
            ),
          NavigationSummary(navigation: navigation, mapAbove: hasMap),
        ],
      ),
    );
  }
}

/// Distance and ETA in big type, the leg, and hints (no position yet,
/// straight-line estimate, old position). The no-map fallback is this card
/// alone.
class NavigationSummary extends ConsumerWidget {
  const NavigationSummary({
    required this.navigation,
    this.mapAbove = false,
    super.key,
  });

  final TaskNavigation navigation;
  final bool mapAbove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final now = ref.watch(clockProvider)().toUtc();
    final metres = navigation.distanceM ?? navigation.route?.distanceM;
    final minutes = navigation.etaMinutes;
    final arrived = minutes == 0 || metres == 0;
    final positionAt = navigation.positionAt;
    final staleFor = positionAt == null
        ? null
        : now.difference(positionAt.toUtc());
    final stale = staleFor != null && staleFor >= navigationStaleAfter;
    final straightLine = navigation.route != null && !navigation.route!.isRoad;

    final big = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: colors.textPrimary,
    );
    final small = TextStyle(fontSize: 16, color: colors.textSecondary);

    final List<Widget> headline;
    if (arrived) {
      headline = [
        Text(l10n.navArrived, key: const Key('nav-arrived'), style: big),
      ];
    } else if (metres == null && minutes == null) {
      headline = [
        Text(
          l10n.navWaitingForLocation,
          key: const Key('nav-waiting'),
          style: const TextStyle(fontSize: 18),
        ),
      ];
    } else {
      headline = [
        if (minutes != null)
          Text(
            l10n.navEtaMinutes(minutes),
            key: const Key('nav-eta'),
            style: big,
          ),
        if (metres != null)
          Text(
            formatDistance(l10n, metres),
            key: const Key('nav-distance'),
            style: big.copyWith(fontWeight: FontWeight.w600),
          ),
      ];
    }
    final etaAt = navigation.etaAt;

    return Card(
      margin: EdgeInsets.only(top: mapAbove ? 8 : 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  navigation.leg == NavigationLeg.toStore
                      ? Icons.store
                      : Icons.person_pin_circle,
                  size: 24,
                  color: colors.textPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    navigation.leg == NavigationLeg.toStore
                        ? l10n.navToStore
                        : l10n.navToCustomer,
                    key: const Key('nav-leg'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: headline,
            ),
            if (!arrived && etaAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.navArriveBy(istTime(context, etaAt)),
                  key: const Key('nav-eta-at'),
                  style: small,
                ),
              ),
            if (straightLine && !arrived)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.navStraightLine,
                  key: const Key('nav-straight-line'),
                  style: small,
                ),
              ),
            if (stale)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.gps_off,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.navLocationOld(staleFor.inMinutes),
                        key: const Key('nav-stale'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `850 m`, `2.4 km` (one decimal under 10 km, whole km above).
String formatDistance(AppLocalizations l10n, int metres) {
  if (metres < 1000) return l10n.navDistanceM(metres);
  final km = metres / 1000;
  return l10n.navDistanceKm(
    km < 10 ? km.toStringAsFixed(1) : km.round().toString(),
  );
}

/// The map spec for a navigation leg: the destination pin, the server's
/// route (dashed when it is a straight-line estimate), and a dashed line
/// from the rider while the server has no route yet. The camera fits again
/// when the leg or the route changes.
RiderMapSpec navigationMapSpec(TaskNavigation navigation) {
  final route = navigation.route;
  return RiderMapSpec(
    pins: [
      MapPin(
        navigation.leg == NavigationLeg.toStore
            ? MapPinKind.store
            : MapPinKind.customer,
        navigation.destination,
      ),
    ],
    route: route?.points ?? const [],
    roadRoute: route?.isRoad ?? true,
    lineFromRider: true,
    followKey: (navigation.leg, route?.polyline),
  );
}

/// The navigation card's map (DL-80, T-821): the shared [GoogleRiderMap]
/// with the rider's blue dot, the destination and the server's route, a
/// recenter button, and a camera that follows leg and route changes.
class GoogleTaskMap extends ConsumerWidget {
  const GoogleTaskMap({
    required this.navigation,
    required this.destination,
    super.key,
  });

  final TaskNavigation navigation;
  final GeoPoint destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fix = ref.watch(riderMapPositionProvider).value ?? MapRiderFix.none;
    return GoogleRiderMap(spec: navigationMapSpec(navigation).withRider(fix));
  }
}
