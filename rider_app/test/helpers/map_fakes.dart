import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/presentation/navigation_panel.dart';
import 'package:rider_app/shared/map/rider_map.dart';

/// The phone's position for the maps, without geolocator.
class FakeMapLocationSource implements MapLocationSource {
  bool allowed = true;
  GeoPoint? fix = const GeoPoint(28.5651, 77.3199);

  @override
  Future<bool> permitted() async => allowed;

  /// Position reads so far.
  int reads = 0;

  @override
  Future<GeoPoint?> lastKnown() async {
    reads++;
    return fix;
  }
}

/// The specs the stub maps were last built with, newest last.
final builtMapSpecs = <RiderMapSpec>[];

/// "This build has a Maps key" with plain widgets in place of the Google
/// Maps platform view ([maps] false: no key).
List<Override> mapOverrides({required bool maps}) => [
  mapsAvailableProvider.overrideWith((ref) async => maps),
  riderMapBuilderProvider.overrideWithValue((spec) {
    builtMapSpecs.add(spec);
    return ColoredBox(
      key: const Key('stub-map'),
      color: Colors.blueGrey,
      child: Text('${spec.pins.length} pins', maxLines: 1),
    );
  }),
  taskMapBuilderProvider.overrideWithValue(
    (navigation, destination) =>
        const ColoredBox(key: Key('stub-nav-map'), color: Colors.blueGrey),
  ),
];
