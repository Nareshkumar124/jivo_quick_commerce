import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../location/presentation/delivery_controller.dart';
import '../domain/order_track.dart';
import 'tracking_screen.dart' show RouteSketch;

/// Builds the live map for a tracked order. A provider, so widget tests
/// swap the Google Maps platform view for a plain widget.
typedef TrackMapBuilder = Widget Function(OrderTrack track);

final trackMapBuilderProvider = Provider<TrackMapBuilder>(
  (ref) =>
      (track) => GoogleTrackMap(track: track),
);

/// The store, the customer and the rider on a Google map (DL-80), moved by
/// the socket's `rider.location` messages. Without a Maps API key in the
/// build, the [RouteSketch] is shown instead.
class TrackMap extends ConsumerStatefulWidget {
  const TrackMap({required this.track, super.key});

  final OrderTrack track;

  @override
  ConsumerState<TrackMap> createState() => _TrackMapState();
}

class _TrackMapState extends ConsumerState<TrackMap> {
  @override
  Widget build(BuildContext context) {
    final available = ref.watch(mapsAvailableProvider).value ?? false;
    if (!available) return RouteSketch(progress: widget.track.progress);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.trackingMapSemantics((widget.track.progress * 100).round()),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(JivoRadii.md),
        child: SizedBox(
          key: const Key('tracking-map'),
          height: 220,
          child: ref.watch(trackMapBuilderProvider)(widget.track),
        ),
      ),
    );
  }
}

/// The Google Maps platform view (DL-80). Default markers for the store,
/// home and the rider; a straight line joins store and home (a sketch, not
/// a route: the ETA is the server's). The rider marker follows the track,
/// which the socket updates.
class GoogleTrackMap extends StatefulWidget {
  const GoogleTrackMap({required this.track, super.key});

  final OrderTrack track;

  @override
  State<GoogleTrackMap> createState() => _GoogleTrackMapState();
}

class _GoogleTrackMapState extends State<GoogleTrackMap> {
  static LatLng _ll(TrackPoint p) => LatLng(p.lat, p.lng);

  GoogleMapController? _controller;

  @override
  void didUpdateWidget(GoogleTrackMap old) {
    super.didUpdateWidget(old);
    // Re-fit once when the rider first appears, so it is on screen; later
    // ticks only move the marker.
    final c = _controller;
    if (c != null &&
        old.track.rider?.location == null &&
        widget.track.rider?.location != null) {
      unawaited(_fit(c));
    }
  }

  Future<void> _fit(GoogleMapController c) async {
    final t = widget.track;
    final points = [t.store, t.destination, ?t.rider?.location];
    try {
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
          48,
        ),
      );
    } catch (_) {
      // The camera is decoration; the status, ETA and cards still show.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    final rider = t.rider?.location;
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _ll(rider ?? t.destination),
        zoom: 14,
      ),
      compassEnabled: false,
      rotateGesturesEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        unawaited(_fit(c));
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [_ll(t.store), _ll(t.destination)],
          color: const Color(0xFF9E9E9E),
          width: 3,
        ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('store'),
          position: _ll(t.store),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
        Marker(
          markerId: const MarkerId('home'),
          position: _ll(t.destination),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
        if (rider != null)
          Marker(
            markerId: const MarkerId('rider'),
            position: _ll(rider),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange,
            ),
          ),
      },
    );
  }
}
