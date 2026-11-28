import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/validation/validators.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/auth_flow.dart';
import 'profile_controllers.dart';

@immutable
class ContactVerifyState {
  const ContactVerifyState({
    this.challenge,
    this.requesting = false,
    this.verifying = false,
    this.error,
  });

  /// The OTP sent to the phone or email being added. Null before Send OTP.
  final OtpChallenge? challenge;
  final bool requesting;
  final bool verifying;
  final Object? error;

  bool get busy => requesting || verifying;
}

/// Adds a phone (`me/phone/otp` + `me/phone/verify`, SMS) or verifies an
/// email (`me/email/otp` + `me/email/verify`) on the signed-in account
/// (`03 §2.11`). On success the current user is replaced with the server's.
class ContactVerifyController extends Notifier<ContactVerifyState> {
  @override
  ContactVerifyState build() => const ContactVerifyState();

  /// [value] is 10 digits for a phone, an address for an email.
  Future<bool> send(LoginMethod kind, String value) async {
    if (state.busy) return false;
    final destination = switch (kind) {
      LoginMethod.phone => Validators.toE164(value.trim()),
      LoginMethod.email => value.trim().toLowerCase(),
    };
    return _request(kind, destination);
  }

  Future<bool> resend() async {
    final challenge = state.challenge;
    if (challenge == null || state.busy) return false;
    return _request(challenge.method, challenge.destination);
  }

  Future<bool> _request(LoginMethod kind, String destination) async {
    state = ContactVerifyState(challenge: state.challenge, requesting: true);
    try {
      final repository = ref.read(profileRepositoryProvider);
      final challenge = switch (kind) {
        LoginMethod.phone => await repository.requestPhoneOtp(destination),
        LoginMethod.email => await repository.requestEmailOtp(destination),
      };
      state = ContactVerifyState(challenge: challenge);
      return true;
    } catch (error) {
      state = ContactVerifyState(challenge: state.challenge, error: error);
      return false;
    }
  }

  /// Returns true once the server accepted [otp].
  Future<bool> verify(String otp) async {
    final challenge = state.challenge;
    if (challenge == null || state.busy) return false;
    state = ContactVerifyState(challenge: challenge, verifying: true);
    try {
      final repository = ref.read(profileRepositoryProvider);
      final user = switch (challenge.method) {
        LoginMethod.phone => await repository.verifyPhone(
          phone: challenge.destination,
          otp: otp,
        ),
        LoginMethod.email => await repository.verifyEmail(
          email: challenge.destination,
          otp: otp,
        ),
      };
      ref.read(currentUserProvider.notifier).replace(user);
      if (ref.mounted) state = ContactVerifyState(challenge: challenge);
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = ContactVerifyState(challenge: challenge, error: error);
      }
      return false;
    }
  }

  void clearError() {
    if (state.error != null) {
      state = ContactVerifyState(challenge: state.challenge);
    }
  }

  /// Back to the entry step.
  void reset() => state = const ContactVerifyState();
}

final contactVerifyProvider =
    NotifierProvider.autoDispose<ContactVerifyController, ContactVerifyState>(
      ContactVerifyController.new,
    );

/// Add a mobile number or add/verify an email: enter it, then the OTP
/// (same UX as login: 6-digit field, resend countdown, mapped errors).
/// Pops `true` when the server verified it.
class ContactVerifyScreen extends ConsumerStatefulWidget {
  const ContactVerifyScreen({required this.kind, this.initial, super.key});

  final LoginMethod kind;

  /// Pre-filled value (the unverified email already on the profile).
  final String? initial;

  static const valueFieldKey = Key('contact-value');
  static const otpFieldKey = Key('contact-otp');

  @override
  ConsumerState<ContactVerifyScreen> createState() =>
      _ContactVerifyScreenState();
}

class _ContactVerifyScreenState extends ConsumerState<ContactVerifyScreen> {
  late final _value = TextEditingController(text: widget.initial ?? '');
  final _otp = TextEditingController();
  bool _showInvalid = false;

  bool get _isPhone => widget.kind == LoginMethod.phone;

  @override
  void dispose() {
    _value.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final value = _value.text.trim();
    final valid = _isPhone
        ? Validators.isMobile(value)
        : Validators.isEmail(value);
    if (!valid) {
      setState(() => _showInvalid = true);
      return;
    }
    final controller = ref.read(contactVerifyProvider.notifier);
    if (await controller.send(widget.kind, value) && mounted) {
      _otp.clear();
      ref
          .read(resendCountdownProvider.notifier)
          .start(ref.read(contactVerifyProvider).challenge!.resendAfterSeconds);
    }
  }

  Future<void> _resend() async {
    final controller = ref.read(contactVerifyProvider.notifier);
    if (await controller.resend() && mounted) {
      _otp.clear();
      ref
          .read(resendCountdownProvider.notifier)
          .start(ref.read(contactVerifyProvider).challenge!.resendAfterSeconds);
      showMessage(context, AppLocalizations.of(context).otpResent);
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final length = ref.read(contactVerifyProvider).challenge?.otpLength ?? 6;
    if (_otp.text.length != length) {
      setState(() => _showInvalid = true);
      return;
    }
    final ok = await ref.read(contactVerifyProvider.notifier).verify(_otp.text);
    if (!mounted) return;
    if (ok) {
      showMessage(
        context,
        _isPhone ? l10n.phoneAdded : l10n.emailVerifiedMessage,
      );
      // The new user refreshes the router; pop once that has settled, or
      // the refresh puts this screen back.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop(true);
      return;
    }
    if (isApiError(
      ref.read(contactVerifyProvider).error,
      ApiErrorCode.otpInvalid,
    )) {
      _otp.clear();
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _edited() {
    if (_showInvalid) setState(() => _showInvalid = false);
    ref.read(contactVerifyProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(contactVerifyProvider);
    final challenge = state.challenge;
    final countdown = ref.watch(resendCountdownProvider);
    final apiError = state.error == null
        ? null
        : describeErrorWithDetails(context, state.error!);

    final List<Widget> step;
    if (challenge == null) {
      step = [
        Text(_isPhone ? l10n.addPhoneSubtitle : l10n.addEmailSubtitle),
        const SizedBox(height: JivoSpacing.xl),
        TextField(
          key: ContactVerifyScreen.valueFieldKey,
          controller: _value,
          autofocus: true,
          keyboardType: _isPhone
              ? TextInputType.phone
              : TextInputType.emailAddress,
          autofillHints: [
            _isPhone
                ? AutofillHints.telephoneNumberNational
                : AutofillHints.email,
          ],
          autocorrect: false,
          inputFormatters: _isPhone
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]
              : [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  LengthLimitingTextInputFormatter(254),
                ],
          onChanged: (_) => _edited(),
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            labelText: _isPhone ? l10n.phoneLabel : l10n.emailAddressLabel,
            prefixText: _isPhone ? '${l10n.phonePrefix} ' : null,
            errorText: _showInvalid
                ? (_isPhone ? l10n.phoneInvalid : l10n.emailInvalid)
                : apiError,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: JivoSpacing.xl),
        BusyButton(
          key: const Key('contact-send'),
          label: l10n.sendOtp,
          busy: state.requesting,
          onPressed: _send,
        ),
      ];
    } else {
      final length = challenge.otpLength;
      step = [
        Text(l10n.otpSentTo(length, challenge.destination)),
        if (!_isPhone) ...[
          const SizedBox(height: JivoSpacing.xs),
          Text(l10n.otpEmailSpamHint, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: JivoSpacing.xl),
        TextField(
          key: ContactVerifyScreen.otpFieldKey,
          controller: _otp,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(length),
          ],
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
          textAlign: TextAlign.center,
          onChanged: (value) {
            _edited();
            if (value.length == length) _verify();
          },
          decoration: InputDecoration(
            labelText: l10n.otpLabel,
            errorText: _showInvalid ? l10n.otpIncomplete(length) : apiError,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: JivoSpacing.xl),
        BusyButton(
          key: const Key('contact-verify'),
          label: l10n.verify,
          busy: state.verifying,
          onPressed: _verify,
        ),
        const SizedBox(height: JivoSpacing.md),
        TextButton(
          onPressed: countdown > 0 || state.busy ? null : _resend,
          child: Text(
            countdown > 0 ? l10n.resendIn(countdown) : l10n.resendOtp,
          ),
        ),
        TextButton(
          onPressed: state.busy
              ? null
              : () {
                  setState(() => _showInvalid = false);
                  ref.read(contactVerifyProvider.notifier).reset();
                },
          child: Text(_isPhone ? l10n.changeNumber : l10n.changeEmail),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPhone ? l10n.addPhoneTitle : l10n.addEmailTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(JivoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: step,
          ),
        ),
      ),
    );
  }
}
