import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two small flags the FCM background isolate and the app share (code
/// review of the D-19 wiring). Plain SharedPreferences, not secure storage:
/// they hold no secret, and the background isolate must read them fast.
///
/// - [signedIn]: a rider session exists on this phone. The background
///   handler rings the offer alarm only while it is on, so a token that
///   could not be deleted at sign-out never rings for the next person.
/// - [tokenDeletePending]: a sign-out could not delete the local FCM token
///   (offline); the app retries on its next start.
///
/// Reads and writes never throw: a failure reads as "off" / "not pending".
abstract interface class PushGuardStore {
  Future<bool> signedIn();

  Future<void> setSignedIn(bool value);

  Future<bool> tokenDeletePending();

  Future<void> setTokenDeletePending(bool value);
}

/// [PushGuardStore] over `SharedPreferencesAsync` (no cache, so the
/// background isolate always reads what the app wrote last).
class PrefsPushGuardStore implements PushGuardStore {
  PrefsPushGuardStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const signedInKey = 'push_rider_signed_in';
  static const tokenDeletePendingKey = 'push_token_delete_pending';

  Future<bool> _get(String key) async {
    try {
      return await _prefs.getBool(key) ?? false;
    } on Object catch (error) {
      debugPrint('PushGuardStore: read failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> _set(String key, bool value) async {
    try {
      await _prefs.setBool(key, value);
    } on Object catch (error) {
      debugPrint('PushGuardStore: write failed: ${error.runtimeType}');
    }
  }

  @override
  Future<bool> signedIn() => _get(signedInKey);

  @override
  Future<void> setSignedIn(bool value) => _set(signedInKey, value);

  @override
  Future<bool> tokenDeletePending() => _get(tokenDeletePendingKey);

  @override
  Future<void> setTokenDeletePending(bool value) =>
      _set(tokenDeletePendingKey, value);
}

/// Tests.
class InMemoryPushGuardStore implements PushGuardStore {
  InMemoryPushGuardStore({this.isSignedIn = false, this.deletePending = false});

  bool isSignedIn;
  bool deletePending;

  @override
  Future<bool> signedIn() async => isSignedIn;

  @override
  Future<void> setSignedIn(bool value) async => isSignedIn = value;

  @override
  Future<bool> tokenDeletePending() async => deletePending;

  @override
  Future<void> setTokenDeletePending(bool value) async => deletePending = value;
}
