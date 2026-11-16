import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/validation/validators.dart';
import '../../../shared/widgets/state_views.dart';
import '../../location/data/reverse_geocoder.dart';
import '../../location/domain/delivery_location.dart';
import '../../location/presentation/delivery_controller.dart';
import '../../location/presentation/location_flow.dart';
import '../../location/presentation/map_picker_screen.dart';
import '../../location/presentation/store_closed_banner.dart';
import '../data/device_location.dart';
import '../domain/saved_address.dart';
import 'address_controllers.dart';

String labelText(AppLocalizations l10n, SavedAddress address) =>
    address.customTitle ??
    switch (address.input.label) {
      AddressLabel.home => l10n.labelHome,
      AddressLabel.work => l10n.labelWork,
      AddressLabel.other => l10n.labelOther,
    };

/// Saved addresses: list, default badge, set default, edit, delete
/// (`03 §2.4`).
class AddressListScreen extends ConsumerWidget {
  const AddressListScreen({super.key});

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SavedAddress address,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteAddressConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      await _run(
        context,
        () => ref.read(addressListProvider.notifier).delete(address.id),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final addresses = ref.watch(addressListProvider);
    final add = FloatingActionButton.extended(
      onPressed: () => context.push(Routes.newAddress),
      icon: const Icon(Icons.add),
      label: Text(l10n.addAddress),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.addresses)),
      floatingActionButton: addresses.hasValue ? add : null,
      body: switch (addresses) {
        AsyncData(:final value) when value.isEmpty => EmptyView(
          message: l10n.addressesEmpty,
          icon: Icons.location_off_outlined,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.read(addressListProvider.notifier).reload(),
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final address = value[i];
              return ListTile(
                leading: Icon(switch (address.input.label) {
                  AddressLabel.home => Icons.home_outlined,
                  AddressLabel.work => Icons.work_outline,
                  AddressLabel.other => Icons.location_on_outlined,
                }),
                title: Row(
                  children: [
                    Flexible(child: Text(labelText(l10n, address))),
                    if (!address.isServiceable) ...[
                      const SizedBox(width: JivoSpacing.sm),
                      Chip(
                        label: Text(l10n.addressNotServiceable),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                    if (address.isDefault) ...[
                      const SizedBox(width: JivoSpacing.sm),
                      Chip(
                        label: Text(l10n.defaultAddress),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(address.summary),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => switch (action) {
                    'edit' => context.push(Routes.editAddress(address.id)),
                    'default' => _run(
                      context,
                      () => ref
                          .read(addressListProvider.notifier)
                          .setDefault(address.id),
                    ),
                    _ => _delete(context, ref, address),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                    if (!address.isDefault)
                      PopupMenuItem(
                        value: 'default',
                        child: Text(l10n.setAsDefault),
                      ),
                    PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                  ],
                ),
              );
            },
          ),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.read(addressListProvider.notifier).reload(),
        ),
        _ => const SkeletonList(),
      },
    );
  }
}

/// Add or edit an address (`03 §2.4`, CA-07). The pin comes first: the map
/// picker (where a map is available), the delivery location carried over
/// from "Save this location" ([initial]), the saved pin when editing, or,
/// without a map, the device location (only when at the address).
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({this.addressId, this.initial, super.key});

  final int? addressId;

  /// The delivery location to save ("Save this location"): its pin and
  /// address line. After saving, the new address becomes the delivery
  /// location.
  final DeliveryLocation? initial;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fields = {
    for (final f in [
      'custom',
      'house',
      'street',
      'landmark',
      'area',
      'city',
      'state',
      'pincode',
      'rname',
      'rphone',
    ])
      f: TextEditingController(),
  };
  AddressLabel _label = AddressLabel.home;
  bool _initialised = false;
  bool _pinError = false;
  final _pinKey = GlobalKey();
  late String _snapshot;

  /// What the geocoder put in each field; a field still holding it counts
  /// as "prefilled and untouched" (CA-07 section 5).
  final _prefilled = <String, String>{};

  String _formText() =>
      '$_label|${_fields.values.map((c) => c.text).join('|')}';

  SavedAddress? _existing() {
    final id = widget.addressId;
    if (id == null) return null;
    return ref
        .read(addressListProvider)
        .value
        ?.where((a) => a.id == id)
        .firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    final existing = _existing();
    if (existing != null) {
      final input = existing.input;
      _label = input.label;
      _fields['custom']!.text = input.customLabel ?? '';
      _fields['house']!.text = input.house;
      _fields['street']!.text = input.buildingStreet;
      _fields['landmark']!.text = input.landmark ?? '';
      _fields['area']!.text = input.area ?? '';
      _fields['city']!.text = input.city;
      _fields['state']!.text = input.state;
      _fields['pincode']!.text = input.pincode;
      _fields['rname']!.text = input.receiverName ?? '';
      _fields['rphone']!.text = Validators.localDigits(
        input.receiverPhone ?? '',
      );
    }
    _snapshot = _formText();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      final existing = _existing();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(addressFormProvider.notifier)
              .start(existing: existing, initial: widget.initial);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the empty fields from the geocoder; every field stays editable.
  void _prefill(AddressParts parts) {
    void fill(String key, String? value) {
      final field = _fields[key]!;
      if (value == null) return;
      final untouched =
          field.text.trim().isEmpty || _prefilled[key] == field.text;
      if (untouched) {
        field.text = value;
        _prefilled[key] = value;
      }
    }

    fill('area', parts.area);
    fill('city', parts.city);
    fill('state', parts.state);
    final pincode = parts.pincode;
    if (pincode != null && Validators.isPincode(pincode)) {
      fill('pincode', pincode);
    }
    // Prefilled text is not a change the customer made.
    _snapshot = _formText();
  }

  bool get _dirty {
    final point = ref.read(addressFormProvider).point;
    final newPin =
        widget.addressId == null && widget.initial == null && point != null;
    return _formText() != _snapshot || newPin;
  }

  Future<void> _confirmLeave() async {
    if (!_dirty) {
      context.pop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addressDiscardTitle),
        content: Text(l10n.addressDiscardBody),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.addressKeepEditing),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.addressDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  Widget _serviceLine(AppLocalizations l10n, AddressFormState state) {
    final theme = Theme.of(context);
    final result = state.serviceability;
    final IconData icon;
    final String text;
    Color? color;
    if (state.checking) {
      return Semantics(
        liveRegion: true,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: JivoSpacing.sm),
            Expanded(child: Text(l10n.addressServiceableChecking)),
          ],
        ),
      );
    }
    if (result == null) return const SizedBox.shrink();
    final store = result.store;
    if (!result.serviceable) {
      icon = Icons.wrong_location_outlined;
      text = l10n.addressServiceableNo;
      color = theme.colorScheme.error;
    } else if (store != null && !store.isOpen) {
      icon = Icons.schedule;
      text = l10n.addressServiceableClosed(
        storeClosedText(l10n, store.opensAt, now: DateTime.now()),
      );
    } else {
      icon = Icons.check_circle_outline;
      text = l10n.addressServiceableYes;
    }
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const Key('address-serviceability'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: JivoSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _pickOnMap(GeoPoint? at) async {
    final picked = await context.push<PickedLocation>(
      Routes.mapPicker,
      extra: MapPickerArgs(
        initial: at ?? ref.read(deliveryProvider).location?.point,
        fromAddressForm: true,
      ),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(addressFormProvider.notifier)
        .setPin(picked.point, line: picked.address);
  }

  Future<void> _save() async {
    if (ref.read(addressFormProvider).point == null) {
      setState(() => _pinError = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _pinKey.currentContext;
        if (target != null) Scrollable.ensureVisible(target);
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    String text(String key) => _fields[key]!.text.trim();
    final phoneDigits = text('rphone');
    final saved = await ref
        .read(addressFormProvider.notifier)
        .save(
          id: widget.addressId,
          build: (point) => AddressInput(
            label: _label,
            customLabel: text('custom'),
            house: text('house'),
            buildingStreet: text('street'),
            landmark: text('landmark'),
            area: text('area'),
            city: text('city'),
            state: text('state'),
            pincode: text('pincode'),
            receiverName: text('rname'),
            receiverPhone: phoneDigits.isEmpty
                ? null
                : Validators.toE164(phoneDigits),
            lat: point.lat,
            lng: point.lng,
          ),
        );
    if (saved == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    // "Save this location": deliver to the new address (serviceability is
    // checked again, and a store change still asks first).
    if (widget.initial != null) {
      await chooseDeliveryLocation(
        context,
        ref,
        DeliveryLocation(
          point: (lat: saved.input.lat, lng: saved.input.lng),
          title: labelText(l10n, saved),
          subtitle: saved.summary,
          addressId: saved.id,
        ),
      );
      if (!mounted) return;
    }
    _snapshot = _formText();
    showMessage(context, l10n.addressSaved);
    context.pop();
  }

  String _locationMessage(AppLocalizations l10n, LocationFailure failure) =>
      switch (failure) {
        LocationFailure.servicesOff => l10n.locationServicesOff,
        LocationFailure.denied => l10n.locationDenied,
        LocationFailure.deniedForever => l10n.locationDeniedForever,
        LocationFailure.unavailable => l10n.locationFailed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(addressFormProvider);
    final point = state.point;
    final hasMap = ref.watch(mapsAvailableProvider).value ?? false;
    ref.listen(addressFormProvider.select((s) => s.parts), (_, parts) {
      if (parts != null) _prefill(parts);
    });
    final locateIcon = state.locating
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.my_location);
    String? required(String? value) =>
        (value ?? '').trim().isEmpty ? l10n.fieldRequired : null;

    Widget field(
      String key,
      String label, {
      String? Function(String?)? validator,
      TextInputType? keyboard,
      List<TextInputFormatter>? formatters,
      int? maxLength,
      String? prefix,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: JivoSpacing.md),
      child: TextFormField(
        key: Key('address-$key'),
        controller: _fields[key],
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLength: maxLength,
        textCapitalization: keyboard == null
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          prefixText: prefix,
        ),
        validator: validator,
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.addressId == null ? l10n.newAddress : l10n.editAddress,
          ),
        ),
        // A Column (not a lazy ListView) so every field is built and validated.
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(JivoSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.locationTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: JivoSpacing.sm),
                if (point != null)
                  Card(
                    key: const Key('address-pin'),
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(
                        Icons.location_on,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        state.pinLine ?? l10n.locationCaptured,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        l10n.pinCoordinates(
                          formatCoordinate(point.lat),
                          formatCoordinate(point.lng),
                        ),
                      ),
                    ),
                  )
                else if (!hasMap)
                  Text(l10n.locationNeeded),
                if (_pinError && point == null)
                  Card(
                    key: _pinKey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      ),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: ListTile(
                        leading: Icon(
                          Icons.error,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          hasMap ? l10n.pinNeededMap : l10n.pinNeededNoMap,
                        ),
                      ),
                    ),
                  ),
                if (point != null) ...[
                  const SizedBox(height: JivoSpacing.sm),
                  _serviceLine(l10n, state),
                ],
                if (state.locationFailure != null) ...[
                  const SizedBox(height: JivoSpacing.sm),
                  Text(
                    _locationMessage(l10n, state.locationFailure!),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  if (state.locationFailure != LocationFailure.unavailable)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => ref
                            .read(addressFormProvider.notifier)
                            .openSettings(),
                        child: Text(l10n.openSettings),
                      ),
                    ),
                ],
                const SizedBox(height: JivoSpacing.sm),
                if (hasMap && point == null)
                  FilledButton.icon(
                    key: const Key('address-set-on-map'),
                    onPressed: () => _pickOnMap(null),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(l10n.setLocationOnMap),
                  )
                else if (hasMap)
                  OutlinedButton.icon(
                    key: const Key('address-adjust-pin'),
                    onPressed: () => _pickOnMap(point),
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: Text(l10n.adjustPin),
                  ),
                if (hasMap)
                  TextButton.icon(
                    onPressed: state.locating
                        ? null
                        : () => ref.read(addressFormProvider.notifier).locate(),
                    icon: locateIcon,
                    label: Text(l10n.useCurrentLocation),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: state.locating
                        ? null
                        : () => ref.read(addressFormProvider.notifier).locate(),
                    icon: locateIcon,
                    label: Text(l10n.useCurrentLocation),
                  ),
                  const SizedBox(height: JivoSpacing.xs),
                  Text(
                    l10n.gpsOnlyAtAddress,
                    key: const Key('address-gps-warning'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: JivoSpacing.xl),
                Wrap(
                  spacing: JivoSpacing.sm,
                  children: [
                    for (final (label, text) in [
                      (AddressLabel.home, l10n.labelHome),
                      (AddressLabel.work, l10n.labelWork),
                      (AddressLabel.other, l10n.labelOther),
                    ])
                      ChoiceChip(
                        label: Text(text),
                        selected: _label == label,
                        onSelected: (_) => setState(() => _label = label),
                      ),
                  ],
                ),
                const SizedBox(height: JivoSpacing.md),
                field('custom', l10n.customLabel, maxLength: 40),
                field(
                  'house',
                  l10n.houseLabel,
                  validator: required,
                  maxLength: 120,
                ),
                field(
                  'street',
                  l10n.buildingStreetLabel,
                  validator: required,
                  maxLength: 200,
                ),
                field('landmark', l10n.landmarkLabel, maxLength: 120),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    for (final k in ['area', 'city', 'state', 'pincode'])
                      _fields[k]!,
                  ]),
                  builder: (context, _) {
                    final show = _prefilled.entries.any(
                      (e) =>
                          e.value.isNotEmpty && _fields[e.key]!.text == e.value,
                    );
                    if (!show) return const SizedBox.shrink();
                    return Padding(
                      key: const Key('address-prefill-note'),
                      padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_fix_high, size: 16),
                          const SizedBox(width: JivoSpacing.xs),
                          Expanded(
                            child: Text(
                              l10n.addressPrefillNote,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                field('area', l10n.areaLabel, maxLength: 120),
                field(
                  'city',
                  l10n.cityLabel,
                  validator: required,
                  maxLength: 80,
                ),
                field(
                  'state',
                  l10n.stateLabel,
                  validator: required,
                  maxLength: 80,
                ),
                field(
                  'pincode',
                  l10n.pincodeLabel,
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  validator: (v) => Validators.isPincode(v ?? '')
                      ? null
                      : l10n.pincodeInvalid,
                ),
                field('rname', l10n.receiverNameLabel, maxLength: 120),
                field(
                  'rphone',
                  l10n.receiverPhoneLabel,
                  keyboard: TextInputType.phone,
                  prefix: '+91 ',
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) => (v ?? '').isEmpty || Validators.isMobile(v!)
                      ? null
                      : l10n.phoneInvalid,
                ),
                if (state.error != null) ...[
                  Text(
                    describeErrorWithDetails(context, state.error!),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: JivoSpacing.md),
                ],
                if (point == null) ...[
                  Text(
                    hasMap ? l10n.pinNeededMap : l10n.pinNeededNoMap,
                    key: const Key('address-pin-needed'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: JivoSpacing.sm),
                ],
                BusyButton(
                  label: l10n.save,
                  busy: state.saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
