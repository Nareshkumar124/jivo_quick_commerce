import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/l10n/app_localizations.dart';
import 'package:rider_app/shared/widgets/jivo_wordmark.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('shows the brand asset with the "Jivo Rider" label', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const JivoWordmark()));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, JivoWordmark.asset);
    expect(image.color, isNull);
    expect(find.bySemanticsLabel('Jivo Rider'), findsOneWidget);
  });

  testWidgets('is tinted in dark mode and when a colour is given', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const JivoWordmark(), brightness: Brightness.dark),
    );
    expect(tester.widget<Image>(find.byType(Image)).color, isNotNull);

    await tester.pumpWidget(_app(const JivoWordmark(color: Colors.white)));
    expect(tester.widget<Image>(find.byType(Image)).color, Colors.white);
  });
}
