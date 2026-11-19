import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' show Geocoding, Placemark;

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

/// Looks up the placemarks at a point. The default is the platform
/// geocoder; tests pass their own.
typedef PlacemarkLookup = Future<List<Placemark>> Function(GeoPoint point);

Future<List<Placemark>> _platformLookup(GeoPoint point) =>
    Geocoding().placemarkFromCoordinates(point.lat, point.lng);

/// Reverse geocoding with the platform geocoder (`geocoding` package,
/// DL-80): no API key, no billing. Results depend on the device's geocoder
/// service; when it has none or fails, the picker shows the coordinates and
/// the customer types the address.
class PlatformReverseGeocoder implements ReverseGeocoder {
  const PlatformReverseGeocoder({this._lookup = _platformLookup});

  final PlacemarkLookup _lookup;

  Future<Placemark?> _place(GeoPoint point) async {
    try {
      final results = await _lookup(point);
      return results.isEmpty ? null : results.first;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> addressAt(GeoPoint point) async {
    final place = await _place(point);
    return place == null ? null : addressLine(place);
  }

  @override
  Future<AddressParts?> partsAt(GeoPoint point) async {
    final place = await _place(point);
    return place == null ? null : partsOf(place);
  }

  /// The parts of [place] for the address form.
  @visibleForTesting
  static AddressParts partsOf(Placemark place) => AddressParts(
    line: addressLine(place),
    area: _clean(place.subLocality) ?? _clean(place.locality),
    city: _clean(place.locality) ?? _clean(place.subAdministrativeArea),
    state: _clean(place.administrativeArea),
    pincode: _clean(place.postalCode),
  );

  /// One line from the placemark's parts. Android's `street` is often the
  /// whole formatted address already, so a part already contained in the
  /// line is skipped.
  @visibleForTesting
  static String? addressLine(Placemark place) {
    final parts = <String>[];
    for (final raw in [
      place.street ?? place.name,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.postalCode,
    ]) {
      final part = _clean(raw);
      if (part == null) continue;
      final lower = part.toLowerCase();
      if (parts.any((p) => p.toLowerCase().contains(lower))) continue;
      parts.add(part);
    }
    return parts.isEmpty ? null : parts.join(', ');
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
