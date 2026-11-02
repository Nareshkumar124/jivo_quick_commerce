import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/delivery_location.dart';

/// Remembers the selected delivery location across launches.
class DeliveryLocationStore {
  const DeliveryLocationStore(this._prefs);

  static const key = 'delivery_location';

  final SharedPreferences _prefs;

  DeliveryLocation? read() {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?>
          ? DeliveryLocation.fromJson(json)
          : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> write(DeliveryLocation location) =>
      _prefs.setString(key, jsonEncode(location.toJson()));

  Future<void> clear() => _prefs.remove(key);
}
