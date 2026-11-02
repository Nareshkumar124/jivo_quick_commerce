import 'package:shared_preferences/shared_preferences.dart';

/// Recent searches, stored on the device only (`03 §2.7`).
class RecentSearchesStore {
  const RecentSearchesStore(this._prefs);

  static const key = 'recent_searches';
  static const limit = 10;

  final SharedPreferences _prefs;

  List<String> read() => _prefs.getStringList(key) ?? const [];

  /// Puts [query] first, without duplicates (case-insensitive), keeping
  /// [limit] entries. Returns the new list.
  Future<List<String>> add(String query) async {
    final text = query.trim();
    if (text.isEmpty) return read();
    final next = [
      text,
      ...read().where((q) => q.toLowerCase() != text.toLowerCase()),
    ].take(limit).toList();
    await _prefs.setStringList(key, next);
    return next;
  }

  Future<void> clear() => _prefs.remove(key);
}
