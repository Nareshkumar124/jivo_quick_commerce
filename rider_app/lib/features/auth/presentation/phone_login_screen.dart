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
import '../../../shared/widgets/error_line.dart';
import '../../../shared/widgets/jivo_wordmark.dart';
import '../../launch/presentation/launch_controller.dart';

import 'package:jivo_core/helpers.dart';

import '../domain/login_method.dart';
import 'auth_error_text.dart';
import 'login_controllers.dart';
import 'support_contact_buttons.dart';

/// Login (04 §2.1): phone (+91 and 10 digits, `POST /auth/otp/request/`)
/// and/or email (`POST /auth/email-otp/request/`), as
/// `GET /auth/methods/?app=rider` says (phone when that call fails; a
/// Phone/Email toggle when both are on). Consent with links to the Terms and
/// Privacy policy from `config/app`.
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();

  /// The rider's pick on the Phone/Email toggle (when both are on).
  LoginMethod? _chosen;

  /// Shown only after the rider tried to continue with an email.
  String? _emailError;

  /// Shown only after the rider tried to continue, or for a complete
  /// 10-digit number that can't be an Indian mobile. Never while a number
  /// is still being typed (device test 2026-11-17: the field went red
  /// mid-typing).
  PhoneInputError? _inputError;

  /// Below this height (the keyboard is open on a phone) the logo is left
  /// out, so the title and the number field both stay in view.
  static const _compactHeight = 520.0;

  /// National digits of an Indian mobile number (after +91).
  static const _phoneDigits = 10;

  void _onPhoneChanged(String value) {
    final complete = value.length == _phoneDigits;
    final error = complete ? IndianMobile.validate(value) : null;
    if (error != _inputError) setState(() => _inputError = error);
    ref.read(phoneLoginControllerProvider.notifier).clearError();
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  LoginMethod _mode(List<LoginMethod> methods) {
    final chosen = _chosen;
    return chosen != null && methods.contains(chosen) ? chosen : methods.first;
  }

  Future<void> _submitFor(LoginMethod mode) =>
      mode == LoginMethod.email ? _submitEmail() : _submit();

  Future<void> _submitEmail() async {
    final l10n = AppLocalizations.of(context);
    final text = _email.text.trim();
    final error = text.isEmpty
        ? l10n.loginEmailEmpty
        : (looksLikeEmail(text) ? null : l10n.loginEmailInvalid);
    setState(() => _emailError = error);
    if (error != null) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(phoneLoginControllerProvider.notifier)
        .requestEmailOtp(text);
    if (ok && mounted) context.go(Routes.otp);
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
    final wrongApp = ref.watch(wrongAppNoticeProvider);
    final serverError = state.error;
    final methods =
        ref.watch(loginMethodsProvider).value ?? const [LoginMethod.phone];
    final mode = _mode(methods);
    final isEmail = mode == LoginMethod.email;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The title sits above the scrolling part: with the keyboard
                // open the field scrolls into view without pushing the title
                // under the status bar (device test 2026-11-17). The logo
                // scrolls, and is left out when the keyboard leaves little
                // room.
                Text(
                  l10n.loginTitle,
                  key: const Key('login-title'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    key: const Key('login-list'),
                    children: [
                      if (constraints.maxHeight >= _compactHeight) ...[
                        const SizedBox(height: 8),
                        const Center(
                          child: JivoWordmark(
                            key: Key('login-logo'),
                            height: 64,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (methods.length > 1) ...[
                        SegmentedButton<LoginMethod>(
                          key: const Key('login-method-toggle'),
                          segments: [
                            ButtonSegment(
                              value: LoginMethod.phone,
                              icon: const Icon(Icons.phone_android),
                              label: Text(
                                l10n.loginMethodPhone,
                                key: const Key('login-method-phone'),
                              ),
                            ),
                            ButtonSegment(
                              value: LoginMethod.email,
                              icon: const Icon(Icons.email_outlined),
                              label: Text(
                                l10n.loginMethodEmail,
                                key: const Key('login-method-email'),
                              ),
                            ),
                          ],
                          selected: {mode},
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onSelectionChanged: state.submitting
                              ? null
                              : (picked) {
                                  ref
                                      .read(
                                        phoneLoginControllerProvider.notifier,
                                      )
                                      .clearError();
                                  setState(() => _chosen = picked.first);
                                },
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        isEmail ? l10n.loginEmailSubtitle : l10n.loginSubtitle,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (expired) ...[
                        const SizedBox(height: 16),
                        Card(
                          color: theme.colorScheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: wrongApp
                                ? Text(
                                    l10n.wrongAppError,
                                    key: const Key('login-wrong-app'),
                                  )
                                : Text(
                                    l10n.loginSessionExpired,
                                    key: const Key('login-session-expired'),
                                  ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (isEmail)
                        TextField(
                          key: const Key('login-email'),
                          controller: _email,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.email],
                          scrollPadding: const EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            64,
                          ),
                          style: theme.textTheme.titleLarge,
                          decoration: InputDecoration(
                            labelText: l10n.loginEmailLabel,
                            hintText: l10n.loginEmailHint,
                            errorText: _emailError,
                          ),
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                            ref
                                .read(phoneLoginControllerProvider.notifier)
                                .clearError();
                          },
                          onSubmitted: (_) => _submitEmail(),
                        )
                      else
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
                            LengthLimitingTextInputFormatter(_phoneDigits),
                          ],
                          // Room for the error line under the field.
                          scrollPadding: const EdgeInsets.fromLTRB(
                            20,
                            20,
                            20,
                            64,
                          ),
                          style: theme.textTheme.headlineSmall,
                          decoration: InputDecoration(
                            labelText: l10n.loginPhoneLabel,
                            hintText: l10n.loginPhoneHint,
                            prefixText: '+91 ',
                            errorText: _inputErrorText(l10n),
                          ),
                          onChanged: _onPhoneChanged,
                          onSubmitted: (_) => _submit(),
                        ),
                      if (serverError != null) ...[
                        const SizedBox(height: 12),
                        ErrorLine(
                          authErrorText(context, serverError),
                          textKey: const Key('login-error'),
                        ),
                        if (isEmailNotRegistered(serverError))
                          const SupportContactButtons(),
                      ],
                    ],
                  ),
                ),
                // The consent and the button never take more than half the
                // screen; at 200 % text they scroll, button kept last (RA-03).
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.4,
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (policies != null)
                          _ConsentText(
                            terms: Uri.tryParse(policies.terms),
                            privacy: Uri.tryParse(policies.privacy),
                          ),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('login-get-otp'),
                          onPressed: state.submitting
                              ? null
                              : () => _submitFor(mode),
                          child: state.submitting
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                )
                              : Text(l10n.loginGetOtp),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
    // UX audit RA-03: the inline links are about 20 dp tall, so the same
    // two pages also open from 48 dp buttons under the sentence.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(style: theme.textTheme.bodyMedium, children: spans),
          key: const Key('login-consent'),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              key: const Key('login-terms-button'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: widget.terms == null
                  ? null
                  : () => _open(widget.terms),
              child: Text(l10n.loginTermsLink),
            ),
            ExcludeSemantics(
              child: Text('·', style: theme.textTheme.bodyLarge),
            ),
            TextButton(
              key: const Key('login-privacy-button'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: widget.privacy == null
                  ? null
                  : () => _open(widget.privacy),
              child: Text(l10n.loginPrivacyLink),
            ),
          ],
        ),
      ],
    );
  }
}
