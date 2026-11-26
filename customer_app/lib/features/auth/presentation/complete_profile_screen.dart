import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../profile/presentation/business_category_field.dart';
import '../../profile/presentation/profile_form.dart';
import 'complete_profile_controller.dart';

/// Shown once after the first sign-up, while the server reports
/// `is_profile_complete: false` (`03 §2.2`): Name (required to submit),
/// Business category and Business name (optional), with Skip and Submit.
/// Either button completes the profile on the server and the router moves
/// on to home. Email is edited later in Edit profile.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  static const businessNameFieldKey = Key('profile-business-name');
  static const submitKey = Key('complete-profile-submit');
  static const skipKey = Key('complete-profile-skip');

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(launchStateProvider).user?.name ?? '',
  );
  final _businessName = TextEditingController();
  int? _categoryId;

  @override
  void dispose() {
    _name.dispose();
    _businessName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(completeProfileProvider.notifier)
        .submit(
          name: _name.text,
          businessCategoryId: _categoryId,
          businessName: _businessName.text,
        );
  }

  Future<void> _skip() async {
    FocusScope.of(context).unfocus();
    await ref.read(completeProfileProvider.notifier).skip();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(completeProfileProvider);
    final error = state.error;
    final generalError = error != null && !state.categoryRejected
        ? describeErrorWithDetails(context, error)
        : null;
    final busy = state.isBusy;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(JivoSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: JivoSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.completeProfileTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: JivoSpacing.sm),
                  Text(l10n.completeProfileSubtitle),
                  const SizedBox(height: JivoSpacing.xl),
                  TextFormField(
                    key: ProfileForm.nameFieldKey,
                    controller: _name,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
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
                  BusinessCategoryField(
                    value: _categoryId,
                    enabled: !busy,
                    errorText: state.categoryRejected
                        ? l10n.businessCategoryInvalid
                        : null,
                    onChanged: (id) => setState(() => _categoryId = id),
                  ),
                  const SizedBox(height: JivoSpacing.lg),
                  TextFormField(
                    key: CompleteProfileScreen.businessNameFieldKey,
                    controller: _businessName,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.organizationName],
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: l10n.businessNameLabel,
                      counterText: '',
                    ),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  if (generalError != null) ...[
                    const SizedBox(height: JivoSpacing.md),
                    Text(
                      generalError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: JivoSpacing.xl),
                  BusyButton(
                    key: CompleteProfileScreen.submitKey,
                    label: l10n.completeProfileSubmit,
                    busy: state.busy == CompleteProfileAction.submit,
                    onPressed: busy ? null : _submit,
                  ),
                  const SizedBox(height: JivoSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: CompleteProfileScreen.skipKey,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: busy ? null : _skip,
                      child: state.busy == CompleteProfileAction.skip
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.completeProfileSkip),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
