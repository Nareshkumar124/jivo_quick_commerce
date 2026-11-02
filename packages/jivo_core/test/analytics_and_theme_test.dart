import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

class RecordingAnalytics implements AnalyticsClient {
  final screens = <String>[];

  @override
  Future<void> logEvent(
    String name, {
    Map<String, Object> parameters = const {},
  }) async {}

  @override
  Future<void> logScreenView(String screenName) async =>
      screens.add(screenName);

  @override
  Future<void> setUserId(String? userId) async {}
}

void main() {
  testWidgets('the navigator observer reports named routes only', (
    tester,
  ) async {
    final analytics = RecordingAnalytics();
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [AnalyticsNavigatorObserver(analytics)],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: RouteSettings(
            name: settings.name == '/' ? 'home' : settings.name,
          ),
          builder: (_) => const SizedBox(),
        ),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'cart'),
        builder: (_) => const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(analytics.screens, ['home', 'cart', 'cart']);
  });

  test('the no-op and debug clients accept every call', () async {
    for (final client in const [
      NoopAnalyticsClient(),
      DebugAnalyticsClient(),
    ]) {
      await client.logEvent('add_to_cart', parameters: {'variant_id': 1});
      await client.logScreenView('home');
      await client.setUserId(null);
    }
  });

  group('JivoTheme', () {
    test('light and dark themes carry the Jivo colour extension', () {
      expect(JivoTheme.light().extension<JivoColors>(), JivoColors.light);
      expect(JivoTheme.dark().extension<JivoColors>(), JivoColors.dark);
      expect(JivoTheme.dark().colorScheme.brightness, Brightness.dark);
    });

    testWidgets('buttons meet the 48 dp touch target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: JivoTheme.light(),
          home: Scaffold(
            body: Center(
              child: FilledButton(onPressed: () {}, child: const Text('OK')),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(kJivoMinTouchTarget));
    });
  });
}
