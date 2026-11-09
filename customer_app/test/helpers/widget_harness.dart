import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/tracking/data/order_socket.dart';
import 'package:customer_app/features/tracking/presentation/order_live.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

/// One widget inside the app's theme and localisations, without the router.
///
/// The cart is available (dev flavor) unless [cartAvailable] is false.
Widget harness(
  Widget child, {
  List<Override> overrides = const [],
  TextScaler textScaler = TextScaler.noScaling,
  bool cartAvailable = true,
  OrderRealtime realtime = const DisabledOrderRealtime(),
}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    cartAvailableProvider.overrideWithValue(cartAvailable),
    orderRealtimeProvider.overrideWithValue(realtime),
    ...overrides,
  ],
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
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(body: child),
  ),
);
