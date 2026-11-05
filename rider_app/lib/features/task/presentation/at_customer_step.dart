import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../launch/presentation/launch_controller.dart';
import '../data/fake_task_backend.dart';
import '../domain/rider_task.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';
import 'cod_amount_changed_notice.dart';
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
  final _otpFocus = FocusNode();

  /// OTP entered and the rider moved on to collecting the COD amount.
  bool _collecting = false;

  /// Kept across a wrong-OTP retry, so the rider does not collect twice.
  /// The amount due when the rider confirmed the cash. If the server's
  /// amount changes afterwards (`deliver` 400 with `amount_due`), the
  /// confirmation no longer counts: the rider confirms the new amount.
  String? _confirmedAmount;

  bool get _cashConfirmed {
    final confirmed = _confirmedAmount;
    final due = ref.read(taskFlowControllerProvider).task?.codAmountDue;
    return confirmed != null && due != null && isSameAmount(confirmed, due);
  }

  /// The rider switched from an unpaid UPI QR to cash (the customer's UPI
  /// failed). Showing the QR again switches back.
  bool _preferCash = false;

  // While a UPI QR is open, the task controller polls the task every 3 s
  // (taskPollInterval), also after a restart mid-payment.

  @override
  void dispose() {
    _otp.dispose();
    _otpFocus.dispose();
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
      // Back to the code; the collection is kept. Clear, refocus and
      // vibrate (at-customer-and-otp.md §2.2). A network error keeps the
      // typed code (§2.3).
      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _collecting = false;
        _otp.clear();
      });
      _otpFocus.requestFocus();
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
    // Never confirm an unknown amount (RD-02): the button is not offered
    // without one, and this re-checks.
    final amount = codAmountText(_task);
    if (amount == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.codConfirmTitle(amount)),
        content: Text(l10n.codConfirmBody),
        actions: [
          TextButton(
            key: const Key('cod-cash-cancel'),
            // Focus starts on "Not yet" (cod.md §4).
            autofocus: true,
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.codConfirmNo),
          ),
          FilledButton(
            key: const Key('cod-cash-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.codConfirmYes(amount)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _confirmedAmount = _task.codAmountDue);
    await _deliver(const CodCollection.cash(cashConfirmed: true));
  }

  Future<void> _showQr() async {
    setState(() => _preferCash = false);
    await _controller.createCodQr();
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
    return TaskStepScaffold(
      task: task,
      title: l10n.otpStepTitle,
      bottomInBody: true,
      content: [
        Text(l10n.otpStepHelp, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        SizedBox(
          height: 64,
          child: TextField(
            key: const Key('delivery-otp'),
            controller: _otp,
            focusNode: _otpFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
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
        ),
        // The tries left come only from the server's `attempts_remaining`,
        // in the error line (taskErrorText), never counted on the phone.
      ],
      actions: PrimaryActionBar(
        quickRow: [
          OutlinedButton.icon(
            key: const Key('call-customer'),
            onPressed: _controller.callCustomer,
            icon: const Icon(Icons.call),
            label: Text(l10n.taskCallCustomer),
          ),
        ],
        exitLink: CantDeliverLink(
          onPressed: () => context.push(Routes.taskFail),
        ),
        buttonKey: Key(task.isCod ? 'otp-continue' : 'task-deliver'),
        label: task.isCod ? l10n.otpContinue : l10n.taskDeliver,
        busy: state.busy != null,
        onPressed: _otpComplete ? _continueFromOtp : null,
        errorKey: const Key('task-error'),
        error: taskStepError(context, state, action: TaskAction.deliver),
      ),
    );
  }

  /// A COD task without a usable amount (RD-02): no cash or UPI action,
  /// only Refresh, so the rider never confirms an unknown amount.
  Widget _amountMissing(
    BuildContext context,
    AppLocalizations l10n,
    TaskFlowState state,
    RiderTask task,
  ) => TaskStepScaffold(
    task: task,
    title: l10n.codTitle,
    content: [
      Container(
        key: const Key('cod-amount-missing'),
        padding: const EdgeInsets.all(16),
        decoration: riderCodDecoration(context),
        child: Text(
          l10n.codAmountMissing,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: RiderColors.of(context).codText),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const Key('cod-back'),
        onPressed: state.busy != null
            ? null
            : () => setState(() => _collecting = false),
        child: Text(l10n.codChangeOtp),
      ),
    ],
    actions: PrimaryActionBar(
      buttonKey: const Key('cod-refresh'),
      label: l10n.codRefresh,
      busy: state.busy != null || state.refreshing,
      onPressed: () => _controller.load(force: true),
      secondary: [
        if (_supportPhone case final phone?)
          OutlinedButton.icon(
            key: const Key('cod-call-support'),
            onPressed: () => ref
                .read(urlOpenerProvider)
                .open(Uri(scheme: 'tel', path: phone)),
            icon: const Icon(Icons.call),
            label: Text(l10n.callSupport),
          ),
      ],
    ),
  );

  /// `support.phone` from `config/app`, when set.
  String? get _supportPhone {
    final phone = ref.read(launchControllerProvider).config?.support.phone;
    return phone == null || phone.trim().isEmpty ? null : phone;
  }

  Widget _codStep(
    BuildContext context,
    AppLocalizations l10n,
    TaskFlowState state,
    RiderTask task,
  ) {
    final theme = Theme.of(context);
    final amount = codAmountText(task);
    final busy = state.busy != null;
    if (amount == null) return _amountMissing(context, l10n, state, task);
    final qr = task.codQr;
    final Widget actions;
    final showQr = qr != null && !_cashConfirmed && !_preferCash;
    if (showQr) {
      final paid = qr.status == UpiQrStatus.paid;
      final expired =
          qr.status == UpiQrStatus.expired ||
          qr.status == UpiQrStatus.cancelled;
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
            OutlinedButton(
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
        CodAmountChangedNotice(task: task),
        Container(
          key: const Key('cod-amount-block'),
          padding: const EdgeInsets.all(16),
          decoration: riderCodDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.codAmountDueLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: RiderColors.of(context).codText,
                ),
              ),
              if (codAmountWasText(task) case final was?)
                Semantics(
                  label: l10n.codAmountPreviously(was),
                  excludeSemantics: true,
                  child: Text(
                    was,
                    key: const Key('cod-amount-was'),
                    style: TextStyle(
                      fontSize: 20,
                      color: RiderColors.of(context).textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              Text(
                amount,
                key: const Key('cod-amount'),
                semanticsLabel: l10n.codAmountSemantics(amount),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: RiderColors.of(context).codText,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.codExactAmount,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: RiderColors.of(context).codText,
                ),
              ),
            ],
          ),
        ),
        if (_cashConfirmed) ...[
          const SizedBox(height: 16),
          ListTile(
            key: const Key('cod-cash-done'),
            leading: Icon(
              Icons.check_circle,
              color: RiderColors.of(context).onlineBg,
            ),
            title: Text(l10n.codCashDone(amount)),
          ),
        ],
        if (showQr) ...[
          const SizedBox(height: 16),
          Center(child: _QrImage(url: qr.imageUrl)),
          Text(
            switch (qr.status) {
              UpiQrStatus.paid => l10n.codUpiPaid,
              UpiQrStatus.expired ||
              UpiQrStatus.cancelled => l10n.codUpiExpired,
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
    final colors = RiderColors.of(context);
    final phone = ref.watch(launchControllerProvider).config?.support.phone;
    final canCall = phone != null && phone.trim().isNotEmpty;
    final cantDeliver = CantDeliverLink(
      onPressed: () => context.push(Routes.taskFail),
    );
    return TaskStepScaffold(
      task: task,
      title: l10n.otpLockedTitle,
      content: [
        Icon(Icons.lock, size: 72, color: colors.danger),
        const SizedBox(height: 16),
        Text(
          l10n.otpLockedHeading,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          canCall ? l10n.deliveryOtpLocked : l10n.deliveryOtpLockedNoPhone,
          key: const Key('otp-locked'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ],
      // Without a support phone there is no disabled button: only
      // "Can't deliver" (at-customer-and-otp.md §2.4).
      actions: canCall
          ? PrimaryActionBar(
              buttonKey: const Key('call-support'),
              label: l10n.callSupport,
              onPressed: () => ref
                  .read(urlOpenerProvider)
                  .open(Uri(scheme: 'tel', path: phone)),
              exitLink: cantDeliver,
            )
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: cantDeliver,
              ),
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
