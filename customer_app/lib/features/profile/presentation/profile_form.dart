import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/validation/validators.dart';
import '../../../shared/widgets/state_views.dart';
import 'business_category_field.dart';
import 'profile_controllers.dart';

/// Edit profile: name (required), email, business category and business
/// name (optional). Calls [onSaved] after a successful save. (The
/// complete-profile screen has its own form, `03 §2.2`.)
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    required this.buttonLabel,
    this.initialName = '',
    this.initialEmail,
    this.initialBusinessCategoryId,
    this.initialBusinessCategoryName,
    this.initialBusinessName = '',
    this.onSaved,
    super.key,
  });

  static const nameFieldKey = Key('profile-name');
  static const emailFieldKey = Key('profile-email');
  static const businessNameFieldKey = Key('profile-business-name');

  final String buttonLabel;
  final String initialName;
  final String? initialEmail;
  final int? initialBusinessCategoryId;
  final String? initialBusinessCategoryName;
  final String initialBusinessName;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  late final _businessName = TextEditingController(
    text: widget.initialBusinessName,
  );
  late int? _categoryId = widget.initialBusinessCategoryId;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _businessName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(profileFormProvider.notifier)
        .save(
          name: _name.text,
          email: _email.text,
          // Only a changed category is sent; the generated client can't send
          // null, so a saved category can be changed but not removed here.
          businessCategoryId: _categoryId == widget.initialBusinessCategoryId
              ? null
              : _categoryId,
          businessName: _businessName.text,
        );
    if (ok) widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileFormProvider);
    final generalError = state.error != null && !state.hasFieldError
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
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: l10n.emailLabel,
              errorText: state.emailRejected ? l10n.emailCantBeUsed : null,
            ),
            validator: (value) {
              final email = (value ?? '').trim();
              return email.isEmpty || Validators.isEmail(email)
                  ? null
                  : l10n.emailInvalid;
            },
          ),
          const SizedBox(height: JivoSpacing.lg),
          BusinessCategoryField(
            value: _categoryId,
            currentName: widget.initialBusinessCategoryName,
            errorText: state.categoryRejected
                ? l10n.businessCategoryInvalid
                : null,
            onChanged: (id) => setState(() => _categoryId = id),
          ),
          const SizedBox(height: JivoSpacing.lg),
          TextFormField(
            key: ProfileForm.businessNameFieldKey,
            controller: _businessName,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.organizationName],
            maxLength: 120,
            decoration: InputDecoration(
              labelText: l10n.businessNameLabel,
              counterText: '',
            ),
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
