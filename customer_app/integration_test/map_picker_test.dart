// On-device check of the Google Maps pin picker (DL-80). Run on a device,
// never in CI:
//
//   flutter test integration_test/map_picker_test.dart --flavor dev -d <device>
//
// With a Maps API key built in (README "Google Maps key"), the picker must
// show a map and resolve the address under the pin. Without a key it must
// show the fallback, not crash.
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
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<void> pumpFor(WidgetTester tester, Duration total) async {
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the map picker shows a Google map or the fallback', (
    tester,
  ) async {
    final configured = await const PlatformMapsAvailability().isAvailable();
    debugPrint('MAPS_CHECK configured=$configured');

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
    // Map tiles and the reverse geocode take a few seconds.
    await pumpFor(tester, const Duration(seconds: 15));

    final fallback = find.byKey(const Key('map-unavailable'));
    final map = find.byType(GoogleMap);
    debugPrint(
      'MAPS_CHECK map=${map.evaluate().isNotEmpty} '
      'fallback=${fallback.evaluate().isNotEmpty}',
    );
    if (!configured) {
      expect(fallback, findsOneWidget);
      return;
    }
    expect(
      map,
      findsOneWidget,
      reason: 'a key was built in but no map is shown',
    );
    final address = tester.widget<Text>(find.byKey(const Key('pin-address')));
    debugPrint('MAPS_CHECK pin_address="${address.data}"');

    // Reverse geocoding on its own, at the default centre.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapPickerScreen)),
    );
    final direct = await container
        .read(reverseGeocoderProvider)
        .addressAt(kDefaultMapCenter);
    debugPrint('MAPS_CHECK reverse_geocode="$direct"');
  });
}
