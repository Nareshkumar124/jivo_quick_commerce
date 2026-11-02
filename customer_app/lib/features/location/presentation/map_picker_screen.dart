import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:mappls_gl/mappls_gl.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../addresses/data/device_location.dart';
import 'delivery_controller.dart';
import 'location_flow.dart';

/// Where the map opens without a better point: central New Delhi.
const kDefaultMapCenter = (lat: 28.613939, lng: 77.209023);

/// What the picker returns: the pin and, when reverse geocoding found one,
/// its address.
typedef PickedLocation = ({GeoPoint point, String? address});

/// Builds the map under the pin. A provider, so widget tests can swap the
/// Mappls platform view for a plain widget.
typedef PinMapBuilder = Widget Function({
  required GeoPoint initial,
  required void Function(MapplsMapController controller) onCreated,
  required VoidCallback onCameraIdle,
  required void Function(int code, String message) onError,
});

final pinMapBuilderProvider = Provider<PinMapBuilder>((ref) => _mapplsMap);

Widget _mapplsMap({
  required GeoPoint initial,
  required void Function(MapplsMapController controller) onCreated,
  required VoidCallback onCameraIdle,
  required void Function(int code, String message) onError,
}) => MapplsMap(
  initialCameraPosition: CameraPosition(
    target: LatLng(initial.lat, initial.lng),
    zoom: 16,
  ),
  trackCameraPosition: true,
  compassEnabled: false,
  onMapCreated: onCreated,
  onCameraIdle: onCameraIdle,
  onMapError: onError,
);

/// Map pin picker (`03 §3` #12, D-03 Mappls): the pin stays in the centre
/// while the map moves under it; the address under the pin is previewed;
/// "Confirm location" pops a [PickedLocation].
///
/// The map is only created when the Mappls SDK config was built into the
/// app (see README). Without it, or when the map reports an error (e.g.
/// authentication), a fallback offers the current location or manual entry.
class MapPickerScreen extends ConsumerStatefulWidget {
  const MapPickerScreen({this.initial, super.key});

  final GeoPoint? initial;

  @override
  ConsumerState<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends ConsumerState<MapPickerScreen> {
  bool _mapFailed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(mapsAvailableProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapPickerTitle)),
      body: switch (available) {
        AsyncData(value: true) when !_mapFailed => _PinMap(
          initial: widget.initial ?? kDefaultMapCenter,
          onMapError: () => setState(() => _mapFailed = true),
        ),
        AsyncData() || AsyncError() => const _MapUnavailable(),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PinMap extends ConsumerStatefulWidget {
  const _PinMap({required this.initial, required this.onMapError});

  final GeoPoint initial;
  final VoidCallback onMapError;

  @override
  ConsumerState<_PinMap> createState() => _PinMapState();
}

class _PinMapState extends ConsumerState<_PinMap> {
  MapplsMapController? _controller;
  late GeoPoint _center = widget.initial;
  String? _address;
  bool _resolving = false;
  int _lookup = 0;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _resolve(_center);
  }

  void _onCameraIdle() {
    final target = _controller?.cameraPosition?.target;
    if (target == null) return;
    final center = (lat: target.latitude, lng: target.longitude);
    if (center == _center && _address != null) return;
    setState(() => _center = center);
    _resolve(center);
  }

  /// Looks up the address under the pin; only the latest lookup counts.
  Future<void> _resolve(GeoPoint point) async {
    final lookup = ++_lookup;
    setState(() {
      _resolving = true;
      _address = null;
    });
    final address = await ref.read(reverseGeocoderProvider).addressAt(point);
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _resolving = false;
      _address = address;
    });
  }

  Future<void> _locateMe() async {
    setState(() => _locating = true);
    try {
      final point = await ref.read(deviceLocationProvider).current();
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(point.lat, point.lng), 17),
      );
    } on LocationException catch (e) {
      if (mounted) {
        showMessage(
          context,
          locationFailureText(AppLocalizations.of(context), e.reason),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final address = _address;
    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ref.watch(pinMapBuilderProvider)(
                initial: widget.initial,
                onCreated: (controller) => _controller = controller,
                onCameraIdle: _onCameraIdle,
                onError: (code, message) {
                  // Usually authentication: the config does not match this
                  // package name / signing certificate.
                  debugPrint('Mappls map error $code: $message');
                  widget.onMapError();
                },
              ),
              // The pin's tip marks the centre.
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Icon(
                    Icons.location_pin,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              Positioned(
                right: JivoSpacing.gutter,
                bottom: JivoSpacing.gutter,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: l10n.locateMe,
                  onPressed: _locating ? null : _locateMe,
                  child: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(JivoSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.mapPickerHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: JivoSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    address ??
                        (_resolving
                            ? l10n.findingAddress
                            : l10n.pinCoordinates(
                                formatCoordinate(_center.lat),
                                formatCoordinate(_center.lng),
                              )),
                    key: const Key('pin-address'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: JivoSpacing.md),
                BusyButton(
                  label: l10n.confirmLocation,
                  onPressed: () => context.pop<PickedLocation>((
                    point: _center,
                    address: address,
                  )),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// No map in this build (or it failed to load): current location or manual
/// address entry.
class _MapUnavailable extends ConsumerStatefulWidget {
  const _MapUnavailable();

  @override
  ConsumerState<_MapUnavailable> createState() => _MapUnavailableState();
}

class _MapUnavailableState extends ConsumerState<_MapUnavailable> {
  bool _locating = false;
  LocationFailure? _failure;

  Future<void> _useCurrent() async {
    setState(() {
      _locating = true;
      _failure = null;
    });
    try {
      final point = await ref.read(deviceLocationProvider).current();
      if (mounted) {
        context.pop<PickedLocation>((point: point, address: null));
      }
    } on LocationException catch (e) {
      if (mounted) setState(() => _failure = e.reason);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final failure = _failure;
    return Center(
      child: SingleChildScrollView(
        key: const Key('map-unavailable'),
        padding: const EdgeInsets.all(JivoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: JivoSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.mapUnavailableTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            Text(l10n.mapUnavailableBody, textAlign: TextAlign.center),
            if (failure != null) ...[
              const SizedBox(height: JivoSpacing.lg),
              Semantics(
                liveRegion: true,
                child: Text(
                  locationFailureText(l10n, failure),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              if (failure != LocationFailure.unavailable)
                TextButton(
                  onPressed: () =>
                      ref.read(deviceLocationProvider).openSettings(failure),
                  child: Text(l10n.openSettings),
                ),
            ],
            const SizedBox(height: JivoSpacing.xl),
            BusyButton(
              label: l10n.detectLocation,
              busy: _locating,
              onPressed: _useCurrent,
            ),
            const SizedBox(height: JivoSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.pushReplacement(Routes.newAddress),
                child: Text(l10n.enterAddressManually),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
