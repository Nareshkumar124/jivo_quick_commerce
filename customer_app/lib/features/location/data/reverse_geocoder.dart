import 'package:flutter/foundation.dart';
import 'package:mappls_gl/mappls_gl.dart';

import '../../addresses/data/device_location.dart';

/// The parts of an address at a pin, for prefilling the address form
/// (`03 §2.4`). Every part may be missing; the customer edits them all.
@immutable
class AddressParts {
  const AddressParts({
    this.line,
    this.area,
    this.city,
    this.state,
    this.pincode,
  });

  /// The formatted address, for display.
  final String? line;
  final String? area;
  final String? city;
  final String? state;
  final String? pincode;
}

/// Turns a map pin into an address line for the picker preview and the
/// notify-me `address_text` (`03 §2.3`), and into [AddressParts] for the
/// address form.
abstract interface class ReverseGeocoder {
  /// The formatted address at [point], or null when unknown. Never throws.
  Future<String?> addressAt(GeoPoint point);

  /// The address parts at [point], or null when unknown. Never throws.
  Future<AddressParts?> partsAt(GeoPoint point);
}

/// Mappls reverse geocoding (D-03), authenticated by the same SDK config
/// as the map. Only used while a map is shown, i.e. when the config is
/// present.
class MapplsReverseGeocoder implements ReverseGeocoder {
  const MapplsReverseGeocoder();

  Future<ReverseGeocodePlace?> _place(GeoPoint point) async {
    try {
      final response = await MapplsReverseGeocode(
        location: LatLng(point.lat, point.lng),
      ).callReverseGeocode();
      final results = response?.results;
      return results == null || results.isEmpty ? null : results.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> addressAt(GeoPoint point) async =>
      _clean((await _place(point))?.formattedAddress);

  @override
  Future<AddressParts?> partsAt(GeoPoint point) async {
    final place = await _place(point);
    if (place == null) return null;
    return AddressParts(
      line: _clean(place.formattedAddress),
      area: _clean(place.subLocality) ?? _clean(place.locality),
      city: _clean(place.city) ?? _clean(place.district),
      state: _clean(place.state),
      pincode: _clean(place.pincode),
    );
  }

  static String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// For tests: returns [address] / [parts] and records the points asked for.
class FakeReverseGeocoder implements ReverseGeocoder {
  FakeReverseGeocoder([this.address]);

  String? address;
  AddressParts? parts;
  final List<GeoPoint> asked = [];

  @override
  Future<String?> addressAt(GeoPoint point) async {
    asked.add(point);
    return address;
  }

  @override
  Future<AddressParts?> partsAt(GeoPoint point) async {
    asked.add(point);
    return parts;
  }
}
