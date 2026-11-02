import 'package:mappls_gl/mappls_gl.dart';

import '../../addresses/data/device_location.dart';

/// Turns a map pin into an address line for the picker preview and the
/// notify-me `address_text` (`03 §2.3`).
abstract interface class ReverseGeocoder {
  /// The formatted address at [point], or null when unknown. Never throws.
  Future<String?> addressAt(GeoPoint point);
}

/// Mappls reverse geocoding (D-03), authenticated by the same SDK config
/// as the map. Only used while a map is shown, i.e. when the config is
/// present.
class MapplsReverseGeocoder implements ReverseGeocoder {
  const MapplsReverseGeocoder();

  @override
  Future<String?> addressAt(GeoPoint point) async {
    try {
      final response = await MapplsReverseGeocode(
        location: LatLng(point.lat, point.lng),
      ).callReverseGeocode();
      final results = response?.results;
      final address = results == null || results.isEmpty
          ? null
          : results.first.formattedAddress?.trim();
      return address == null || address.isEmpty ? null : address;
    } catch (_) {
      return null;
    }
  }
}

/// For tests: returns [address] and records the points asked for.
class FakeReverseGeocoder implements ReverseGeocoder {
  FakeReverseGeocoder([this.address]);

  String? address;
  final List<GeoPoint> asked = [];

  @override
  Future<String?> addressAt(GeoPoint point) async {
    asked.add(point);
    return address;
  }
}
