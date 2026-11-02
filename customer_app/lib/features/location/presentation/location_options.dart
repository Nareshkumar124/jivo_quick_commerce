import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../addresses/data/device_location.dart';
import '../../addresses/presentation/address_controllers.dart';
import '../../addresses/presentation/address_screens.dart' show labelText;
import '../domain/delivery_location.dart';
import 'delivery_controller.dart';
import 'location_flow.dart';
import 'map_picker_screen.dart';

/// The ways to pick a delivery location: detect, map, saved addresses, add
/// one. Used by the location screen and the home address switcher.
/// [onChosen] runs after a location was selected.
class LocationOptions extends ConsumerStatefulWidget {
  const LocationOptions({required this.onChosen, super.key});

  final VoidCallback onChosen;

  @override
  ConsumerState<LocationOptions> createState() => _LocationOptionsState();
}

class _LocationOptionsState extends ConsumerState<LocationOptions> {
  bool _busy = false;
  LocationFailure? _failure;

  Future<void> _choose(DeliveryLocation location) async {
    setState(() => _busy = true);
    final chosen = await chooseDeliveryLocation(
      context,
      ref,
      location,
      onChecked: () {
        if (mounted) setState(() => _busy = false);
      },
    );
    if (mounted && chosen) widget.onChosen();
  }

  Future<void> _detect() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _failure = null;
    });
    final GeoPoint point;
    try {
      point = await ref.read(deviceLocationProvider).current();
    } on LocationException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = e.reason;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    // With a map, let the customer fine-tune the pin; without, use the fix.
    final hasMap = await ref.read(mapsAvailableProvider.future);
    if (!mounted) return;
    if (hasMap) {
      await _pickOnMap(initial: point);
    } else {
      await _choose(
        DeliveryLocation(point: point, title: l10n.currentLocationTitle),
      );
    }
  }

  Future<void> _pickOnMap({GeoPoint? initial}) async {
    final l10n = AppLocalizations.of(context);
    final picked = await context.push<PickedLocation>(
      Routes.mapPicker,
      extra: initial,
    );
    if (picked == null || !mounted) return;
    await _choose(
      DeliveryLocation(
        point: picked.point,
        title: l10n.pinnedLocationTitle,
        subtitle: picked.address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final addresses = ref.watch(addressListProvider);
    final current = ref.watch(deliveryProvider.select((s) => s.location));
    final failure = _failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(),
        ListTile(
          key: const Key('detect-location'),
          enabled: !_busy,
          leading: Icon(Icons.my_location, color: theme.colorScheme.primary),
          title: Text(
            l10n.detectLocation,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: _detect,
        ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
            child: Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(JivoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        locationFailureText(l10n, failure),
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    Wrap(
                      children: [
                        if (failure != LocationFailure.unavailable)
                          TextButton(
                            onPressed: () => ref
                                .read(deviceLocationProvider)
                                .openSettings(failure),
                            child: Text(l10n.openSettings),
                          ),
                        TextButton(onPressed: _detect, child: Text(l10n.retry)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ListTile(
          key: const Key('pick-on-map'),
          enabled: !_busy,
          leading: const Icon(Icons.map_outlined),
          title: Text(l10n.pickOnMap),
          onTap: () => _pickOnMap(initial: current?.point),
        ),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.add),
          title: Text(l10n.addAddress),
          onTap: () => context.push(Routes.newAddress),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            JivoSpacing.gutter,
            JivoSpacing.sm,
            JivoSpacing.gutter,
            JivoSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(l10n.addresses, style: theme.textTheme.titleSmall),
          ),
        ),
        switch (addresses) {
          AsyncData(:final value) when value.isEmpty => Padding(
            padding: const EdgeInsets.all(JivoSpacing.gutter),
            child: Text(l10n.addressesEmpty),
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final address in value)
                ListTile(
                  key: ValueKey('choose-address-${address.id}'),
                  enabled: !_busy,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(labelText(l10n, address)),
                  subtitle: Text(
                    address.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: current?.addressId == address.id
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () => _choose(
                    DeliveryLocation(
                      point: (lat: address.input.lat, lng: address.input.lng),
                      title: labelText(l10n, address),
                      subtitle: address.summary,
                      addressId: address.id,
                    ),
                  ),
                ),
            ],
          ),
          AsyncError(:final error) => ListTile(
            title: Text(describeError(context, error)),
            trailing: TextButton(
              onPressed: () => ref.invalidate(addressListProvider),
              child: Text(l10n.retry),
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.all(JivoSpacing.gutter),
            child: SkeletonSemantics(
              child: Column(
                children: [
                  SkeletonBox(height: 48, width: double.infinity),
                  SizedBox(height: JivoSpacing.sm),
                  SkeletonBox(height: 48, width: double.infinity),
                ],
              ),
            ),
          ),
        },
      ],
    );
  }
}

/// The address switcher, opened from the home header (`03 §2.3`).
Future<void> showAddressSwitcher(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JivoSpacing.gutter,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  AppLocalizations.of(context).selectLocation,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            LocationOptions(onChosen: () => Navigator.pop(sheetContext)),
          ],
        ),
      ),
    );
