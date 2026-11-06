import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/notifications/presentation/push_providers.dart';
import '../features/realtime/presentation/rider_socket_providers.dart';
import '../features/shift/presentation/shift_controller.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class RiderApp extends ConsumerWidget {
  const RiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // App-wide listeners, alive from the start without rebuilding the app:
    // push token registration, push routing, and the shift (which notices
    // an auto-offline and restores "online" after a restart), and the rider
    // socket (live offers and task updates while online).
    ref
      ..listen(pushRegistrationControllerProvider, (_, _) {})
      ..listen(pushMessageHandlerProvider, (_, _) {})
      ..listen(shiftControllerProvider, (_, _) {})
      ..listen(riderSocketControllerProvider, (_, _) {});
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildRiderTheme(),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        JivoCoreLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
