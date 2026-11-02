// On-device check of the Mappls map pin picker (D-03). Run on an emulator
// or device, never in CI:
//
//   customer_app/tool/setup_mappls.sh      # without it: the fallback path
//   flutter test integration_test/map_picker_test.dart --flavor dev -d <device>
//
// With the Mappls config built in, the picker must show a map that
// authenticates (no map error, so no fallback) and resolve the address
// under the pin. Without the config it must show the fallback, not crash.
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/location/data/maps_availability.dart';
import 'package:customer_app/features/location/presentation/map_picker_screen.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:mappls_gl/mappls_gl.dart';

Future<void> pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the map picker shows a Mappls map or the fallback', (
    tester,
  ) async {
    final configured = await const PlatformMapsAvailability().isAvailable();
    debugPrint('MAPPLS_CHECK configured=$configured');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: JivoTheme.light(),
          locale: const Locale('en', 'IN'),
          supportedLocales: const [Locale('en', 'IN')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            JivoCoreLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MapPickerScreen(),
        ),
      ),
    );
    // Map tiles, authentication and the reverse geocode take a few seconds.
    await pumpFor(tester, const Duration(seconds: 15));

    final fallback = find.byKey(const Key('map-unavailable'));
    final map = find.byType(MapplsMap);
    debugPrint(
      'MAPPLS_CHECK map=${map.evaluate().isNotEmpty} '
      'fallback=${fallback.evaluate().isNotEmpty}',
    );
    if (!configured) {
      expect(fallback, findsOneWidget);
      return;
    }
    expect(map, findsOneWidget, reason: 'a map error switched to fallback');
    final address = tester.widget<Text>(find.byKey(const Key('pin-address')));
    debugPrint('MAPPLS_CHECK pin_address="${address.data}"');

    // Reverse geocoding on its own, at the default centre.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPickerScreen)),
    );
    final direct = await container
        .read(reverseGeocoderProvider)
        .addressAt(kDefaultMapCenter);
    debugPrint('MAPPLS_CHECK reverse_geocode="$direct"');
  });
}
