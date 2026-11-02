import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../addresses/data/device_location.dart';
import '../domain/delivery_location.dart';
import 'delivery_controller.dart';

/// Arguments of the not-serviceable screen.
class NotServiceableArgs {
  const NotServiceableArgs({required this.location, this.serviceability});

  final DeliveryLocation location;
  final Serviceability? serviceability;
}

/// Switches the delivery location to [location] (`03 §2.3`):
/// - not serviceable: opens the not-serviceable screen;
/// - a different store with items in the cart: asks before clearing it;
/// - otherwise selects it.
///
/// [onChecked] runs once the network check is done (before any dialog or
/// screen), so callers can stop their progress indicator.
///
/// Returns true when the location was selected.
Future<bool> chooseDeliveryLocation(
  BuildContext context,
  WidgetRef ref,
  DeliveryLocation location, {
  VoidCallback? onChecked,
}) async {
  final controller = ref.read(deliveryProvider.notifier);
  final LocationCheck check;
  try {
    check = await controller.check(location);
  } catch (error) {
    onChecked?.call();
    if (context.mounted) {
      showMessage(context, describeErrorWithDetails(context, error));
    }
    return false;
  }
  onChecked?.call();
  if (!context.mounted) return false;

  switch (check.outcome) {
    case LocationOutcome.notServiceable:
      await context.push(
        Routes.notServiceable,
        extra: NotServiceableArgs(
          location: location,
          serviceability: check.serviceability,
        ),
      );
      return false;
    case LocationOutcome.storeChange:
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.storeChangeTitle),
          content: Text(l10n.storeChangeBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.storeChangeConfirm),
            ),
          ],
        ),
      );
      if (!(confirmed ?? false)) return false;
      await controller.select(location, check.serviceability, clearCart: true);
      return true;
    case LocationOutcome.ok:
      await controller.select(location, check.serviceability);
      return true;
  }
}

/// The message for a location failure (Phase 1 strings).
String locationFailureText(AppLocalizations l10n, LocationFailure failure) =>
    switch (failure) {
      LocationFailure.servicesOff => l10n.locationServicesOff,
      LocationFailure.denied => l10n.locationDenied,
      LocationFailure.deniedForever => l10n.locationDeniedForever,
      LocationFailure.unavailable => l10n.locationFailed,
    };

/// Coordinates for display, 5 decimals (about 1 m).
String formatCoordinate(double value) => value.toStringAsFixed(5);
