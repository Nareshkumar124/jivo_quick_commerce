import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app/theme.dart';
import '../../features/task/domain/rider_task.dart';
import '../../l10n/app_localizations.dart';
import '../platform/device_channel.dart';

/// Whether this build can show a Google map: it needs a Maps API key
/// injected at build time (DL-80, `android/app/build.gradle.kts`). Without
/// one every screen shows its no-map layout. Overridden in tests.
final mapsAvailableProvider = FutureProvider<bool>(
  (ref) => const DeviceChannel().hasMapsKey(),
);

/// What a pin marks. Colours and glyphs follow the customer app's tracking
/// map (store: blue shop disc, drop: dark home disc).
enum MapPinKind { store, customer }

@immutable
class MapPin {
  const MapPin(this.kind, this.point);

  final MapPinKind kind;
  final GeoPoint point;

  @override
  bool operator ==(Object other) =>
      other is MapPin && other.kind == kind && other.point == point;

  @override
  int get hashCode => Object.hash(kind, point);
}

/// What one map shows. Display only: every position, pin and route comes
/// from the server (or the phone's own GPS for the rider); the app never
/// routes and never decides a geofence.
@immutable
class RiderMapSpec {
  const RiderMapSpec({
    required this.pins,
    this.route = const [],
    this.roadRoute = true,
    this.lineFromRider = false,
    this.rider,
    this.showMyLocation = false,
    this.followKey,
  });

  final List<MapPin> pins;

  /// The server's route polyline, decoded (empty: none).
  final List<GeoPoint> route;

  /// False for a straight-line estimate (drawn dashed).
  final bool roadRoute;

  /// Without a [route], draw a dashed straight line from the rider to the
  /// first pin (a leg the server sends no route for, e.g. RETURNING).
  final bool lineFromRider;

  /// The phone's last known position (fits the camera, starts the line).
  final GeoPoint? rider;

  /// Location permission is granted: the map's own my-location layer (blue
  /// dot) may be shown while the app is in front.
  final bool showMyLocation;

  /// The camera fits again, even after the rider panned, when this changes
  /// (the leg or the server's route).
  final Object? followKey;

  /// A road route or a straight line will be drawn as an estimate.
  bool get showsStraightLine =>
      (route.length >= 2 && !roadRoute) ||
      (route.length < 2 && lineFromRider && rider != null && pins.isNotEmpty);

  RiderMapSpec withRider(MapRiderFix fix) => RiderMapSpec(
    pins: pins,
    route: route,
    roadRoute: roadRoute,
    lineFromRider: lineFromRider,
    rider: fix.at,
    showMyLocation: fix.permitted,
    followKey: followKey,
  );
}

/// The phone's position for the maps: permission, and the last known fix.
@immutable
class MapRiderFix {
  const MapRiderFix({required this.permitted, this.at});

  static const none = MapRiderFix(permitted: false);

  final bool permitted;
  final GeoPoint? at;
}

/// Reads the phone's position for the maps without starting GPS: the
/// last known fix (the online foreground service keeps it fresh).
abstract interface class MapLocationSource {
  Future<bool> permitted();
  Future<GeoPoint?> lastKnown();
}

class GeolocatorMapLocationSource implements MapLocationSource {
  const GeolocatorMapLocationSource();

  @override
  Future<bool> permitted() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } on Object {
      return false;
    }
  }

  @override
  Future<GeoPoint?> lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : GeoPoint(p.latitude, p.longitude);
    } on Object {
      return null;
    }
  }
}

final mapLocationSourceProvider = Provider<MapLocationSource>(
  (ref) => const GeolocatorMapLocationSource(),
);

/// How often a shown map re-reads the last known position.
const mapPositionRefresh = Duration(seconds: 15);

/// The rider's position for the maps on screen. Alive only while a map is
/// shown (auto-dispose) and read only while the app is in front.
final riderMapPositionProvider = StreamProvider.autoDispose<MapRiderFix>((ref) {
  final source = ref.watch(mapLocationSourceProvider);
  final controller = StreamController<MapRiderFix>();
  var permitted = false;
  var busy = false;

  Future<void> read({bool checkPermission = false}) async {
    if (busy || controller.isClosed) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    busy = true;
    try {
      if (checkPermission || !permitted) permitted = await source.permitted();
      final at = permitted ? await source.lastKnown() : null;
      if (!controller.isClosed) {
        controller.add(MapRiderFix(permitted: permitted, at: at));
      }
    } finally {
      busy = false;
    }
  }

  unawaited(read(checkPermission: true));
  final timer = Timer.periodic(mapPositionRefresh, (_) => unawaited(read()));
  ref.onDispose(() {
    timer.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

/// Builds the map for a spec. A provider, so widget tests swap the Google
/// Maps platform view for a plain widget.
typedef RiderMapBuilder = Widget Function(RiderMapSpec spec);

final riderMapBuilderProvider = Provider<RiderMapBuilder>(
  (ref) =>
      (spec) => GoogleRiderMap(spec: spec),
);

/// Sections the rider hid (kept while the app runs, per section).
final collapsedMapsProvider = NotifierProvider<CollapsedMaps, Set<String>>(
  CollapsedMaps.new,
);

class CollapsedMaps extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String section) => state = state.contains(section)
      ? ({...state}..remove(section))
      : {...state, section};
}

/// Map height on a step: about a fifth of the screen, never more than
/// 200 dp, so the step's cards and inputs stay in view on small phones.
double smallMapHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * 0.22).clamp(120.0, 200.0);

/// A small map with a "Hide map / Show map" header, shown only when the
/// build has a Maps key (nothing otherwise, so the screen looks as it did
/// before maps). [spec] is called only when the map is shown, so screens
/// without a key never read the extra data.
///
/// Keys: `map-<section>` (the section), `map-<section>-toggle`,
/// `map-<section>-view` (the map), `map-<section>-straight`.
class RiderMapSection extends ConsumerWidget {
  const RiderMapSection({
    required this.section,
    required this.title,
    required this.spec,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
    super.key,
  });

  final String section;
  final String title;
  final RiderMapSpec? Function(WidgetRef ref) spec;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMap = ref.watch(mapsAvailableProvider).value ?? false;
    if (!hasMap) return const SizedBox.shrink();
    final base = spec(ref);
    if (base == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final collapsed = ref.watch(
      collapsedMapsProvider.select((s) => s.contains(section)),
    );
    return Padding(
      padding: padding,
      child: Column(
        key: Key('map-$section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: !collapsed,
            child: InkWell(
              key: Key('map-$section-toggle'),
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  ref.read(collapsedMapsProvider.notifier).toggle(section),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, color: colors.textPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      collapsed ? l10n.mapShow : l10n.mapHide,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      collapsed ? Icons.expand_more : Icons.expand_less,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // A hidden map reads no position (its provider is disposed).
          if (!collapsed) _MapBody(section: section, title: title, spec: base),
        ],
      ),
    );
  }
}

/// The shown map and its "Straight-line estimate" note. Only this part
/// watches the rider's position, so a hidden map stops the 15 s reads.
class _MapBody extends ConsumerWidget {
  const _MapBody({
    required this.section,
    required this.title,
    required this.spec,
  });

  final String section;
  final String title;
  final RiderMapSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fix = ref.watch(riderMapPositionProvider).value ?? MapRiderFix.none;
    final shown = spec.withRider(fix);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: title,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              key: Key('map-$section-view'),
              height: smallMapHeight(context),
              child: ref.watch(riderMapBuilderProvider)(shown),
            ),
          ),
        ),
        if (shown.showsStraightLine)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppLocalizations.of(context).navStraightLine,
              key: Key('map-$section-straight'),
              style: TextStyle(
                fontSize: 14,
                color: RiderColors.of(context).textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// The map's gestures inside a scrolling screen: a one-finger drag that
/// starts vertical stays with the list (its drag slop is smaller than the
/// pan slop), a sideways or diagonal drag pans the map, two fingers zoom.
/// Not an eager recognizer, which would stop the list scrolling over the map.
final Set<Factory<OneSequenceGestureRecognizer>> riderMapGestureRecognizers = {
  Factory<PanGestureRecognizer>(PanGestureRecognizer.new),
  Factory<ScaleGestureRecognizer>(ScaleGestureRecognizer.new),
};

/// The Google Maps platform view for a [RiderMapSpec]: the store and drop
/// pins, the server's route (or a dashed straight line), and the phone's
/// own blue dot while the app is in front with location allowed. The
/// camera fits everything, follows the rider until they pan, and fits again
/// on the recenter button or when the leg or route changes.
class GoogleRiderMap extends StatefulWidget {
  const GoogleRiderMap({required this.spec, super.key});

  final RiderMapSpec spec;

  @override
  State<GoogleRiderMap> createState() => _GoogleRiderMapState();
}

class _GoogleRiderMapState extends State<GoogleRiderMap> {
  static LatLng _ll(GeoPoint p) => LatLng(p.lat, p.lng);

  GoogleMapController? _controller;
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;
  bool _userMoved = false;
  _PinIcons? _icons;
  List<GeoPoint> _fitted = const [];

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final foreground = state == AppLifecycleState.resumed;
        if (foreground != _foreground && mounted) {
          setState(() => _foreground = foreground);
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_icons != null) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    unawaited(
      _PinIcons.load(dpr).then((icons) {
        if (mounted) setState(() => _icons = icons);
      }),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  List<GeoPoint> get _fitPoints => [
    for (final pin in widget.spec.pins) pin.point,
    ...widget.spec.route,
    ?widget.spec.rider,
  ];

  @override
  void didUpdateWidget(GoogleRiderMap old) {
    super.didUpdateWidget(old);
    final c = _controller;
    if (c == null) return;
    if (old.spec.followKey != widget.spec.followKey) {
      _userMoved = false;
      unawaited(_fit(c));
    } else if (!_userMoved && !listEquals(_fitPoints, _fitted)) {
      unawaited(_fit(c));
    }
  }

  Future<void> _fit(GoogleMapController c) async {
    final points = _fitPoints;
    _fitted = points;
    if (points.isEmpty) return;
    try {
      if (points.length < 2) {
        await c.animateCamera(
          CameraUpdate.newLatLngZoom(_ll(points.first), 15),
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
      // The camera is decoration; the step's cards and actions still show.
    }
  }

  void _recenter() {
    setState(() => _userMoved = false);
    final c = _controller;
    if (c != null) unawaited(_fit(c));
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final first =
        spec.rider ??
        (spec.pins.isNotEmpty ? spec.pins.first.point : null) ??
        (spec.route.isNotEmpty ? spec.route.first : const GeoPoint(0, 0));
    final rider = spec.rider;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (_) {
              if (!_userMoved) setState(() => _userMoved = true);
            },
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _ll(first),
                zoom: 14,
              ),
              // The rider's own position: only in front, only with permission.
              myLocationEnabled: _foreground && spec.showMyLocation,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              buildingsEnabled: false,
              trafficEnabled: false,
              indoorViewEnabled: false,
              // Pan and zoom inside the scrolling step list.
              gestureRecognizers: riderMapGestureRecognizers,
              onMapCreated: (c) {
                _controller = c;
                unawaited(_fit(c));
              },
              polylines: {
                if (spec.route.length >= 2)
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [for (final p in spec.route) _ll(p)],
                    color: const Color(0xFF1565C0),
                    width: 5,
                    patterns: spec.roadRoute
                        ? const []
                        : [PatternItem.dash(12), PatternItem.gap(8)],
                  )
                else if (spec.lineFromRider &&
                    rider != null &&
                    spec.pins.isNotEmpty)
                  Polyline(
                    polylineId: const PolylineId('straight'),
                    points: [_ll(rider), _ll(spec.pins.first.point)],
                    color: const Color(0xFF1565C0),
                    width: 4,
                    patterns: [PatternItem.dash(12), PatternItem.gap(8)],
                  ),
              },
              markers: {
                for (final pin in spec.pins)
                  Marker(
                    markerId: MarkerId(pin.kind.name),
                    position: _ll(pin.point),
                    anchor: const Offset(0.5, 0.5),
                    icon: switch (pin.kind) {
                      MapPinKind.store =>
                        _icons?.store ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ),
                      MapPinKind.customer =>
                        _icons?.customer ??
                            BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen,
                            ),
                    },
                  ),
              },
            ),
          ),
        ),
        PositionedDirectional(
          end: 8,
          bottom: 8,
          child: IconButton.filledTonal(
            key: const Key('map-recenter'),
            tooltip: l10n.mapRecenter,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
            ),
            onPressed: _recenter,
            icon: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }
}

/// Painted pin icons, as in the customer app: a white-ringed disc with a
/// shop (store) or home (drop) glyph. Drawn once per map.
class _PinIcons {
  const _PinIcons({required this.store, required this.customer});

  final BitmapDescriptor store;
  final BitmapDescriptor customer;

  static final _cache = <double, Future<_PinIcons>>{};

  /// Painted once per device pixel ratio, shared by every map.
  static Future<_PinIcons> load(double dpr) =>
      _cache.putIfAbsent(dpr, () => _paint(dpr));

  static Future<_PinIcons> _paint(double dpr) async {
    final results = await Future.wait([
      _disc(Icons.storefront, const Color(0xFF1E6FD9), dpr),
      _disc(Icons.home_rounded, const Color(0xFF263238), dpr),
    ]);
    return _PinIcons(store: results[0], customer: results[1]);
  }

  static Future<BitmapDescriptor> _disc(
    IconData icon,
    Color color,
    double dpr, {
    double size = 34,
  }) async {
    // Fall back to the default pin when painting is not possible.
    try {
      final px = size * dpr;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final c = Offset(px / 2, px / 2);
      final r = px / 2 - 2 * dpr;
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
    } on Object {
      return BitmapDescriptor.defaultMarker;
    }
  }
}
