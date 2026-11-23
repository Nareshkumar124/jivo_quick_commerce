import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/map/rider_map.dart';
import '../../task/presentation/task_flow_controller.dart';
import 'home_providers.dart';
import 'shift_controller.dart';

/// Home while online with no task: a small map with the rider's blue dot
/// and the home store (`home_store.lat/lng` of `GET /rider/me/`). Nothing
/// offline (no location is read then), with a task, without a Maps key or
/// without the store's position.
class HomeAreaMap extends ConsumerWidget {
  const HomeAreaMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(shiftControllerProvider.select((s) => s.isOnline));
    final hasTask = ref.watch(
      taskFlowControllerProvider.select((s) => s.task != null),
    );
    if (!online || hasTask) return const SizedBox.shrink();
    return RiderMapSection(
      section: 'home',
      title: AppLocalizations.of(context).mapTitleHome,
      spec: (ref) {
        final store = ref.watch(todaySummaryProvider).value?.homeStoreLocation;
        if (store == null) return null;
        return RiderMapSpec(
          pins: [MapPin(MapPinKind.store, store)],
          followKey: 'home',
        );
      },
    );
  }
}
