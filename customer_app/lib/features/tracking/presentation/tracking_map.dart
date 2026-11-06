import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:mappls_gl/mappls_gl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../location/presentation/delivery_controller.dart';
import '../domain/order_track.dart';
import 'tracking_screen.dart' show RouteSketch;

/// Builds the live map for a tracked order. A provider, so widget tests
/// swap the Mappls platform view for a plain widget.
typedef TrackMapBuilder = Widget Function(OrderTrack track);

final trackMapBuilderProvider = Provider<TrackMapBuilder>(
  (ref) =>
      (track) => MapplsTrackMap(track: track),
);

/// The store, the customer and the rider on a Mappls map (D-03), moved by
/// the socket's `rider.location` messages. Without the Mappls config, or
/// when the map fails, the [RouteSketch] is shown instead.
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

/// The Mappls platform view. Markers are circles (no image assets): the
/// store, home and the rider; a straight line joins store and home (a
/// sketch, not a route: the ETA is the server's).
class MapplsTrackMap extends StatefulWidget {
  const MapplsTrackMap({required this.track, super.key});

  final OrderTrack track;

  @override
  State<MapplsTrackMap> createState() => _MapplsTrackMapState();
}

class _MapplsTrackMapState extends State<MapplsTrackMap> {
  MapplsMapController? _controller;
  Circle? _rider;
  bool _styled = false;
  bool _failed = false;

  static LatLng _ll(TrackPoint p) => LatLng(p.lat, p.lng);

  @override
  void didUpdateWidget(MapplsTrackMap old) {
    super.didUpdateWidget(old);
    final at = widget.track.rider?.location;
    if (_styled && at != old.track.rider?.location) {
      unawaited(_placeRider(at));
    }
  }

  Future<void> _onStyleLoaded() async {
    final c = _controller;
    if (c == null) return;
    _styled = true;
    final t = widget.track;
    try {
      await c.addLine(
        LineOptions(
          geometry: [_ll(t.store), _ll(t.destination)],
          lineColor: '#9E9E9E',
          lineWidth: 3,
        ),
      );
      await c.addCircle(_dot(t.store, '#1565C0'));
      await c.addCircle(_dot(t.destination, '#2E7D32'));
      await _placeRider(t.rider?.location);
      final points = [t.store, t.destination, ?t.rider?.location];
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
          left: 48,
          top: 48,
          right: 48,
          bottom: 48,
        ),
      );
    } catch (_) {
      // Markers are decoration; the status, ETA and cards still show.
    }
  }

  static CircleOptions _dot(TrackPoint p, String color, {double r = 7}) =>
      CircleOptions(
        geometry: _ll(p),
        circleRadius: r,
        circleColor: color,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 2,
      );

  Future<void> _placeRider(TrackPoint? at) async {
    final c = _controller;
    if (c == null) return;
    try {
      final rider = _rider;
      if (at == null) {
        if (rider != null) await c.removeCircle(rider);
        _rider = null;
      } else if (rider == null) {
        _rider = await c.addCircle(_dot(at, '#E65100', r: 9));
      } else {
        await c.updateCircle(rider, CircleOptions(geometry: _ll(at)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return RouteSketch(progress: widget.track.progress);
    final t = widget.track;
    return MapplsMap(
      initialCameraPosition: CameraPosition(
        target: _ll(t.rider?.location ?? t.destination),
        zoom: 14,
      ),
      compassEnabled: false,
      rotateGesturesEnabled: false,
      onMapCreated: (c) => _controller = c,
      onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
      onMapError: (code, message) {
        debugPrint('Mappls map error $code: $message');
        if (mounted) setState(() => _failed = true);
      },
    );
  }
}
