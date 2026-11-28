import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/validation/validators.dart';
import '../../../shared/widgets/state_views.dart';
import 'profile_controllers.dart';

/// Name (required) and email (optional), shared by complete-profile and
/// edit profile. Calls [onSaved] after a successful save.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    required this.buttonLabel,
    this.initialName = '',
    this.initialEmail,
    this.emailLocked = false,
    this.onSaved,
    super.key,
  });

  static const nameFieldKey = Key('profile-name');
  static const emailFieldKey = Key('profile-email');

  final String buttonLabel;
  final String initialName;
  final String? initialEmail;

  /// The email is the account's only sign-in (no phone): shown read-only;
  /// the server refuses changing or clearing it.
  final bool emailLocked;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _email = TextEditingController(text: widget.initialEmail ?? '');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(profileFormProvider.notifier)
        .save(name: _name.text, email: _email.text);
    if (ok) widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileFormProvider);
    final generalError = state.error != null && !state.emailRejected
        ? describeErrorWithDetails(context, state.error!)
        : null;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: ProfileForm.nameFieldKey,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            maxLength: 120,
            decoration: InputDecoration(
              labelText: l10n.nameLabel,
              counterText: '',
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? l10n.nameRequired : null,
          ),
          const SizedBox(height: JivoSpacing.lg),
          TextFormField(
            key: ProfileForm.emailFieldKey,
            controller: _email,
            readOnly: widget.emailLocked,
            enabled: !widget.emailLocked,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: widget.emailLocked
                  ? l10n.emailAddressLabel
                  : l10n.emailLabel,
              helperText: widget.emailLocked
                  ? l10n.emailSignInNotEditable
                  : null,
              helperMaxLines: 2,
              errorText: state.emailRejected ? l10n.emailCantBeUsed : null,
            ),
            validator: (value) {
              final email = (value ?? '').trim();
              return email.isEmpty || Validators.isEmail(email)
                  ? null
                  : l10n.emailInvalid;
            },
          ),
          if (generalError != null) ...[
            const SizedBox(height: JivoSpacing.md),
            Text(
              generalError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: JivoSpacing.xl),
          BusyButton(
            label: widget.buttonLabel,
            busy: state.saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
