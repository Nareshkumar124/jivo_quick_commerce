import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../launch/presentation/launch_controller.dart';
import '../data/fake_task_backend.dart';
import '../domain/rider_task.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';
import 'task_flow_controller.dart';
import 'task_providers.dart';
import 'task_screen.dart';

/// At the customer (04 §2.6, screen 12): the delivery OTP, then for COD the
/// exact amount due with "Cash collected ₹X" (confirmed) or a UPI QR the
/// server confirms, then one `deliver` call.
///
/// The typed OTP and the cash confirmation live on this screen only (a
/// restart asks again); the OTP attempts, the lock and the UPI status come
/// from the server.
class AtCustomerStep extends ConsumerStatefulWidget {
  const AtCustomerStep({required this.task, super.key});

  final RiderTask task;

  @override
  ConsumerState<AtCustomerStep> createState() => _AtCustomerStepState();
}

class _AtCustomerStepState extends ConsumerState<AtCustomerStep> {
  final _otp = TextEditingController();

  /// OTP entered and the rider moved on to collecting the COD amount.
  bool _collecting = false;

  /// Kept across a wrong-OTP retry, so the rider does not collect twice.
  bool _cashConfirmed = false;

  /// The rider switched from an unpaid UPI QR to cash (the customer's UPI
  /// failed). Showing the QR again switches back.
  bool _preferCash = false;
  Timer? _upiPoll;

  @override
  void initState() {
    super.initState();
    // Restored with a QR still waiting (app restarted mid-payment): keep
    // asking the server until it is paid or expires.
    if (widget.task.codQr?.status == UpiQrStatus.pending) _startUpiPoll();
  }

  @override
  void dispose() {
    _otp.dispose();
    _upiPoll?.cancel();
    super.dispose();
  }

  RiderTask get _task => ref.read(taskFlowControllerProvider).task!;
  TaskFlowController get _controller =>
      ref.read(taskFlowControllerProvider.notifier);

  bool get _otpComplete => _otp.text.length == widget.task.otpLength;

  Future<void> _deliver(CodCollection? collection) async {
    final ok = await _controller.deliver(
      otp: _otp.text,
      collection: collection,
    );
    if (ok || !mounted) return;
    final error = ref.read(taskFlowControllerProvider).error;
    if (error?.code == ApiErrorCode.deliveryOtpInvalid) {
      // Back to the code; the collection is kept.
      setState(() {
        _collecting = false;
        _otp.clear();
      });
    }
  }

  void _continueFromOtp() {
    if (!_otpComplete) return;
    if (!widget.task.isCod) {
      unawaited(_deliver(null));
      return;
    }
    _controller.clearError();
    setState(() => _collecting = true);
  }

  Future<void> _confirmCash() async {
    final l10n = AppLocalizations.of(context);
    final amount = formatRupees(_task.codAmountDue ?? '');
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.codConfirmTitle),
        content: Text(l10n.codConfirmBody(amount)),
        actions: [
          TextButton(
            key: const Key('cod-cash-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.codConfirmNo),
          ),
          FilledButton(
            key: const Key('cod-cash-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.codConfirmYes),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _cashConfirmed = true);
    await _deliver(const CodCollection.cash(cashConfirmed: true));
  }

  Future<void> _showQr() async {
    setState(() => _preferCash = false);
    final ok = await _controller.createCodQr();
    if (ok && mounted) _startUpiPoll();
  }

  /// The server confirms the UPI payment (Razorpay); poll the task.
  void _startUpiPoll() {
    _upiPoll?.cancel();
    _upiPoll = Timer.periodic(const Duration(seconds: 5), (_) {
      final status = ref.read(taskFlowControllerProvider).task?.codQr?.status;
      if (status != UpiQrStatus.pending) {
        _upiPoll?.cancel();
        return;
      }
      unawaited(_controller.load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskFlowControllerProvider);
    final task = state.task ?? widget.task;

    if (task.otpLocked) return _Locked(task: task);
    if (!_collecting) return _otpStep(context, l10n, state, task);
    return _codStep(context, l10n, state, task);
  }

  Widget _otpStep(
    BuildContext context,
    AppLocalizations l10n,
    TaskFlowState state,
    RiderTask task,
  ) {
    final theme = Theme.of(context);
    final left = task.otpAttemptsRemaining;
    return TaskStepScaffold(
      task: task,
      title: l10n.otpStepTitle,
      bottomInBody: true,
      content: [
        Text(l10n.otpStepHelp, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        TextField(
          key: const Key('delivery-otp'),
          controller: _otp,
          keyboardType: TextInputType.number,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(letterSpacing: 12),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(task.otpLength),
          ],
          decoration: InputDecoration(labelText: l10n.otpStepLabel),
          onChanged: (_) {
            _controller.clearError();
            setState(() {});
          },
        ),
        if (left != null && left < FakeTaskBackend.maxOtpAttempts) ...[
          const SizedBox(height: 8),
          Text(
            l10n.otpAttemptsLeft(left),
            key: const Key('otp-attempts'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('call-customer'),
          onPressed: _controller.callCustomer,
          icon: const Icon(Icons.call),
          label: Text(l10n.taskCallCustomer),
        ),
      ],
      actions: PrimaryActionBar(
        buttonKey: Key(task.isCod ? 'otp-continue' : 'task-deliver'),
        label: task.isCod ? l10n.otpContinue : l10n.taskDeliver,
        busy: state.busy != null,
        onPressed: _otpComplete ? _continueFromOtp : null,
        errorKey: const Key('task-error'),
        error: taskStepError(context, state, action: TaskAction.deliver),
        secondary: [
          TextButton(
            key: const Key('task-cant-deliver'),
            onPressed: () => context.push(Routes.taskFail),
            child: Text(l10n.taskCantDeliver),
          ),
        ],
      ),
    );
  }

  Widget _codStep(
    BuildContext context,
    AppLocalizations l10n,
    TaskFlowState state,
    RiderTask task,
  ) {
    final theme = Theme.of(context);
    final amount = formatRupees(task.codAmountDue ?? '');
    final qr = task.codQr;
    final busy = state.busy != null;
    final Widget actions;
    final showQr = qr != null && !_cashConfirmed && !_preferCash;
    if (showQr) {
      final paid = qr.status == UpiQrStatus.paid;
      final expired = qr.status == UpiQrStatus.expired;
      actions = PrimaryActionBar(
        buttonKey: const Key('cod-upi-deliver'),
        label: l10n.taskDeliver,
        busy: busy,
        hint: paid || expired ? null : l10n.codUpiWaiting,
        onPressed: paid ? () => _deliver(const CodCollection.upi()) : null,
        errorKey: const Key('task-error'),
        error: taskStepError(context, state, action: TaskAction.deliver),
        secondary: [
          if (expired)
            OutlinedButton(
              key: const Key('cod-upi-again'),
              onPressed: busy ? null : _showQr,
              child: Text(l10n.codShowUpi),
            )
          else if (!paid)
            OutlinedButton(
              key: const Key('cod-upi-check'),
              onPressed: busy ? null : _controller.load,
              child: Text(l10n.codUpiCheck),
            ),
          if (!paid)
            TextButton(
              key: const Key('cod-take-cash'),
              onPressed: busy ? null : () => setState(() => _preferCash = true),
              child: Text(l10n.codTakeCashInstead),
            ),
        ],
      );
    } else {
      actions = PrimaryActionBar(
        buttonKey: const Key('cod-cash'),
        label: _cashConfirmed
            ? l10n.taskDeliver
            : l10n.codCashCollected(amount),
        busy: busy,
        onPressed: _cashConfirmed
            ? () => _deliver(const CodCollection.cash(cashConfirmed: true))
            : _confirmCash,
        errorKey: const Key('task-error'),
        error: taskStepError(context, state, action: TaskAction.deliver),
        secondary: [
          if (!_cashConfirmed)
            OutlinedButton.icon(
              key: const Key('cod-upi'),
              onPressed: busy ? null : _showQr,
              icon: const Icon(Icons.qr_code_2),
              label: Text(l10n.codShowUpi),
            ),
        ],
      );
    }

    return TaskStepScaffold(
      task: task,
      title: l10n.codTitle,
      content: [
        Text(l10n.codAmountDueLabel, style: theme.textTheme.titleMedium),
        Text(
          amount,
          key: const Key('cod-amount'),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(l10n.codExactAmount, style: theme.textTheme.bodyLarge),
        if (_cashConfirmed) ...[
          const SizedBox(height: 16),
          ListTile(
            key: const Key('cod-cash-done'),
            leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
            title: Text(l10n.codCashDone(amount)),
          ),
        ],
        if (showQr) ...[
          const SizedBox(height: 16),
          Center(child: _QrImage(url: qr.imageUrl)),
          Text(
            switch (qr.status) {
              UpiQrStatus.paid => l10n.codUpiPaid,
              UpiQrStatus.expired => l10n.codUpiExpired,
              UpiQrStatus.pending => l10n.codUpiWaiting,
            },
            key: const Key('cod-upi-status'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const _DevPayUpi(),
        ],
        const SizedBox(height: 8),
        TextButton(
          key: const Key('cod-back'),
          onPressed: busy ? null : () => setState(() => _collecting = false),
          child: Text(l10n.codChangeOtp),
        ),
      ],
      actions: actions,
    );
  }
}

/// DELIVERY_OTP_LOCKED: 5 wrong codes, ops alerted (04 §2.6).
class _Locked extends ConsumerWidget {
  const _Locked({required this.task});

  final RiderTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final phone = ref.watch(launchControllerProvider).config?.support.phone;
    return TaskStepScaffold(
      task: task,
      title: l10n.otpLockedTitle,
      content: [
        Icon(Icons.lock, size: 72, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 16),
        Text(
          l10n.deliveryOtpLocked,
          key: const Key('otp-locked'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
      actions: PrimaryActionBar(
        buttonKey: const Key('call-support'),
        label: l10n.callSupport,
        onPressed: phone == null || phone.trim().isEmpty
            ? null
            : () => ref
                  .read(urlOpenerProvider)
                  .open(Uri(scheme: 'tel', path: phone)),
        secondary: [
          TextButton(
            key: const Key('task-cant-deliver'),
            onPressed: () => context.push(Routes.taskFail),
            child: Text(l10n.taskCantDeliver),
          ),
        ],
      ),
    );
  }
}

/// Dev flavor with the fake only: the customer pays the QR.
class _DevPayUpi extends ConsumerWidget {
  const _DevPayUpi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(taskRepositoryProvider);
    if (!ref.watch(appEnvProvider).showDevTools ||
        repository is! FakeTaskBackend) {
      return const SizedBox.shrink();
    }
    return TextButton(
      key: const Key('dev-upi-paid'),
      onPressed: () {
        repository.markUpiPaid();
        ref.read(taskFlowControllerProvider.notifier).load();
      },
      child: Text(AppLocalizations.of(context).devUpiPaid),
    );
  }
}

/// The UPI QR image from the server. Only an https URL is loaded; anything
/// else (or a failed load) shows an error, never a broken or spoofable image.
/// No URL at all is the fake (dev and tests): a placeholder.
class _QrImage extends StatelessWidget {
  const _QrImage({required this.url});

  final String? url;

  static bool isSafe(String? url) => Uri.tryParse(url ?? '')?.scheme == 'https';

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final l10n = AppLocalizations.of(context);
    Widget unavailable() => Padding(
      key: const Key('cod-qr-unavailable'),
      padding: const EdgeInsets.all(16),
      child: Text(
        l10n.codQrUnavailable,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
    if (url == null) return const Icon(Icons.qr_code_2, size: 200);
    if (!isSafe(url)) return unavailable();
    return Image.network(
      url,
      key: const Key('cod-qr-image'),
      height: 240,
      errorBuilder: (_, _, _) => unavailable(),
    );
  }
}
