import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../../shared/widgets/sensitive_number_field.dart';
import '../domain/masking.dart';
import '../domain/onboarding_forms.dart';
import '../domain/rider_profile.dart';
import '../domain/validators.dart';
import 'onboarding_controllers.dart';
import 'onboarding_providers.dart';
import 'onboarding_text.dart';

/// Bank details (04 §2.2, screen 5) for payouts: account holder, account
/// number twice (masked once typed, no paste in the confirm field), IFSC and
/// an optional UPI ID. `PUT /rider/bank-account/`. Saved details come back
/// masked.
class BankDetailsScreen extends ConsumerStatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _confirm = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  Map<BankField, FieldError> _errors = const {};

  @override
  void initState() {
    super.initState();
    final profile = ref.read(riderProfileControllerProvider).value;
    _holder.text = profile?.bankAccount?.holderName ?? profile?.fullName ?? '';
  }

  @override
  void dispose() {
    for (final c in [_holder, _account, _confirm, _ifsc, _upi]) {
      c.dispose();
    }
    super.dispose();
  }

  void _clear(BankField field) {
    ref.read(bankDetailsControllerProvider.notifier).clearError();
    if (_errors.containsKey(field)) {
      setState(() => _errors = Map.of(_errors)..remove(field));
    }
  }

  String? _error(AppLocalizations l10n, BankField field) {
    final error = _errors[field];
    return error == null ? null : fieldErrorText(l10n, error);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final draft = BankAccountDraft(
      holderName: _holder.text,
      accountNumber: _account.text,
      confirmAccountNumber: _confirm.text,
      ifsc: _ifsc.text,
      upiId: _upi.text,
    );
    final errors = draft.validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final saved = await ref
        .read(bankDetailsControllerProvider.notifier)
        .save(draft.toInput());
    if (!saved || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.bankSavedToast)));
    // Back to the status screen; a reload picks up a status change.
    final reload = ref.read(riderProfileControllerProvider.notifier).reload();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.riderStatus);
    }
    await reload;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(bankDetailsControllerProvider);
    final profile = ref.watch(riderProfileControllerProvider).value;
    final saved = profile?.bankAccount;
    final firstTime = profile?.stage == OnboardingStage.needsBankAccount;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bankTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('bank-form'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (firstTime) ...[
                  Text(
                    l10n.onboardingStepOf(3, 3),
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(l10n.bankIntro, style: theme.textTheme.bodyLarge),
                if (saved != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    key: const Key('bank-saved'),
                    child: ListTile(
                      leading: const Icon(Icons.account_balance, size: 32),
                      title: Text(
                        l10n.bankSaved(saved.accountNumberMasked, saved.ifsc),
                      ),
                      subtitle: Text(l10n.bankReplaceHint),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const Key('bank-holder'),
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.bankHolderName,
                    errorText: _error(l10n, BankField.holderName),
                  ),
                  onChanged: (_) => _clear(BankField.holderName),
                ),
                const SizedBox(height: 16),
                SensitiveNumberField(
                  fieldKey: const Key('bank-account'),
                  controller: _account,
                  label: l10n.bankAccountNumber,
                  masked: Masking.accountNumber,
                  maskedHelper: l10n.numberMaskedHelper,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(18),
                  ],
                  errorText: _error(l10n, BankField.accountNumber),
                  onChanged: (_) => _clear(BankField.accountNumber),
                ),
                const SizedBox(height: 16),
                SensitiveNumberField(
                  fieldKey: const Key('bank-account-confirm'),
                  controller: _confirm,
                  label: l10n.bankConfirmAccountNumber,
                  masked: Masking.accountNumber,
                  maskedHelper: l10n.numberMaskedHelper,
                  allowPaste: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(18),
                  ],
                  errorText: _error(l10n, BankField.confirmAccountNumber),
                  onChanged: (_) => _clear(BankField.confirmAccountNumber),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('bank-ifsc'),
                  controller: _ifsc,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    const UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.bankIfsc,
                    hintText: l10n.bankIfscHint,
                    errorText: _error(l10n, BankField.ifsc),
                  ),
                  onChanged: (_) => _clear(BankField.ifsc),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('bank-upi'),
                  controller: _upi,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.bankUpi,
                    hintText: l10n.bankUpiHint,
                    errorText: _error(l10n, BankField.upiId),
                  ),
                  onChanged: (_) => _clear(BankField.upiId),
                ),
              ],
            ),
          ),
          PrimaryActionBar(
            buttonKey: const Key('bank-save'),
            label: l10n.bankSave,
            busy: state.submitting,
            onPressed: _save,
            errorKey: const Key('bank-error'),
            error: state.error == null
                ? null
                : onboardingErrorText(context, state.error!),
          ),
        ],
      ),
    );
  }
}
