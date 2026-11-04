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
import '../../../shared/widgets/sensitive_number_field.dart';
import '../../launch/presentation/blocking_message.dart';
import '../../launch/presentation/launch_controller.dart';
import '../data/fake_task_backend.dart';
import '../domain/rider_task.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';
import 'at_customer_step.dart';
import 'cod_amount_changed_notice.dart';
import 'task_flow_controller.dart';
import 'task_providers.dart';
import 'task_text.dart';

/// The current task, one step per screen (04 §2.5–§2.6, screens 10–14). The
/// step always follows the task state the server reported last.
class TaskScreen extends ConsumerWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskFlowControllerProvider);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    final task = state.task;

    if (state.notice == TaskNotice.unassigned) {
      return _EndScreen(
        icon: Icons.swap_horiz,
        title: l10n.taskUnassignedTitle,
        body: l10n.taskUnassignedBody,
        onDone: controller.finish,
      );
    }
    if (state.notice == TaskNotice.unconfirmed) {
      return const _UnconfirmedScreen();
    }
    if (task == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return switch (task.status) {
      TaskStatus.assigned => _GoToStoreStep(task: task),
      TaskStatus.atStore => _PickupStep(task: task),
      TaskStatus.pickedUp => _GoToCustomerStep(task: task),
      TaskStatus.atCustomer => AtCustomerStep(
        key: ValueKey(task.id),
        task: task,
      ),
      TaskStatus.delivered => _EndScreen(
        icon: Icons.check_circle,
        title: l10n.taskDeliveredTitle,
        body: task.payout == null
            ? l10n.taskDeliveredBody
            : l10n.taskDeliveredEarned(formatRupees(task.payout!)),
        onDone: controller.finish,
      ),
      TaskStatus.failed || TaskStatus.returning => _ReturnStep(task: task),
      TaskStatus.returned => _EndScreen(
        icon: Icons.assignment_return,
        title: l10n.taskReturnedTitle,
        body: l10n.taskReturnedBody,
        onDone: controller.finish,
      ),
      TaskStatus.cancelled => _EndScreen(
        icon: Icons.cancel_outlined,
        title: l10n.taskCancelledTitle,
        body: l10n.taskCancelledBody,
        onDone: controller.finish,
      ),
      _ => _EndScreen(
        icon: Icons.help_outline,
        title: l10n.taskUnknownTitle,
        body: l10n.taskUnknownBody,
        onDone: controller.load,
        doneLabel: l10n.retry,
      ),
    };
  }
}

/// Scaffold shared by the steps (`design/screens/rider/task-step-shell.md`):
/// title and order number (18 sp / 700), the offline banner after a network
/// error, a refresh action, pull to refresh, and the actions pinned at the
/// bottom. After a network error the primary reads "Try again: {label}"
/// until the next success (shell §3).
class TaskStepScaffold extends ConsumerWidget {
  const TaskStepScaffold({
    required this.task,
    required this.title,
    required this.content,
    required this.actions,
    this.bottomInBody = false,
    super.key,
  });

  final RiderTask task;
  final String title;
  final List<Widget> content;
  final Widget actions;

  /// Keep the actions above the keyboard (steps with a text field).
  final bool bottomInBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    final offline = ref.watch(
      taskFlowControllerProvider.select((s) => isNetworkError(s.error)),
    );
    final list = RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        key: const Key('task-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.taskOrderNumber(task.orderNumber),
            key: const Key('task-order-number'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...content,
          const _DevTaskTools(),
        ],
      ),
    );
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(title, key: const Key('task-title')),
          actions: [
            IconButton(
              key: const Key('task-refresh'),
              tooltip: l10n.taskRefresh,
              onPressed: controller.load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (offline) const _OfflineBanner(),
            Expanded(child: list),
            if (bottomInBody)
              PrimaryActionRetry(retrying: offline, child: actions),
          ],
        ),
        bottomNavigationBar: bottomInBody
            ? null
            : PrimaryActionRetry(retrying: offline, child: actions),
      ),
    );
  }
}

/// The last request failed for lack of network (shell §3).
bool isNetworkError(ApiError? error) =>
    error != null &&
    (error.code == ApiErrorCode.network || error.code == ApiErrorCode.timeout);

/// "No internet. Your progress is saved on Jivo's server; ..." (shell §3).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final colors = RiderColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('task-offline-banner'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.codBg,
          border: Border(
            bottom: BorderSide(
              color: colors.codBorder,
              width: RiderColors.borderWidth,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wifi_off, color: colors.codText),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.of(context).taskOfflineBanner,
                style: TextStyle(fontSize: 16, color: colors.codText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The last action error (server or local) for the bottom bar.
String? taskStepError(
  BuildContext context,
  TaskFlowState state, {
  TaskAction? action,
}) {
  final error = state.error;
  if (error != null) return taskErrorText(context, error, action: action);
  final local = state.localError;
  return local == null
      ? null
      : taskLocalErrorText(AppLocalizations.of(context), local);
}

Future<void> openNavigation(
  BuildContext context,
  WidgetRef ref,
  GeoPoint to,
  String label,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final text = AppLocalizations.of(context).taskNoMapsApp;
  final opened = await ref
      .read(navigationLauncherProvider)
      .navigateTo(to, label: label);
  if (!opened) messenger.showSnackBar(SnackBar(content: Text(text)));
}

class _GoToStoreStep extends ConsumerWidget {
  const _GoToStoreStep({required this.task});

  final RiderTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskFlowControllerProvider);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    return TaskStepScaffold(
      task: task,
      title: l10n.taskGoToStoreTitle,
      content: [
        _PlaceCard(
          icon: Icons.store,
          title: task.store.name,
          lines: [task.store.address],
        ),
        StoreStatusBanner(progress: task.storeProgress),
      ],
      actions: PrimaryActionBar(
        // Navigate sits in the sticky quick row (pickup.md §1, RD-07).
        quickRow: [
          _NavigateButton(
            buttonKey: const Key('navigate-store'),
            onPressed: () => openNavigation(
              context,
              ref,
              task.store.location,
              task.store.name,
            ),
          ),
        ],
        buttonKey: const Key('task-arrived-store'),
        label: l10n.taskArrivedStore,
        busy: state.busy != null,
        onPressed: controller.arrivedAtStore,
        errorKey: const Key('task-error'),
        error: taskStepError(context, state, action: TaskAction.arrivedStore),
      ),
    );
  }
}

class _PickupStep extends ConsumerStatefulWidget {
  const _PickupStep({required this.task});

  final RiderTask task;

  @override
  ConsumerState<_PickupStep> createState() => _PickupStepState();
}

class _PickupStepState extends ConsumerState<_PickupStep> {
  final _code = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    ref.read(taskFlowControllerProvider.notifier).clearError();
    final code = await context.push<String>(Routes.taskScan);
    if (code == null || !mounted) return;
    setState(() => _code.text = code);
    await _confirm(code);
  }

  Future<void> _confirm(String code) async {
    final controller = ref.read(taskFlowControllerProvider.notifier);
    await controller.pickup(code);
    if (!mounted) return;
    final error = ref.read(taskFlowControllerProvider).error;
    if (error != null && error.code == ApiErrorCode.validationError) {
      // Wrong code: select it all so typing replaces it (pickup.md §2).
      unawaited(HapticFeedback.mediumImpact());
      _code.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _code.text.length,
      );
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = RiderColors.of(context);
    final task = widget.task;
    final state = ref.watch(taskFlowControllerProvider);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    final busy = state.busy != null;
    final length = _code.text.length;
    final complete = length == kPickupCodeLength;

    final scanButtonLabel = Text(l10n.pickupScan);
    const scanIcon = Icon(Icons.qr_code_scanner);

    final PrimaryActionBar actions;
    if (complete) {
      actions = PrimaryActionBar(
        buttonKey: const Key('task-pickup'),
        label: l10n.taskPickup,
        busy: busy,
        onPressed: () => _confirm(_code.text),
        errorKey: const Key('task-error'),
        error: taskStepError(context, state, action: TaskAction.pickup),
        secondary: [
          OutlinedButton.icon(
            key: const Key('pickup-scan'),
            onPressed: busy ? null : _scan,
            icon: scanIcon,
            label: scanButtonLabel,
          ),
        ],
      );
    } else {
      final error = taskStepError(context, state, action: TaskAction.pickup);
      actions = PrimaryActionBar(
        buttonKey: const Key('pickup-scan'),
        label: l10n.pickupScan,
        busy: busy,
        onPressed: _scan,
        errorKey: const Key('task-error'),
        error: error,
        hint: length > 0
            ? l10n.pickupEnterAll
            : (task.storeProgress == StoreOrderProgress.packing
                  ? l10n.pickupNotPacked
                  : null),
        secondary: [
          if (length == 0)
            OutlinedButton(
              key: const Key('pickup-type'),
              onPressed: busy ? null : _focus.requestFocus,
              child: Text(l10n.pickupTypeCode),
            ),
        ],
      );
    }

    return TaskStepScaffold(
      task: task,
      title: l10n.taskPickupTitle,
      bottomInBody: true,
      content: [
        StoreStatusBanner(progress: task.storeProgress),
        const SizedBox(height: 16),
        Text(l10n.pickupCodeHelp, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: TextField(
            key: const Key('pickup-code'),
            controller: _code,
            focusNode: _focus,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 8,
            ),
            inputFormatters: [
              const UpperCaseTextFormatter(),
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(kPickupCodeLength),
            ],
            decoration: InputDecoration(labelText: l10n.pickupCodeLabel),
            onChanged: (_) {
              controller.clearError();
              setState(() {});
            },
            onSubmitted: (value) {
              if (value.length == kPickupCodeLength) _confirm(value);
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.pickupCheckBag(task.items.length),
          style: theme.textTheme.titleMedium,
        ),
        for (final item in task.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    '${item.quantity} ×',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontSize: 18)),
                      if (item.unit != null)
                        Text(
                          item.unit!,
                          style: TextStyle(
                            fontSize: 16,
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      actions: actions,
    );
  }
}

class _GoToCustomerStep extends ConsumerWidget {
  const _GoToCustomerStep({required this.task});

  final RiderTask task;

  Future<void> _override(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.arrivedOverrideTitle)),
            for (final (key, text) in [
              ('PIN_WRONG', l10n.arrivedOverridePinWrong),
              ('GATE_OR_LOBBY', l10n.arrivedOverrideGate),
            ])
              ListTile(
                key: Key('override-$key'),
                minTileHeight: 56,
                title: Text(text),
                onTap: () => Navigator.of(sheet).pop(key),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    await ref
        .read(taskFlowControllerProvider.notifier)
        .arrivedAtCustomer(overrideReason: reason);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskFlowControllerProvider);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    final customer = task.customer;
    final outside = state.error?.code == ApiErrorCode.outsideGeofence;
    return TaskStepScaffold(
      task: task,
      title: l10n.taskGoToCustomerTitle,
      content: [
        if (customer != null)
          _PlaceCard(
            icon: Icons.person_pin_circle,
            title: customer.name,
            lines: [
              customer.address,
              if (customer.landmark != null)
                l10n.taskLandmark(customer.landmark!),
              if (customer.instructions != null)
                l10n.taskInstructions(customer.instructions!),
            ],
          ),
        if (task.isCod) ...[
          CodAmountChangedNotice(task: task),
          Container(
            key: const Key('cod-banner'),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: riderCodDecoration(context),
            child: Text(
              switch (codAmountText(task)) {
                final amount? => l10n.taskCollectCash(amount),
                null => l10n.codAmountMissing,
              },
              style: TextStyle(
                fontSize: 22,
                color: RiderColors.of(context).codText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
      actions: PrimaryActionBar(
        // Navigate and Call in the sticky quick row (RD-07).
        quickRow: [
          if (customer != null)
            _NavigateButton(
              buttonKey: const Key('navigate-customer'),
              onPressed: () => openNavigation(
                context,
                ref,
                customer.location,
                customer.address,
              ),
            ),
          OutlinedButton.icon(
            key: const Key('call-customer'),
            onPressed: controller.callCustomer,
            icon: const Icon(Icons.call),
            label: Text(l10n.taskCallCustomer),
          ),
        ],
        exitLink: CantDeliverLink(
          onPressed: () => context.push(Routes.taskFail),
        ),
        buttonKey: const Key('task-arrived-customer'),
        label: l10n.taskArrivedCustomer,
        busy: state.busy != null,
        onPressed: controller.arrivedAtCustomer,
        errorKey: const Key('task-error'),
        error: taskStepError(
          context,
          state,
          action: TaskAction.arrivedCustomer,
        ),
        secondary: [
          if (outside)
            OutlinedButton(
              key: const Key('arrived-override'),
              onPressed: () => _override(context, ref),
              child: Text(l10n.arrivedOverride),
            ),
        ],
      ),
    );
  }
}

class _ReturnStep extends ConsumerWidget {
  const _ReturnStep({required this.task});

  final RiderTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskFlowControllerProvider);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    return TaskStepScaffold(
      task: task,
      title: l10n.taskReturnTitle,
      content: [
        Container(
          key: const Key('return-notice'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: RiderColors.of(context).neutralContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.assignment_return, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.taskReturnBody,
                      style: const TextStyle(fontSize: 18),
                    ),
                    // Just at the door with a COD amount (fail-and-return.md
                    // §2): say so plainly.
                    if (task.isCod) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.taskReturnNoCash,
                        key: const Key('return-no-cash'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _PlaceCard(
          icon: Icons.store,
          title: task.store.name,
          lines: [task.store.address],
        ),
      ],
      actions: PrimaryActionBar(
        quickRow: [
          _NavigateButton(
            buttonKey: const Key('navigate-store'),
            onPressed: () => openNavigation(
              context,
              ref,
              task.store.location,
              task.store.name,
            ),
          ),
        ],
        buttonKey: const Key('task-check'),
        label: l10n.taskCheckStatus,
        busy: state.refreshing,
        onPressed: controller.load,
      ),
    );
  }
}

/// The last step's answer was lost and the server no longer lists the task
/// (it may have been delivered). Neutral: check again, or ask support.
class _UnconfirmedScreen extends ConsumerWidget {
  const _UnconfirmedScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskFlowControllerProvider);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    final phone = ref.watch(launchControllerProvider).config?.support.phone;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlockingMessage(
          icon: Icons.help_outline,
          title: l10n.taskUnconfirmedTitle,
          body: l10n.taskUnconfirmedBody,
          actions: [
            FilledButton(
              key: const Key('task-check'),
              onPressed: state.refreshing ? null : controller.load,
              child: Text(l10n.taskCheckStatus),
            ),
            if (phone != null && phone.trim().isNotEmpty)
              OutlinedButton.icon(
                key: const Key('call-support'),
                onPressed: () => ref
                    .read(urlOpenerProvider)
                    .open(Uri(scheme: 'tel', path: phone)),
                icon: const Icon(Icons.call),
                label: Text(l10n.callSupport),
              ),
            TextButton(
              key: const Key('task-done'),
              onPressed: controller.finish,
              child: Text(l10n.taskBackToOrders),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndScreen extends StatelessWidget {
  const _EndScreen({
    required this.icon,
    required this.title,
    required this.body,
    required this.onDone,
    this.doneLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onDone;
  final String? doneLabel;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: BlockingMessage(
        icon: icon,
        title: title,
        body: body,
        actions: [
          FilledButton(
            key: const Key('task-done'),
            onPressed: onDone,
            child: Text(doneLabel ?? AppLocalizations.of(context).done),
          ),
        ],
      ),
    ),
  );
}

/// A store or customer: name 20 sp / 600, address lines 18 sp. Navigate and
/// Call live in the step's quick row, not in the card (RD-07).
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colors = RiderColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: colors.textPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: const TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavigateButton extends StatelessWidget {
  const _NavigateButton({required this.buttonKey, required this.onPressed});

  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: buttonKey,
    onPressed: onPressed,
    icon: const Icon(Icons.navigation),
    label: Text(AppLocalizations.of(context).taskNavigate),
  );
}

/// "Can't deliver…" (task-step shell §1): a 48 dp text button with the
/// `report` icon, kept 24 dp away from the primary action.
class CantDeliverLink extends StatelessWidget {
  const CantDeliverLink({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const Key('task-cant-deliver'),
    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    onPressed: onPressed,
    icon: const Icon(Icons.report),
    label: Text(AppLocalizations.of(context).taskCantDeliver),
  );
}

/// "Store is packing: wait here" / "Ready for pickup" (pickup.md §3), in
/// words with an icon. Announced when it changes (the push arrives too).
class StoreStatusBanner extends StatelessWidget {
  const StoreStatusBanner({required this.progress, super.key});

  final StoreOrderProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final ready = progress != StoreOrderProgress.packing;
    final (bg, fg) = ready
        ? (colors.onlineBg, colors.onlineFg)
        : (colors.neutralContainer, colors.textPrimary);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('task-store-progress'),
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              ready ? Icons.inventory_2 : Icons.hourglass_top,
              size: 28,
              color: fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                ready ? l10n.taskOrderReady : l10n.taskOrderPacking,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dev flavor with the fake only: plays the store and ops (packed, return
/// received, cancelled) so the flow can be walked through on a phone.
class _DevTaskTools extends ConsumerWidget {
  const _DevTaskTools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(taskRepositoryProvider);
    if (!ref.watch(appEnvProvider).showDevTools ||
        repository is! FakeTaskBackend) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    void act(void Function() change) {
      change();
      controller.load();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Wrap(
        spacing: 8,
        children: [
          TextButton(
            key: const Key('dev-packed'),
            onPressed: () => act(repository.markPacked),
            child: Text(l10n.devMarkPacked),
          ),
          TextButton(
            key: const Key('dev-cancel'),
            onPressed: () => act(repository.cancelOrder),
            child: Text(l10n.devCancelOrder),
          ),
          TextButton(
            key: const Key('dev-cod-changed'),
            onPressed: () => act(repository.changeCodAmount),
            child: Text(l10n.devCodAmountChanged),
          ),
          TextButton(
            key: const Key('dev-returned'),
            onPressed: () => act(repository.markReturned),
            child: Text(l10n.devReturnReceived),
          ),
        ],
      ),
    );
  }
}
