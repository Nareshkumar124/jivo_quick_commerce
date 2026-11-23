import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:customer_app/shared/widgets/jivo_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('the wordmark shows the brand asset and reads "Jivo"', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const JivoWordmark(height: 40)));

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, JivoWordmark.asset);
    expect(tester.getSize(find.byType(Image)).height, 40);
    expect(find.bySemanticsLabel('Jivo'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a tint colours the wordmark with srcIn', (tester) async {
    await tester.pumpWidget(_app(const JivoWordmark(color: Colors.white)));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, Colors.white);
    expect(image.colorBlendMode, BlendMode.srcIn);
  });
}
