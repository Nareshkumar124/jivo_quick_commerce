import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../../shared/widgets/sensitive_number_field.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/logout_button.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../domain/onboarding_forms.dart';
import '../domain/validators.dart';
import '../domain/vehicle_type.dart';
import 'onboarding_controllers.dart';
import 'onboarding_providers.dart';
import 'onboarding_text.dart';

/// Registration form (04 §2.2, screen 3) for `rider_status: NONE`: name,
/// date of birth (18+), emergency contact, preferred store, vehicle type and
/// (motorised only) vehicle number. Submits `POST /rider/register/`; the
/// router then opens the status screen with the next step.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _name = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyPhone = TextEditingController();
  final _vehicleNumber = TextEditingController();
  DateTime? _dob;
  int? _storeId;
  VehicleType? _vehicle;

  /// Shown only after the rider tried to continue; cleared per field as
  /// they fix it.
  Map<RegistrationField, FieldError> _errors = const {};

  @override
  void initState() {
    super.initState();
    final account = ref.read(riderAccountControllerProvider);
    if (account is AccountLoaded) _name.text = account.user.name.trim();
  }

  @override
  void dispose() {
    _name.dispose();
    _emergencyName.dispose();
    _emergencyPhone.dispose();
    _vehicleNumber.dispose();
    super.dispose();
  }

  DateTime get _today => istToday(ref.read(clockProvider)());

  RegistrationDraft get _draft => RegistrationDraft(
    fullName: _name.text,
    dateOfBirth: _dob,
    emergencyName: _emergencyName.text,
    emergencyPhone: _emergencyPhone.text,
    storeId: _storeId,
    vehicleType: _vehicle,
    vehicleNumber: _vehicleNumber.text,
  );

  void _clear(RegistrationField field) {
    ref.read(registrationControllerProvider.notifier).clearError();
    if (_errors.containsKey(field)) {
      setState(() => _errors = Map.of(_errors)..remove(field));
    }
  }

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final latest = latestAllowedDateOfBirth(_today);
    final last = DateTime(latest.year, latest.month, latest.day);
    final current = _dob;
    final initial = current == null
        ? last
        : DateTime(current.year, current.month, current.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: DateTime(1940),
      lastDate: last,
      initialDatePickerMode: DatePickerMode.year,
      helpText: AppLocalizations.of(context).registerDobPickerHelp,
    );
    if (picked == null || !mounted) return;
    setState(() => _dob = dateOnly(picked));
    _clear(RegistrationField.dateOfBirth);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final account = ref.read(riderAccountControllerProvider);
    final draft = _draft;
    final errors = draft.validate(
      today: _today,
      riderPhoneE164: account is AccountLoaded ? account.user.phone : null,
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    await ref
        .read(registrationControllerProvider.notifier)
        .submit(draft.toRegistration());
  }

  String? _error(AppLocalizations l10n, RegistrationField field) {
    final error = _errors[field];
    return error == null ? null : fieldErrorText(l10n, error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(registrationControllerProvider);
    final serverError = state.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.registerTitle),
        actions: const [LogoutButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('register-form'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  l10n.onboardingStepOf(1, 3),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(l10n.registerIntro, style: theme.textTheme.bodyLarge),
                _SectionTitle(l10n.registerSectionAboutYou),
                TextField(
                  key: const Key('register-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: l10n.registerFullName,
                    errorText: _error(l10n, RegistrationField.fullName),
                  ),
                  onChanged: (_) => _clear(RegistrationField.fullName),
                ),
                const SizedBox(height: 16),
                _DateOfBirthField(
                  value: _dob,
                  errorText: _error(l10n, RegistrationField.dateOfBirth),
                  onTap: _pickDob,
                ),
                _SectionTitle(l10n.registerSectionEmergency),
                Text(l10n.registerEmergencyHelp),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('register-emergency-name'),
                  controller: _emergencyName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.registerEmergencyName,
                    errorText: _error(l10n, RegistrationField.emergencyName),
                  ),
                  onChanged: (_) => _clear(RegistrationField.emergencyName),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('register-emergency-phone'),
                  controller: _emergencyPhone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.registerEmergencyPhone,
                    hintText: l10n.loginPhoneHint,
                    prefixText: '+91 ',
                    errorText: _error(l10n, RegistrationField.emergencyPhone),
                  ),
                  onChanged: (_) => _clear(RegistrationField.emergencyPhone),
                ),
                _SectionTitle(l10n.registerSectionStore),
                _StoreField(
                  value: _storeId,
                  errorText: _error(l10n, RegistrationField.store),
                  onChanged: (id) {
                    setState(() => _storeId = id);
                    _clear(RegistrationField.store);
                  },
                ),
                _SectionTitle(l10n.registerSectionVehicle),
                _VehicleChoice(
                  value: _vehicle,
                  errorText: _error(l10n, RegistrationField.vehicleType),
                  onChanged: (type) {
                    setState(() => _vehicle = type);
                    _clear(RegistrationField.vehicleType);
                    _clear(RegistrationField.vehicleNumber);
                  },
                ),
                if (_vehicle?.isMotorised ?? false) ...[
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('register-vehicle-number'),
                    controller: _vehicleNumber,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      const UpperCaseTextFormatter(),
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 ]')),
                      LengthLimitingTextInputFormatter(14),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.registerVehicleNumber,
                      hintText: l10n.registerVehicleNumberHint,
                      errorText: _error(l10n, RegistrationField.vehicleNumber),
                    ),
                    onChanged: (_) => _clear(RegistrationField.vehicleNumber),
                  ),
                ],
              ],
            ),
          ),
          PrimaryActionBar(
            buttonKey: const Key('register-submit'),
            label: l10n.registerSubmit,
            busy: state.submitting,
            onPressed: _submit,
            errorKey: const Key('register-error'),
            error: serverError == null
                ? null
                : onboardingErrorText(context, serverError),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// Opens the date picker (no typing). Shows the chosen date.
class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({
    required this.value,
    required this.errorText,
    required this.onTap,
  });

  final DateTime? value;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = value;
    return InkWell(
      key: const Key('register-dob'),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: date == null,
        decoration: InputDecoration(
          labelText: l10n.registerDob,
          hintText: l10n.registerDobHint,
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_month),
        ),
        child: date == null
            ? null
            : Text(
                DateFormat.yMMMd(locale).format(date),
                style: Theme.of(context).textTheme.titleMedium,
              ),
      ),
    );
  }
}

/// Preferred home store, from the store list (loading and error states).
class _StoreField extends ConsumerWidget {
  const _StoreField({
    required this.value,
    required this.errorText,
    required this.onChanged,
  });

  final int? value;
  final String? errorText;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final stores = ref.watch(storeOptionsProvider);
    return switch (stores) {
      AsyncData(:final value) => DropdownButtonFormField<int>(
        key: const Key('register-store'),
        initialValue: this.value,
        isExpanded: true,
        itemHeight: 56,
        decoration: InputDecoration(
          labelText: l10n.registerStoreLabel,
          helperText: l10n.registerStoreHelp,
          helperMaxLines: 2,
          errorText: errorText,
        ),
        items: [
          for (final store in value)
            DropdownMenuItem(
              value: store.id,
              child: Text(
                l10n.registerStoreOption(store.name, store.city),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
      AsyncError() => Row(
        children: [
          Expanded(
            child: Text(
              l10n.registerStoresError,
              key: const Key('register-stores-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          OutlinedButton(
            key: const Key('register-stores-retry'),
            onPressed: () => ref.invalidate(storeOptionsProvider),
            child: Text(l10n.retry),
          ),
        ],
      ),
      _ => Row(
        children: [
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 12),
          Text(l10n.registerStoresLoading),
        ],
      ),
    };
  }
}

/// Four large tiles (no typing): bicycle, e-bike, motorbike, scooter.
class _VehicleChoice extends StatelessWidget {
  const _VehicleChoice({
    required this.value,
    required this.errorText,
    required this.onChanged,
  });

  final VehicleType? value;
  final String? errorText;
  final ValueChanged<VehicleType> onChanged;

  static IconData _icon(VehicleType type) => switch (type) {
    VehicleType.bicycle => Icons.pedal_bike,
    VehicleType.eBike => Icons.electric_bike,
    VehicleType.motorbike => Icons.two_wheeler,
    VehicleType.scooter => Icons.moped,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget tile(VehicleType type) {
      final selected = type == value;
      final color = selected
          ? theme.colorScheme.primary
          : theme.colorScheme.outline;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Semantics(
            selected: selected,
            button: true,
            child: InkWell(
              key: Key('register-vehicle-${type.wireValue}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(type),
              child: Container(
                constraints: const BoxConstraints(minHeight: 88),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: selected ? 3 : 1),
                  color: selected ? theme.colorScheme.primaryContainer : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icon(type), size: 36, color: color),
                    const SizedBox(height: 4),
                    Text(
                      vehicleName(l10n, type),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [tile(VehicleType.bicycle), tile(VehicleType.eBike)]),
        Row(children: [tile(VehicleType.motorbike), tile(VehicleType.scooter)]),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
