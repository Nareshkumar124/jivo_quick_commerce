import 'package:flutter/foundation.dart';

import '../../addresses/data/device_location.dart';

/// The store serving a location (`06 §2.3`).
@immutable
class StoreInfo {
  const StoreInfo({
    required this.id,
    required this.name,
    required this.isOpen,
    this.opensAt,
  });

  /// Sent as `X-Store-Id` on catalog and cart calls.
  final int id;
  final String name;
  final bool isOpen;

  /// The next opening (UTC), shown in IST. Null when open, or closed with
  /// no known reopening time.
  final DateTime? opensAt;
}

/// `GET /serviceability/?lat=&lng=` (`06 §2.3`).
@immutable
class Serviceability {
  const Serviceability({
    required this.serviceable,
    this.store,
    this.etaMinutes,
    this.message,
  });

  /// Inside an active store's area, whether or not the store is open.
  final bool serviceable;

  /// Null when not serviceable (the API never returns an error for that).
  final StoreInfo? store;

  /// Null when not serviceable or the store is closed.
  final int? etaMinutes;

  /// Server text when not serviceable or closed (times in IST).
  final String? message;

  bool get storeClosed => serviceable && store != null && !store!.isOpen;
}

/// The location the customer shops for: a saved address or a pin.
@immutable
class DeliveryLocation {
  const DeliveryLocation({
    required this.point,
    required this.title,
    this.subtitle,
    this.addressId,
  });

  final GeoPoint point;

  /// "Home", "Work", or "Current location"/"Pinned location".
  final String title;

  /// The address line, when known.
  final String? subtitle;

  /// Set when it is a saved address.
  final int? addressId;

  Map<String, Object?> toJson() => {
    'lat': point.lat,
    'lng': point.lng,
    'title': title,
    'subtitle': subtitle,
    'address_id': addressId,
  };

  /// Null when [json] is not a stored location.
  static DeliveryLocation? fromJson(Map<String, Object?> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    final title = json['title'];
    if (lat is! num || lng is! num || title is! String) return null;
    final subtitle = json['subtitle'];
    final addressId = json['address_id'];
    return DeliveryLocation(
      point: (lat: lat.toDouble(), lng: lng.toDouble()),
      title: title,
      subtitle: subtitle is String ? subtitle : null,
      addressId: addressId is int ? addressId : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeliveryLocation &&
      other.point == point &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.addressId == addressId;

  @override
  int get hashCode => Object.hash(point, title, subtitle, addressId);
}
