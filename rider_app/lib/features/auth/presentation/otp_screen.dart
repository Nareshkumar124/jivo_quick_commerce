import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';

import 'package:jivo_core/helpers.dart';

import 'auth_error_text.dart';
import 'auth_providers.dart';
import 'login_controllers.dart';

/// OTP verify (04 §2.1): `otp_length` digits, resend countdown from
/// `resend_after_seconds`, SMS autofill (User Consent API), and the
/// `OTP_INVALID` / `OTP_EXPIRED` / `OTP_RATE_LIMITED` errors.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  late final OtpAutofill _autofill;

  @override
  void initState() {
    super.initState();
    _autofill = ref.read(otpAutofillProvider);
    _listenForSms();
  }

  @override
  void dispose() {
    unawaited(_autofill.stop());
    _code.dispose();
    super.dispose();
  }

  /// Waits for the OTP SMS (one system prompt) and submits its code.
  Future<void> _listenForSms() async {
    final code = await _autofill.listenForCode();
    if (!mounted || code == null) return;
    final length = ref.read(otpChallengeProvider)?.otpLength;
    if (code.length != length) return;
    _code.text = code;
    await _verify();
  }

  Future<void> _verify() =>
      ref.read(otpControllerProvider.notifier).verify(_code.text);

  Future<void> _resend() async {
    await ref.read(otpControllerProvider.notifier).resend();
  }

  /// Back to the phone step: without a pending OTP the router redirects to
  /// login.
  void _changeNumber() => ref.read(otpChallengeProvider.notifier).clear();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final challenge = ref.watch(otpChallengeProvider);
    final state = ref.watch(otpControllerProvider);

    // Clear the field after a wrong or expired code, and listen for the new
    // SMS after a successful resend.
    ref.listen(otpControllerProvider.select((s) => s.clearCodeId), (_, _) {
      _code.clear();
    });
    ref.listen(otpControllerProvider.select((s) => s.cooldown.id), (_, _) {
      final current = ref.read(otpControllerProvider);
      if (current.error == null) unawaited(_listenForSms());
    });

    if (challenge == null) {
      // The router sends the rider back to the phone step.
      return const Scaffold(body: SizedBox.shrink());
    }

    final error = state.error;
    final complete = _code.text.length == challenge.otpLength;
    final Widget primary = state.expired
        ? FilledButton(
            key: const Key('otp-get-new-code'),
            onPressed: state.busy ? null : _resend,
            child: Text(l10n.otpGetNewCode),
          )
        : FilledButton(
            key: const Key('otp-verify'),
            onPressed: complete && !state.busy ? _verify : null,
            child: state.verifying
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Text(l10n.otpVerify),
          );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(l10n.otpTitle, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      l10n.otpSentTo(
                        challenge.otpLength,
                        IndianMobile.format(challenge.phone),
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const Key('otp-change-number'),
                        onPressed: state.busy ? null : _changeNumber,
                        child: Text(l10n.otpChangeNumber),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('otp-code'),
                      controller: _code,
                      autofocus: true,
                      enabled: !state.expired,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(challenge.otpLength),
                      ],
                      style: theme.textTheme.headlineMedium?.copyWith(
                        letterSpacing: 12,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.otpFieldLabel,
                        counterText: '',
                      ),
                      onChanged: (value) {
                        setState(() {});
                        if (value.length == challenge.otpLength) _verify();
                      },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        authErrorText(context, error),
                        key: const Key('otp-error'),
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (!state.expired)
                      _ResendCountdown(
                        cooldown: state.cooldown,
                        enabled: !state.busy,
                        onResend: _resend,
                      ),
                  ],
                ),
              ),
              primary,
            ],
          ),
        ),
      ),
    );
  }
}

/// "Resend code in 25 s", then a "Resend code" button. A new
/// [ResendCooldown.id] restarts the countdown (after a resend, or with
/// `retry_after_seconds` after `OTP_RATE_LIMITED`).
class _ResendCountdown extends StatefulWidget {
  const _ResendCountdown({
    required this.cooldown,
    required this.enabled,
    required this.onResend,
  });

  final ResendCooldown cooldown;
  final bool enabled;
  final VoidCallback onResend;

  @override
  State<_ResendCountdown> createState() => _ResendCountdownState();
}

class _ResendCountdownState extends State<_ResendCountdown> {
  Timer? _timer;
  int _remaining = 0;

  @override
  void initState() {
    super.initState();
    _start(widget.cooldown.seconds);
  }

  @override
  void didUpdateWidget(_ResendCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cooldown.id != widget.cooldown.id) {
      _start(widget.cooldown.seconds);
    }
  }

  void _start(int seconds) {
    _timer?.cancel();
    _remaining = seconds;
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remaining--);
      if (_remaining <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_remaining > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          l10n.otpResendIn(_remaining),
          key: const Key('otp-resend-countdown'),
          textAlign: TextAlign.center,
        ),
      );
    }
    return TextButton(
      key: const Key('otp-resend'),
      onPressed: widget.enabled ? widget.onResend : null,
      child: Text(l10n.otpResend),
    );
  }
}
