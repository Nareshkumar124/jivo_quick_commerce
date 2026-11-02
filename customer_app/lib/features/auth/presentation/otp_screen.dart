import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import 'auth_flow.dart';

/// OTP entry with SMS autofill, resend countdown and error handling
/// (`03 §2.2`).
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  static const otpFieldKey = Key('otp-field');

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otp = TextEditingController();
  bool _showIncomplete = false;
  late final _autofill = ref.read(otpAutofillProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final challenge = ref.read(authFlowProvider).challenge;
      if (challenge != null) {
        ref
            .read(resendCountdownProvider.notifier)
            .start(challenge.resendAfterSeconds);
      }
      _listenForSms();
    });
  }

  Future<void> _listenForSms() async {
    final code = await _autofill.listenForCode();
    final length = ref.read(authFlowProvider).challenge?.otpLength ?? 6;
    if (!mounted || code == null || code.length != length) return;
    _otp.text = code;
    await _verify();
  }

  @override
  void dispose() {
    _autofill.stop();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final length = ref.read(authFlowProvider).challenge?.otpLength ?? 6;
    if (_otp.text.length != length) {
      setState(() => _showIncomplete = true);
      return;
    }
    await ref.read(authFlowProvider.notifier).verify(_otp.text);
  }

  Future<void> _resend() async {
    final flow = ref.read(authFlowProvider.notifier);
    if (await flow.resend() && mounted) {
      _otp.clear();
      ref
          .read(resendCountdownProvider.notifier)
          .start(ref.read(authFlowProvider).challenge!.resendAfterSeconds);
      showMessage(context, AppLocalizations.of(context).otpResent);
      _listenForSms();
    }
  }

  String? _errorText(AppLocalizations l10n, Object? error, int length) {
    if (_showIncomplete) return l10n.otpIncomplete(length);
    if (error == null) return null;
    if (isApiError(error, ApiErrorCode.permissionDenied)) {
      return l10n.accountDeactivated;
    }
    return describeErrorWithDetails(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final flow = ref.watch(authFlowProvider);
    final challenge = flow.challenge;
    final countdown = ref.watch(resendCountdownProvider);
    if (challenge == null) return const Scaffold();
    final length = challenge.otpLength;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            ref.read(authFlowProvider.notifier).reset();
            context.go(Routes.login);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(JivoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.otpTitle,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: JivoSpacing.sm),
              Text(l10n.otpSentTo(length, challenge.phone)),
              const SizedBox(height: JivoSpacing.xl),
              TextField(
                key: OtpScreen.otpFieldKey,
                controller: _otp,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                style: theme.textTheme.headlineSmall?.copyWith(
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                onChanged: (value) {
                  if (_showIncomplete) setState(() => _showIncomplete = false);
                  ref.read(authFlowProvider.notifier).clearError();
                  if (value.length == length) _verify();
                },
                decoration: InputDecoration(
                  labelText: l10n.otpLabel,
                  errorText: _errorText(l10n, flow.error, length),
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: JivoSpacing.xl),
              BusyButton(
                label: l10n.verify,
                busy: flow.verifying,
                onPressed: _verify,
              ),
              const SizedBox(height: JivoSpacing.md),
              TextButton(
                onPressed: countdown > 0 || flow.busy ? null : _resend,
                child: Text(
                  countdown > 0 ? l10n.resendIn(countdown) : l10n.resendOtp,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(authFlowProvider.notifier).reset();
                  context.go(Routes.login);
                },
                child: Text(l10n.changeNumber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
