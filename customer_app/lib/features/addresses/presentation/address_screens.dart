import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/validation/validators.dart';
import '../../../shared/widgets/state_views.dart';
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

/// Add or edit an address. No map in Phase 1: the pin is the device
/// location, captured with a permission flow (`03 §2.4`).
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({this.addressId, super.key});

  final int? addressId;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      final existing = _existing();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(addressFormProvider.notifier).initFrom(existing);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    String text(String key) => _fields[key]!.text.trim();
    final phoneDigits = text('rphone');
    final ok = await ref
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
    if (ok && mounted) {
      showMessage(context, AppLocalizations.of(context).addressSaved);
      context.pop();
    }
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

    return Scaffold(
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
              Text(l10n.locationTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: JivoSpacing.sm),
              if (state.point != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.check_circle,
                    color: context.jivoColors.success,
                  ),
                  title: Text(l10n.locationCaptured),
                )
              else
                Text(l10n.locationNeeded),
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
                      onPressed: () =>
                          ref.read(addressFormProvider.notifier).openSettings(),
                      child: Text(l10n.openSettings),
                    ),
                  ),
              ],
              const SizedBox(height: JivoSpacing.sm),
              OutlinedButton.icon(
                onPressed: state.locating
                    ? null
                    : () => ref.read(addressFormProvider.notifier).locate(),
                icon: state.locating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(l10n.useCurrentLocation),
              ),
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
              field('area', l10n.areaLabel, maxLength: 120),
              field('city', l10n.cityLabel, validator: required, maxLength: 80),
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
                validator: (v) =>
                    Validators.isPincode(v ?? '') ? null : l10n.pincodeInvalid,
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
              BusyButton(
                label: l10n.save,
                busy: state.saving,
                onPressed: state.point == null ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
