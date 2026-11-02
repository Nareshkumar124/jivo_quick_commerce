import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The JWT pair issued by `otp/verify` and rotated by `token/refresh`.
@immutable
class AuthTokens {
  const AuthTokens({required this.access, required this.refresh});

  /// Short-lived access token (15 minutes), sent as `Authorization: Bearer`.
  final String access;

  /// Refresh token (30 days). It works exactly once: every refresh returns a
  /// new one.
  final String refresh;

  Map<String, String> toJson() => {'access': access, 'refresh': refresh};

  /// Parses [toJson] output. Returns null when either token is missing.
  static AuthTokens? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final access = json['access'];
    final refresh = json['refresh'];
    if (access is! String || access.isEmpty) return null;
    if (refresh is! String || refresh.isEmpty) return null;
    return AuthTokens(access: access, refresh: refresh);
  }

  @override
  bool operator ==(Object other) =>
      other is AuthTokens && other.access == access && other.refresh == refresh;

  @override
  int get hashCode => Object.hash(access, refresh);

  /// Never prints the tokens.
  @override
  String toString() => 'AuthTokens(<redacted>)';
}

/// Persists the token pair. Writes are atomic: both tokens or neither.
abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// Stores the pair in the Android Keystore / iOS Keychain via
/// flutter_secure_storage.
///
/// Both tokens live in **one** entry (a JSON value), so a single write
/// replaces them together. With two entries, a crash between the writes
/// could pair a new access token with an already-revoked refresh token.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage, this.key = defaultKey})
    : _storage = storage ?? const FlutterSecureStorage(iOptions: _iosOptions);

  static const defaultKey = 'jivo.session.tokens';

  // Readable after the first unlock (background work such as the rider's
  // location upload may refresh tokens while locked); never synced to other
  // devices or restored from backups.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;
  final String key;

  /// Returns null (signed out) when the entry is missing or unreadable,
  /// e.g. after a backup restore or a keystore reset on Android, and then
  /// removes the unreadable entry.
  @override
  Future<AuthTokens?> read() async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return null;
      final tokens = AuthTokens.tryFromJson(jsonDecode(raw));
      if (tokens != null) return tokens;
    } catch (_) {
      // Unreadable: fall through and remove it.
    }
    try {
      await clear();
    } catch (_) {
      // Best effort; the next sign-in overwrites the entry.
    }
    return null;
  }

  @override
  Future<void> write(AuthTokens tokens) =>
      _storage.write(key: key, value: jsonEncode(tokens.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: key);
}

/// Keeps the pair in memory only. For tests and previews.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
