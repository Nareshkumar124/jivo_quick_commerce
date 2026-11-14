import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/home/presentation/banner_viewer.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _banner = HomeBanner(id: 1, title: 'Price list');

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBannerViewer(context, _banner),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

TransformationController _controller(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byKey(const Key('banner-viewer-zoom')))
    .transformationController!;

double _scale(WidgetTester tester) =>
    _controller(tester).value.getMaxScaleOnAxis();

void main() {
  testWidgets('pinch zooms in, and out again', (tester) async {
    await _open(tester);
    final c = tester.getCenter(find.byKey(const Key('banner-viewer-zoom')));
    final a = await tester.startGesture(c - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(c + const Offset(20, 0), pointer: 2);
    await tester.pump();
    await a.moveTo(c - const Offset(80, 0));
    await b.moveTo(c + const Offset(80, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(1.5));
    expect(_scale(tester), lessThanOrEqualTo(5.0001));
    expect(find.byType(BannerViewer), findsOneWidget);
  });

  testWidgets('double tap zooms to 2.5x and back', (tester) async {
    await _open(tester);
    final target = find.byKey(const Key('banner-viewer-zoom'));
    Future<void> doubleTap() async {
      await tester.tapAt(tester.getCenter(target) + const Offset(40, 30));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(tester.getCenter(target) + const Offset(40, 30));
      await tester.pumpAndSettle();
    }

    await doubleTap();
    expect(_scale(tester), closeTo(2.5, 0.01));
    await doubleTap();
    expect(_scale(tester), closeTo(1, 0.01));
  });

  testWidgets('swipe down closes at 1x but is ignored while zoomed', (
    tester,
  ) async {
    await _open(tester);
    final target = find.byKey(const Key('banner-viewer-zoom'));
    final c = tester.getCenter(target);
    await tester.tapAt(c);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(c);
    await tester.pumpAndSettle();
    expect(_scale(tester), greaterThan(2));

    await tester.fling(target, const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(BannerViewer), findsOneWidget);

    await tester.tapAt(c);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(c);
    await tester.pumpAndSettle();
    expect(_scale(tester), closeTo(1, 0.01));

    await tester.fling(target, const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    expect(find.byType(BannerViewer), findsNothing);
  });
}
