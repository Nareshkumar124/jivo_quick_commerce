import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/platform/device_channel.dart';
import '../domain/rider_task.dart';
import '../domain/task_navigation.dart';

/// Whether this build can show a Google map: it needs a Maps API key
/// injected at build time (DL-80, `android/app/build.gradle.kts`). Without
/// one the task screens show the no-map card. Overridden in tests.
final mapsAvailableProvider = FutureProvider<bool>(
  (ref) => const DeviceChannel().hasMapsKey(),
);

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

/// The Google Maps platform view (DL-80): the rider's own location layer
/// (blue dot), a marker at the destination and the server's route. The
/// camera fits the route once, and again when the leg changes; the rider
/// may pan in between.
class GoogleTaskMap extends StatefulWidget {
  const GoogleTaskMap({
    required this.navigation,
    required this.destination,
    super.key,
  });

  final TaskNavigation navigation;
  final GeoPoint destination;

  @override
  State<GoogleTaskMap> createState() => _GoogleTaskMapState();
}

class _GoogleTaskMapState extends State<GoogleTaskMap> {
  static LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

  GoogleMapController? _controller;
  List<GeoPoint> _points = const [];
  String? _polyline;

  List<GeoPoint> get _route {
    final polyline = widget.navigation.route?.polyline;
    if (polyline != _polyline) {
      _polyline = polyline;
      _points = polyline == null ? const [] : decodePolyline(polyline);
    }
    return _points;
  }

  @override
  void didUpdateWidget(GoogleTaskMap old) {
    super.didUpdateWidget(old);
    final c = _controller;
    if (c != null && old.navigation.leg != widget.navigation.leg) {
      unawaited(_fit(c));
    }
  }

  Future<void> _fit(GoogleMapController c) async {
    final points = [..._route, widget.destination];
    try {
      if (points.length < 2) {
        await c.animateCamera(
          CameraUpdate.newLatLngZoom(_ll(widget.destination), 15),
        );
        return;
      }
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              points.map((p) => p.lat).reduce(math.min),
              points.map((p) => p.lng).reduce(math.min),
            ),
            northeast: LatLng(
              points.map((p) => p.lat).reduce(math.max),
              points.map((p) => p.lng).reduce(math.max),
            ),
          ),
          40,
        ),
      );
    } on Object {
      // The camera is decoration; distance, ETA and actions still show.
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final toStore = widget.navigation.leg == NavigationLeg.toStore;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _ll(route.isNotEmpty ? route.first : widget.destination),
        zoom: 14,
      ),
      // The rider's position from the phone (location is already allowed
      // "all the time" by the permissions gate).
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      buildingsEnabled: false,
      trafficEnabled: false,
      indoorViewEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        unawaited(_fit(c));
      },
      polylines: {
        if (route.length >= 2)
          Polyline(
            polylineId: const PolylineId('route'),
            points: [for (final p in route) _ll(p)],
            color: const Color(0xFF1565C0),
            width: 5,
          ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('destination'),
          position: _ll(widget.destination),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            toStore ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueGreen,
          ),
        ),
      },
    );
  }
}
