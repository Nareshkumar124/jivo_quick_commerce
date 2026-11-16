import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/home/presentation/banner_carousel.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('a referral banner opens the Refer & earn route', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: BannerCarousel(
              banners: [
                HomeBanner(
                  id: 1,
                  title: 'Refer a friend',
                  link: ReferralBannerLink(),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: Routes.referral,
          builder: (_, _) => const Scaffold(body: Text('REFERRAL SCREEN')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('banner-carousel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('banner-viewer-action')));
    await tester.pumpAndSettle();

    expect(find.text('REFERRAL SCREEN'), findsOneWidget);
  });
}
