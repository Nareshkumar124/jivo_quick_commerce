import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

/// The single analytics entry point for the apps (`03 §4`).
///
/// The backing provider is decided in D-19 (Firebase Analytics recommended).
/// Until then apps use [DebugAnalyticsClient] in non-prod flavors and
/// [NoopAnalyticsClient] in prod.
abstract interface class AnalyticsClient {
  /// Logs a named event, e.g. `add_to_cart`. Parameter values must be
  /// strings, numbers or booleans.
  Future<void> logEvent(String name, {Map<String, Object> parameters});

  /// Logs that a screen became visible.
  Future<void> logScreenView(String screenName);

  /// Associates later events with a user id, or clears it with null.
  Future<void> setUserId(String? userId);
}

/// Discards every call.
class NoopAnalyticsClient implements AnalyticsClient {
  const NoopAnalyticsClient();

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object> parameters = const {},
  }) async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

/// Writes every call to the developer log (visible in DevTools / `flutter run`).
class DebugAnalyticsClient implements AnalyticsClient {
  const DebugAnalyticsClient();

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object> parameters = const {},
  }) async => developer.log('event $name $parameters', name: 'analytics');

  @override
  Future<void> logScreenView(String screenName) async =>
      developer.log('screen_view $screenName', name: 'analytics');

  @override
  Future<void> setUserId(String? userId) async => developer.log(
    'user_id ${userId == null ? 'cleared' : 'set'}',
    name: 'analytics',
  );
}

/// Logs a screen view for every named page route that becomes visible.
///
/// With go_router, give each `GoRoute` a `name`; that name is reported.
class AnalyticsNavigatorObserver extends NavigatorObserver {
  AnalyticsNavigatorObserver(this.analytics);

  final AnalyticsClient analytics;

  void _report(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (route is PageRoute && name != null && name.isNotEmpty) {
      analytics.logScreenView(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(previousRoute);
}
