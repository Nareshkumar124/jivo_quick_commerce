import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../location/presentation/delivery_controller.dart';
import '../domain/order_track.dart';
import '../domain/route_geometry.dart';
import 'tracking_providers.dart';
import 'tracking_screen.dart' show RouteSketch;
import 'tracking_sheet.dart';

/// Builds the live map for a tracked order. A provider, so widget tests
/// swap the Google Maps platform view for a plain widget. [bottomInset] is
/// the height the bottom sheet covers: markers and the recenter button stay
/// above it.
typedef TrackMapBuilder = Widget Function(int orderId, double bottomInset);

final trackMapBuilderProvider = Provider<TrackMapBuilder>(
  (ref) =>
      (orderId, bottomInset) =>
          GoogleTrackMap(orderId: orderId, bottomInset: bottomInset),
);

/// The live map (DL-80, T-821), or the [RouteSketch] when the build has no
/// Maps API key. With [height] null it fills its parent (the full-screen
/// map behind the sheet). A "Location not live" chip covers the map while
/// the rider's position is old: an old position is never shown as live.
class TrackMap extends ConsumerWidget {
  const TrackMap({
    required this.orderId,
    this.height,
    this.bottomInset = 0,
    super.key,
  });

  final int orderId;
  final double? height;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(mapsAvailableProvider).value ?? false;
    if (!available) {
      final progress = ref.watch(
        trackProvider(orderId).select((a) => a.value?.progress ?? 0),
      );
      return RouteSketch(progress: progress);
    }
    final l10n = AppLocalizations.of(context);
    final stale = ref.watch(riderFixStaleProvider(orderId));
    final map = Stack(
      children: [
        Positioned.fill(
          child: ref.watch(trackMapBuilderProvider)(orderId, bottomInset),
        ),
        if (stale)
          Positioned(
            top: JivoSpacing.md,
            left: 0,
            right: 0,
            child: Center(
              child: Chip(
                key: const Key('tracking-map-not-live'),
                avatar: const Icon(Icons.location_disabled, size: 18),
                label: Text(l10n.trackingMapNotLive),
              ),
            ),
          ),
      ],
    );
    return SizedBox(
      key: const Key('tracking-map'),
      height: height,
      child: height == null
          ? map
          : ClipRRect(
              borderRadius: BorderRadius.circular(JivoRadii.md),
              child: map,
            ),
    );
  }
}

/// The rider's newest fix as the map needs it.
typedef _Fix = ({TrackPoint at, double? heading, DateTime? recordedAt});

/// The Google Maps platform view (DL-80, T-821): store, home and a scooter
/// marker for the rider, rotated by heading and glided between fixes (no
/// jumps); the server's road route from the rider onwards; the camera fits
/// everyone until the customer moves the map, then a button brings it
/// back. It `select`s only what it draws, and the glide only rebuilds this
/// widget.
class GoogleTrackMap extends ConsumerStatefulWidget {
  const GoogleTrackMap({
    required this.orderId,
    this.bottomInset = 0,
    super.key,
  });

  final int orderId;
  final double bottomInset;

  @override
  ConsumerState<GoogleTrackMap> createState() => _GoogleTrackMapState();
}

class _GoogleTrackMapState extends ConsumerState<GoogleTrackMap>
    with SingleTickerProviderStateMixin {
  static LatLng _ll(TrackPoint p) => LatLng(p.lat, p.lng);

  /// How long a glide between two fixes takes.
  static const _glide = Duration(milliseconds: 1500);

  /// The glide redraws the marker at most this often (platform calls).
  static const _frame = Duration(milliseconds: 40);

  GoogleMapController? _controller;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _glide,
  )..addListener(_onTick);
  Duration _lastFrame = Duration.zero;
  final _stopwatch = Stopwatch()..start();

  TrackPoint? _from;
  TrackPoint? _to;
  double? _fromHeading;
  double? _toHeading;
  TrackPoint? _shown;
  double? _shownHeading;
  DateTime? _lastFixAt;

  String? _routeSource;
  List<TrackPoint> _route = const [];

  bool _userMoved = false;
  _MarkerIcons? _icons;

  @override
  void initState() {
    super.initState();
    final t = ref.read(trackProvider(widget.orderId)).value;
    final at = t?.rider?.location;
    if (at != null) {
      _shown = _to = at;
      _shownHeading = _toHeading = t?.rider?.heading;
      _lastFixAt = t?.rider?.updatedAt;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_icons == null) {
      final scheme = Theme.of(context).colorScheme;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      unawaited(
        _MarkerIcons.load(dpr, scheme).then((icons) {
          if (mounted) setState(() => _icons = icons);
        }),
      );
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// A new fix: glide from where the marker is now to it.
  void _onFix(_Fix? fix) {
    if (fix == null) return;
    final last = _lastFixAt;
    final at = fix.recordedAt;
    if (last != null && at != null && !at.isAfter(last)) return;
    _lastFixAt = at ?? last;
    final from = _shown ?? fix.at;
    final heading = markerHeading(
      previous: _to,
      current: fix.at,
      serverHeading: fix.heading,
      fallback: _toHeading,
    );
    _from = from;
    _fromHeading = _shownHeading ?? heading;
    _to = fix.at;
    _toHeading = heading;
    if (_shown == null) {
      setState(() {
        _shown = fix.at;
        _shownHeading = heading;
      });
      unawaited(_fit());
      return;
    }
    _anim.forward(from: 0);
    unawaited(_followIfOffScreen(fix.at));
  }

  void _onTick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final now = _stopwatch.elapsed;
    final finished = _anim.status == AnimationStatus.completed;
    if (!finished && now - _lastFrame < _frame) return;
    _lastFrame = now;
    final t = Curves.easeInOut.transform(_anim.value);
    final fh = _fromHeading;
    final th = _toHeading;
    setState(() {
      _shown = lerpPoint(from, to, t);
      _shownHeading = fh != null && th != null ? lerpHeading(fh, th, t) : th;
    });
  }

  List<TrackPoint> _focus(OrderTrack t) {
    final rider = _to ?? t.rider?.location;
    final toStore =
        t.route?.leg == RouteLeg.toStore ||
        (t.route == null && !t.outForDelivery);
    return [?rider, if (toStore || rider == null) t.store, t.destination];
  }

  Future<void> _fit() async {
    final c = _controller;
    final t = ref.read(trackProvider(widget.orderId)).value;
    if (c == null || t == null || _userMoved) return;
    final points = _focus(t);
    try {
      final lats = points.map((p) => p.lat);
      final lngs = points.map((p) => p.lng);
      final south = lats.reduce(math.min);
      final north = lats.reduce(math.max);
      final west = lngs.reduce(math.min);
      final east = lngs.reduce(math.max);
      if (north - south < 0.0005 && east - west < 0.0005) {
        await c.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng((north + south) / 2, (east + west) / 2),
            16,
          ),
        );
        return;
      }
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          64,
        ),
      );
    } catch (_) {
      // The camera is decoration; the sheet still shows everything.
    }
  }

  Future<void> _followIfOffScreen(TrackPoint at) async {
    final c = _controller;
    if (c == null || _userMoved) return;
    try {
      final visible = await c.getVisibleRegion();
      if (!visible.contains(_ll(at))) await _fit();
    } catch (_) {}
  }

  void _recenter() {
    setState(() => _userMoved = false);
    unawaited(_fit());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = widget.orderId;
    ref.listen<_Fix?>(
      trackProvider(id).select((a) {
        final r = a.value?.rider;
        final at = r?.location;
        return at == null
            ? null
            : (at: at, heading: r!.heading, recordedAt: r.updatedAt);
      }),
      (_, next) => _onFix(next),
    );
    // A new leg (picked up): fit the new focus.
    ref.listen<RouteLeg?>(
      trackProvider(id).select((a) => a.value?.route?.leg),
      (prev, next) {
        if (prev != next) unawaited(_fit());
      },
    );
    final (store, home, polyline, tracked) = ref.watch(
      trackProvider(id).select((a) {
        final t = a.value;
        return (
          t?.store,
          t?.destination,
          t?.route?.polyline,
          t?.riderTracked ?? false,
        );
      }),
    );
    final stale = ref.watch(riderFixStaleProvider(id));
    if (store == null || home == null) return const SizedBox.shrink();
    if (polyline != _routeSource) {
      _routeSource = polyline;
      _route = polyline == null ? const [] : decodePolyline(polyline);
    }
    final rider = tracked ? _shown : null;
    final ahead = routeAhead(_route, _to);
    final scheme = Theme.of(context).colorScheme;
    final icons = _icons;
    final inset = widget.bottomInset;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) {
              if (!_userMoved) setState(() => _userMoved = true);
            },
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _ll(rider ?? home),
                zoom: 14,
              ),
              padding: EdgeInsets.only(bottom: inset),
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              buildingsEnabled: false,
              onMapCreated: (c) {
                _controller = c;
                unawaited(_fit());
              },
              polylines: {
                if (ahead.length >= 2)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [for (final p in ahead) _ll(p)],
                    color: stale ? scheme.outline : scheme.primary,
                    width: 5,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  )
                else if (!tracked)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [_ll(store), _ll(home)],
                    color: scheme.outlineVariant,
                    width: 3,
                    patterns: [PatternItem.dash(12), PatternItem.gap(8)],
                  ),
              },
              markers: {
                Marker(
                  markerId: const MarkerId('store'),
                  position: _ll(store),
                  anchor: const Offset(0.5, 0.5),
                  icon:
                      icons?.store ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                  infoWindow: InfoWindow(title: l10n.trackingMapStore),
                ),
                Marker(
                  markerId: const MarkerId('home'),
                  position: _ll(home),
                  icon:
                      icons?.home ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                  infoWindow: InfoWindow(title: l10n.trackingMapHome),
                ),
                if (rider != null)
                  Marker(
                    markerId: const MarkerId('rider'),
                    position: _ll(rider),
                    anchor: const Offset(0.5, 0.5),
                    flat: true,
                    rotation: _shownHeading ?? 0,
                    zIndexInt: 2,
                    alpha: stale ? 0.6 : 1,
                    icon:
                        (stale ? icons?.riderStale : icons?.rider) ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                  ),
              },
            ),
          ),
        ),
        if (_userMoved)
          PositionedDirectional(
            end: JivoSpacing.md,
            bottom: inset + JivoSpacing.md,
            child: FloatingActionButton.small(
              key: const Key('tracking-recenter'),
              heroTag: null,
              tooltip: l10n.trackingRecenter,
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
              onPressed: _recenter,
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
      ],
    );
  }
}

/// The map's painted marker icons: a scooter disc with a heading pointer
/// (rotated by the marker), a grey one for an old position, the store and
/// home. Drawn once per screen.
class _MarkerIcons {
  const _MarkerIcons({
    required this.rider,
    required this.riderStale,
    required this.store,
    required this.home,
  });

  final BitmapDescriptor rider;
  final BitmapDescriptor riderStale;
  final BitmapDescriptor store;
  final BitmapDescriptor home;

  static Future<_MarkerIcons> load(double dpr, ColorScheme scheme) async {
    final results = await Future.wait([
      _disc(Icons.delivery_dining, scheme.primary, dpr, pointer: true),
      _disc(Icons.delivery_dining, Colors.grey, dpr, pointer: true),
      _disc(Icons.storefront, const Color(0xFF1E6FD9), dpr, size: 34),
      _disc(Icons.home_rounded, const Color(0xFF263238), dpr, size: 34),
    ]);
    return _MarkerIcons(
      rider: results[0],
      riderStale: results[1],
      store: results[2],
      home: results[3],
    );
  }

  static Future<BitmapDescriptor> _disc(
    IconData icon,
    Color color,
    double dpr, {
    double size = 44,
    bool pointer = false,
  }) async {
    // Fall back to the default pin when painting is not possible.
    try {
      final px = size * dpr;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final c = Offset(px / 2, px / 2);
      final r = px / 2 - (pointer ? px * 0.14 : 2 * dpr);
      if (pointer) {
        final nose = Path()
          ..moveTo(c.dx, 0)
          ..lineTo(c.dx - px * 0.13, px * 0.2)
          ..lineTo(c.dx + px * 0.13, px * 0.2)
          ..close();
        canvas.drawPath(nose, Paint()..color = color);
      }
      canvas
        ..drawCircle(
          c.translate(0, dpr),
          r,
          Paint()
            ..color = Colors.black26
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * dpr),
        )
        ..drawCircle(c, r, Paint()..color = Colors.white)
        ..drawCircle(c, r - 2.5 * dpr, Paint()..color = color);
      final glyph = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: r * 1.2,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
          ),
        ),
      )..layout();
      glyph.paint(canvas, c - Offset(glyph.width / 2, glyph.height / 2));
      final image = await recorder.endRecording().toImage(
        px.round(),
        px.round(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no bytes');
      return BitmapDescriptor.bytes(
        data.buffer.asUint8List(),
        imagePixelRatio: dpr,
      );
    } catch (_) {
      return BitmapDescriptor.defaultMarker;
    }
  }
}
