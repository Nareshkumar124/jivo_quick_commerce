import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../launch/presentation/launch_controller.dart';
import '../domain/indian_mobile.dart';
import 'auth_error_text.dart';
import 'login_controllers.dart';

/// Phone login (04 §2.1): +91 and 10 digits, consent with links to the
/// Terms and Privacy policy from `config/app`, then `POST /auth/otp/request/`
/// with `app: rider`.
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController();

  /// Shown only after the rider tried to continue.
  PhoneInputError? _inputError;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = IndianMobile.validate(_phone.text);
    setState(() => _inputError = error);
    if (error != null) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(phoneLoginControllerProvider.notifier)
        .requestOtp(_phone.text);
    if (ok && mounted) context.go(Routes.otp);
  }

  String? _inputErrorText(AppLocalizations l10n) => switch (_inputError) {
    null => null,
    PhoneInputError.empty => l10n.loginPhoneEmpty,
    PhoneInputError.incomplete => l10n.loginPhoneIncomplete,
    PhoneInputError.invalid => l10n.loginPhoneInvalid,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(phoneLoginControllerProvider);
    final policies = ref.watch(launchControllerProvider).config?.policyUrls;
    final expired =
        ref.watch(sessionManagerProvider).lastSignOutReason ==
        SignOutReason.sessionExpired;
    final serverError = state.error;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 24),
                    Icon(
                      Icons.delivery_dining,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.loginTitle, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(l10n.loginSubtitle, style: theme.textTheme.bodyLarge),
                    if (expired) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: theme.colorScheme.secondaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            l10n.loginSessionExpired,
                            key: const Key('login-session-expired'),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('login-phone'),
                      controller: _phone,
                      autofocus: true,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: theme.textTheme.headlineSmall,
                      decoration: InputDecoration(
                        labelText: l10n.loginPhoneLabel,
                        hintText: l10n.loginPhoneHint,
                        prefixText: '+91 ',
                        errorText: _inputErrorText(l10n),
                      ),
                      onChanged: (_) {
                        if (_inputError != null) {
                          setState(() => _inputError = null);
                        }
                        ref
                            .read(phoneLoginControllerProvider.notifier)
                            .clearError();
                      },
                      onSubmitted: (_) => _submit(),
                    ),
                    if (serverError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        authErrorText(context, serverError),
                        key: const Key('login-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              if (policies != null)
                _ConsentText(
                  terms: Uri.tryParse(policies.terms),
                  privacy: Uri.tryParse(policies.privacy),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('login-get-otp'),
                onPressed: state.submitting ? null : _submit,
                child: state.submitting
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(l10n.loginGetOtp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "By continuing, you agree to the Terms of Use and the Privacy Policy."
/// with both names as links. The sentence is one ARB string with
/// placeholders, so translations can reorder them.
class _ConsentText extends ConsumerStatefulWidget {
  const _ConsentText({required this.terms, required this.privacy});

  final Uri? terms;
  final Uri? privacy;

  @override
  ConsumerState<_ConsentText> createState() => _ConsentTextState();
}

class _ConsentTextState extends ConsumerState<_ConsentText> {
  static const _termsMarker = '\u0001';
  static const _privacyMarker = '\u0002';

  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => _open(widget.terms);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => _open(widget.privacy);

  void _open(Uri? uri) {
    if (uri != null) unawaited(ref.read(urlOpenerProvider).open(uri));
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final linkStyle = TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    final sentence = l10n.loginConsent(_termsMarker, _privacyMarker);
    final spans = <InlineSpan>[];
    for (final part in sentence.split(
      RegExp('(?=[\u0001\u0002])|(?<=[\u0001\u0002])'),
    )) {
      if (part == _termsMarker) {
        spans.add(
          TextSpan(
            text: l10n.loginTermsLink,
            style: linkStyle,
            recognizer: _termsTap,
          ),
        );
      } else if (part == _privacyMarker) {
        spans.add(
          TextSpan(
            text: l10n.loginPrivacyLink,
            style: linkStyle,
            recognizer: _privacyTap,
          ),
        );
      } else if (part.isNotEmpty) {
        spans.add(TextSpan(text: part));
      }
    }
    return Text.rich(
      TextSpan(style: theme.textTheme.bodyMedium, children: spans),
      key: const Key('login-consent'),
    );
  }
}
