import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/map/rider_map.dart';
import '../domain/rider_task.dart';
import '../domain/task_navigation.dart';
import 'navigation_panel.dart';

/// Which place a task step's small map is about.
enum TaskMapTarget { store, customer }

/// The small, hideable map on the task steps without the navigation card
/// (at the store, at the customer, returning): the rider's blue dot and
/// the store or drop pin. It uses the server's `navigation` route when the
/// leg matches, and otherwise a dashed straight line from the rider (the
/// server sends no `navigation` while RETURNING; api-requests gap).
///
/// Nothing without a Maps key, so the step looks as before.
class TaskMapSection extends StatelessWidget {
  const TaskMapSection({
    required this.task,
    required this.target,
    required this.section,
    super.key,
  });

  final RiderTask task;
  final TaskMapTarget target;

  /// Key suffix: `map-<section>`.
  final String section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RiderMapSection(
      section: section,
      title: switch (target) {
        TaskMapTarget.store => l10n.mapTitleStore(task.store.name),
        TaskMapTarget.customer => l10n.mapTitleCustomer,
      },
      spec: (_) => taskMapSpec(task, target),
    );
  }
}

/// The spec for [task]'s small map, or null when the place is unknown
/// (the drop is hidden again after the task ended).
RiderMapSpec? taskMapSpec(RiderTask task, TaskMapTarget target) {
  final navigation = task.navigation;
  final leg = target == TaskMapTarget.store
      ? NavigationLeg.toStore
      : NavigationLeg.toCustomer;
  if (navigation != null && navigation.leg == leg) {
    return navigationMapSpec(navigation);
  }
  final GeoPoint? point = switch (target) {
    TaskMapTarget.store => task.store.location,
    TaskMapTarget.customer => task.customer?.location,
  };
  if (point == null) return null;
  return RiderMapSpec(
    pins: [
      MapPin(
        target == TaskMapTarget.store ? MapPinKind.store : MapPinKind.customer,
        point,
      ),
    ],
    lineFromRider: true,
    followKey: target,
  );
}
