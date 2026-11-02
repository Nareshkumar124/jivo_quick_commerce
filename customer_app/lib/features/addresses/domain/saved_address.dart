import 'package:flutter/foundation.dart';

enum AddressLabel { home, work, other }

/// The editable part of an address (`03 §2.4`). `lat`/`lng` are required by
/// the backend; in Phase 1 they come from the device location (no map yet).
@immutable
class AddressInput {
  const AddressInput({
    required this.label,
    required this.house,
    required this.buildingStreet,
    required this.city,
    required this.state,
    required this.pincode,
    required this.lat,
    required this.lng,
    this.customLabel,
    this.landmark,
    this.area,
    this.receiverName,
    this.receiverPhone,
  });

  final AddressLabel label;
  final String? customLabel;
  final String house;
  final String buildingStreet;
  final String? landmark;
  final String? area;
  final String city;
  final String state;
  final String pincode;

  /// Null means "the user's own" (the backend default).
  final String? receiverName;
  final String? receiverPhone;
  final double lat;
  final double lng;
}

@immutable
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.input,
    required this.isDefault,
  });

  final int id;
  final AddressInput input;
  final bool isDefault;

  /// The title to show: the custom label when set.
  String? get customTitle {
    final custom = input.customLabel?.trim();
    return custom == null || custom.isEmpty ? null : custom;
  }

  /// One line: house, building/street, area, city, PIN.
  String get summary => [
    input.house,
    input.buildingStreet,
    if (input.landmark?.trim().isNotEmpty ?? false) input.landmark!,
    if (input.area?.trim().isNotEmpty ?? false) input.area!,
    input.city,
    input.pincode,
  ].join(', ');
}
