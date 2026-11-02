import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/validation/validators.dart';
import '../../../shared/widgets/state_views.dart';
import 'auth_flow.dart';

/// Phone login with +91 validation and consent text (`03 §2.2`).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static const phoneFieldKey = Key('login-phone');

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  bool _showInvalid = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final digits = _phone.text.trim();
    if (!Validators.isMobile(digits)) {
      setState(() => _showInvalid = true);
      return;
    }
    if (await ref.read(authFlowProvider.notifier).requestOtp(digits) &&
        mounted) {
      context.go(Routes.otp);
    }
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
              const SizedBox(height: JivoSpacing.xl),
              Semantics(
                header: true,
                child: Text(
                  l10n.loginTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: JivoSpacing.sm),
              Text(l10n.loginSubtitle),
              const SizedBox(height: JivoSpacing.xl),
              TextField(
                key: LoginScreen.phoneFieldKey,
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) {
                  if (_showInvalid) setState(() => _showInvalid = false);
                  ref.read(authFlowProvider.notifier).clearError();
                },
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  prefixText: '${l10n.phonePrefix} ',
                  errorText: _showInvalid
                      ? l10n.phoneInvalid
                      : (flow.error != null
                            ? describeErrorWithDetails(context, flow.error!)
                            : null),
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: JivoSpacing.xl),
              BusyButton(
                label: l10n.getOtp,
                busy: flow.requesting,
                onPressed: _submit,
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
