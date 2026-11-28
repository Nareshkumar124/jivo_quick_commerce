import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/validation/validators.dart';
import '../../../shared/widgets/jivo_wordmark.dart';
import '../../../shared/widgets/state_views.dart';
import '../../cms/data/cms_repository.dart';
import '../domain/auth_models.dart';
import 'auth_flow.dart';

/// Login with consent text (`03 §2.2`): phone (+91 validation), email, or
/// a Phone / Email choice, as `GET /auth/methods/` says.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const phoneFieldKey = Key('login-phone');
  static const emailFieldKey = Key('login-email');
  static const methodToggleKey = Key('login-method');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _showInvalid = false;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit(LoginMethod method) async {
    final flow = ref.read(authFlowProvider.notifier);
    final bool sent;
    switch (method) {
      case LoginMethod.phone:
        final digits = _phone.text.trim();
        if (!Validators.isMobile(digits)) {
          setState(() => _showInvalid = true);
          return;
        }
        sent = await flow.requestOtp(digits);
      case LoginMethod.email:
        final email = _email.text.trim();
        if (!Validators.isEmail(email)) {
          setState(() => _showInvalid = true);
          return;
        }
        sent = await flow.requestEmailOtp(email);
    }
    if (sent && mounted) context.go(Routes.otp);
  }

  void _onEdited() {
    if (_showInvalid) setState(() => _showInvalid = false);
    ref.read(authFlowProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final flow = ref.watch(authFlowProvider);
    final expired =
        ref.watch(sessionProvider).lastSignOutReason ==
        SignOutReason.sessionExpired;
    final policies = ref.watch(launchStateProvider).config?.policies;
    // Without policy links in config/app, the in-app pages (public API):
    // the consent sentence never ends without its links (CA-05).
    final inAppPages = policies == null && ref.watch(cmsAvailableProvider);
    // Loaded at start-up; phone while (rarely) still loading.
    final methods =
        ref.watch(loginMethodsProvider).value ?? LoginMethods.fallback;
    final method = effectiveLoginMethod(
      methods,
      ref.watch(selectedLoginMethodProvider),
    );
    final errorText = _showInvalid
        ? (method == LoginMethod.phone ? l10n.phoneInvalid : l10n.emailInvalid)
        : (flow.error != null
              ? describeErrorWithDetails(context, flow.error!)
              : null);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(JivoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expired) ...[
                Card(
                  color: theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(JivoSpacing.lg),
                    child: Text(l10n.sessionExpired),
                  ),
                ),
                const SizedBox(height: JivoSpacing.lg),
              ],
              const SizedBox(height: JivoSpacing.lg),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: JivoWordmark(height: 56),
              ),
              const SizedBox(height: JivoSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  l10n.loginTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: JivoSpacing.sm),
              Text(
                method == LoginMethod.phone
                    ? l10n.loginSubtitle
                    : l10n.loginSubtitleEmail,
              ),
              if (methods.length > 1) ...[
                const SizedBox(height: JivoSpacing.lg),
                Semantics(
                  label: l10n.loginWith,
                  child: SegmentedButton<LoginMethod>(
                    key: LoginScreen.methodToggleKey,
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: LoginMethod.phone,
                        icon: const Icon(Icons.phone_android),
                        label: Text(l10n.loginMethodPhone),
                      ),
                      ButtonSegment(
                        value: LoginMethod.email,
                        icon: const Icon(Icons.mail_outline),
                        label: Text(l10n.loginMethodEmail),
                      ),
                    ],
                    selected: {method},
                    onSelectionChanged: flow.busy
                        ? null
                        : (picked) {
                            ref
                                .read(selectedLoginMethodProvider.notifier)
                                .select(picked.first);
                            _onEdited();
                          },
                  ),
                ),
              ],
              const SizedBox(height: JivoSpacing.xl),
              if (method == LoginMethod.phone)
                TextField(
                  key: LoginScreen.phoneFieldKey,
                  controller: _phone,
                  // The keyboard opens with the screen (CA-05).
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (_) => _onEdited(),
                  onSubmitted: (_) => _submit(method),
                  decoration: InputDecoration(
                    labelText: l10n.phoneLabel,
                    prefixText: '${l10n.phonePrefix} ',
                    errorText: errorText,
                    errorMaxLines: 3,
                  ),
                )
              else
                TextField(
                  key: LoginScreen.emailFieldKey,
                  controller: _email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    LengthLimitingTextInputFormatter(254),
                  ],
                  onChanged: (_) => _onEdited(),
                  onSubmitted: (_) => _submit(method),
                  decoration: InputDecoration(
                    labelText: l10n.emailAddressLabel,
                    errorText: errorText,
                    errorMaxLines: 3,
                  ),
                ),
              const SizedBox(height: JivoSpacing.xl),
              BusyButton(
                label: l10n.getOtp,
                busy: flow.requesting,
                onPressed: () => _submit(method),
              ),
              const SizedBox(height: JivoSpacing.lg),
              Text(
                l10n.consentPrefix,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (policies != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    _PolicyLink(
                      label: l10n.termsOfService,
                      url: policies.terms,
                    ),
                    _PolicyLink(
                      label: l10n.privacyPolicy,
                      url: policies.privacy,
                    ),
                  ],
                )
              else if (inAppPages)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton(
                      key: const Key('login-terms'),
                      onPressed: () =>
                          context.push(Routes.page(CmsSlugs.terms)),
                      child: Text(l10n.termsOfService),
                    ),
                    TextButton(
                      key: const Key('login-privacy'),
                      onPressed: () =>
                          context.push(Routes.page(CmsSlugs.privacy)),
                      child: Text(l10n.privacyPolicy),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyLink extends ConsumerWidget {
  const _PolicyLink({required this.label, required this.url});

  final String label;
  final Uri url;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () async {
      final opened = await ref.read(urlOpenerProvider).open(url);
      if (!opened && context.mounted) {
        showMessage(context, AppLocalizations.of(context).linkOpenFailed);
      }
    },
    child: Text(label),
  );
}
