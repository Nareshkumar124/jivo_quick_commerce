import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../auth/presentation/auth_error_text.dart';
import '../../auth/presentation/rider_account_controller.dart';
import 'delete_account_controller.dart';

/// Delete account (Google Play requirement). Step 1 explains what is
/// deleted, the 30-day grace period and what the law keeps; step 2 takes
/// the OTP sent to the rider's own phone. On success the rider is told the
/// final date and signed out.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  static const _otpLength = 6;

  final _otp = TextEditingController();
  Timer? _ticker;
  String? _localError;

  DeleteAccountController get _controller =>
      ref.read(deleteAccountControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Redraws the resend countdown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final resendAt = ref.read(deleteAccountControllerProvider).resendAt;
      if (mounted && resendAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _localError = null);
    if (await _controller.sendOtp()) _otp.clear();
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final code = _otp.text.trim();
    if (code.length != _otpLength) {
      setState(() => _localError = l10n.deleteAccountOtpTooShort);
      return;
    }
    setState(() => _localError = null);
    final deletion = await _controller.confirm(code);
    if (deletion == null || !mounted) return;
    final date = istDayOf(context, deletion.anonymiseAfter);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => AlertDialog(
        key: const Key('delete-account-done'),
        title: Text(l10n.deleteAccountDoneTitle),
        content: Text(l10n.deleteAccountDoneBody(date)),
        actions: [
          FilledButton(
            key: const Key('delete-account-done-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(l10n.deleteAccountDoneOk),
          ),
        ],
      ),
    );
    // Signing out sends the router to the login screen.
    await _controller.finish();
  }

  String? _errorText(AppLocalizations l10n, DeleteAccountState state) {
    if (_localError != null) return _localError;
    switch (state.blocked) {
      case LogoutResult.blockedWhileOnline:
        return l10n.deleteAccountBlockedOnline;
      case LogoutResult.blockedDuringTask:
        return l10n.deleteAccountBlockedTask;
      case LogoutResult.done || null:
        break;
    }
    final error = state.error;
    if (error == null) return null;
    if (error.rawCode == noPhoneCode) {
      return l10n.deleteAccountNoPhone;
    }
    return authErrorText(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(deleteAccountControllerProvider);
    final error = _errorText(l10n, state);
    final otpStep = state.step == DeleteAccountStep.otp;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: otpStep
                ? _OtpStep(
                    controller: _otp,
                    phone: state.phone ?? '',
                    resendAt: state.resendAt,
                    busy: state.busy,
                    onResend: _sendOtp,
                    now: ref.read(clockProvider)(),
                  )
                : const _ExplainStep(),
          ),
          PrimaryActionBar(
            buttonKey: Key(
              otpStep ? 'delete-account-confirm' : 'delete-account-send-otp',
            ),
            label: otpStep
                ? l10n.deleteAccountConfirm
                : l10n.deleteAccountSendOtp,
            busy: state.busy,
            error: error,
            errorKey: const Key('delete-account-error'),
            onPressed: otpStep ? _confirm : _sendOtp,
          ),
        ],
      ),
    );
  }
}

class _ExplainStep extends ConsumerWidget {
  const _ExplainStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = RiderColors.of(context);
    Widget point(IconData icon, String text, Key key) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(key: key, text, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
    return ListView(
      key: const Key('delete-account-explain'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.danger, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.deleteAccountWarningTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        point(
          Icons.delete_outline,
          l10n.deleteAccountWhatDeleted,
          const Key('delete-account-what'),
        ),
        point(
          Icons.event,
          l10n.deleteAccountGrace,
          const Key('delete-account-grace'),
        ),
        point(
          Icons.gavel,
          l10n.deleteAccountKept,
          const Key('delete-account-kept'),
        ),
        point(
          Icons.payments_outlined,
          l10n.deleteAccountCashAdvice,
          const Key('delete-account-cash'),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('delete-account-learn-more'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () =>
                ref.read(urlOpenerProvider).open(accountDeletionInfoUrl),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.deleteAccountLearnMore),
          ),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controller,
    required this.phone,
    required this.resendAt,
    required this.busy,
    required this.onResend,
    required this.now,
  });

  final TextEditingController controller;
  final String phone;
  final DateTime? resendAt;
  final DateTime now;
  final bool busy;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final left = resendAt == null ? 0 : resendAt!.difference(now).inSeconds + 1;
    final canResend = left <= 0 && !busy;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.deleteAccountOtpPrompt(
            phone.startsWith('+') ? IndianMobile.format(phone) : phone,
          ),
          key: const Key('delete-account-otp-prompt'),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('delete-account-otp'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 12),
          decoration: InputDecoration(labelText: l10n.deleteAccountOtpLabel),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('delete-account-resend'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: canResend ? onResend : null,
            child: Text(left > 0 ? l10n.otpResendIn(left) : l10n.otpResend),
          ),
        ),
      ],
    );
  }
}
