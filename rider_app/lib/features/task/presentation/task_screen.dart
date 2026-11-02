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
import '../../../shared/widgets/sensitive_number_field.dart';
import '../../launch/presentation/blocking_message.dart';
import '../../launch/presentation/launch_controller.dart';
import '../data/fake_task_backend.dart';
import '../domain/rider_task.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';
import 'at_customer_step.dart';
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

/// Scaffold shared by the steps: title and order number, a refresh action,
/// pull to refresh, and the actions pinned at the bottom.
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
    final list = RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        key: const Key('task-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.taskOrderNumber(task.orderNumber),
            style: Theme.of(context).textTheme.labelLarge,
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
        body: bottomInBody
            ? Column(
                children: [
                  Expanded(child: list),
                  actions,
                ],
              )
            : list,
        bottomNavigationBar: bottomInBody ? null : actions,
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
          navigateKey: const Key('navigate-store'),
          onNavigate: () => openNavigation(
            context,
            ref,
            task.store.location,
            task.store.name,
          ),
        ),
        _ProgressChip(progress: task.storeProgress),
      ],
      actions: PrimaryActionBar(
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

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    ref.read(taskFlowControllerProvider.notifier).clearError();
    final code = await context.push<String>(Routes.taskScan);
    if (code == null || !mounted) return;
    _code.text = code;
    await ref.read(taskFlowControllerProvider.notifier).pickup(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final task = widget.task;
    final state = ref.watch(taskFlowControllerProvider);
    final controller = ref.read(taskFlowControllerProvider.notifier);
    return TaskStepScaffold(
      task: task,
      title: l10n.taskPickupTitle,
      bottomInBody: true,
      content: [
        _ProgressChip(progress: task.storeProgress),
        const SizedBox(height: 16),
        Text(l10n.taskItemsTitle, style: theme.textTheme.titleMedium),
        for (final item in task.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(
              '${item.quantity} ×',
              style: theme.textTheme.titleLarge,
            ),
            title: Text(item.name),
            subtitle: item.unit == null ? null : Text(item.unit!),
          ),
        const SizedBox(height: 16),
        Text(l10n.pickupCodeHelp, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        TextField(
          key: const Key('pickup-code'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
          inputFormatters: [
            const UpperCaseTextFormatter(),
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(kPickupCodeLength),
          ],
          decoration: InputDecoration(labelText: l10n.pickupCodeLabel),
          onChanged: (_) => controller.clearError(),
          onSubmitted: (_) => controller.pickup(_code.text),
        ),
      ],
      actions: PrimaryActionBar(
        buttonKey: const Key('task-pickup'),
        label: l10n.taskPickup,
        busy: state.busy != null,
        onPressed: () => controller.pickup(_code.text),
        errorKey: const Key('task-error'),
        error: taskStepError(context, state, action: TaskAction.pickup),
        secondary: [
          OutlinedButton.icon(
            key: const Key('pickup-scan'),
            onPressed: state.busy != null ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(l10n.pickupScan),
          ),
        ],
      ),
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
            navigateKey: const Key('navigate-customer'),
            onNavigate: () => openNavigation(
              context,
              ref,
              customer.location,
              customer.address,
            ),
            trailing: OutlinedButton.icon(
              key: const Key('call-customer'),
              onPressed: controller.callCustomer,
              icon: const Icon(Icons.call),
              label: Text(l10n.taskCallCustomer),
            ),
          ),
        if (task.isCod)
          Card(
            key: const Key('cod-banner'),
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.taskCollectCash(formatRupees(task.codAmountDue ?? '')),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
      ],
      actions: PrimaryActionBar(
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
        Text(l10n.taskReturnBody, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        _PlaceCard(
          icon: Icons.store,
          title: task.store.name,
          lines: [task.store.address],
          navigateKey: const Key('navigate-store'),
          onNavigate: () => openNavigation(
            context,
            ref,
            task.store.location,
            task.store.name,
          ),
        ),
      ],
      actions: PrimaryActionBar(
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

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.icon,
    required this.title,
    required this.lines,
    required this.navigateKey,
    required this.onNavigate,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final Key navigateKey;
  final VoidCallback onNavigate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: theme.textTheme.bodyLarge),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: navigateKey,
              onPressed: onNavigate,
              icon: const Icon(Icons.navigation),
              label: Text(l10n.taskNavigate),
            ),
            if (trailing != null) ...[const SizedBox(height: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.progress});

  final StoreOrderProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = progress != StoreOrderProgress.packing;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Chip(
        key: const Key('task-store-progress'),
        avatar: Icon(ready ? Icons.inventory_2 : Icons.hourglass_top),
        label: Text(ready ? l10n.taskOrderReady : l10n.taskOrderPacking),
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
            key: const Key('dev-returned'),
            onPressed: () => act(repository.markReturned),
            child: Text(l10n.devReturnReceived),
          ),
        ],
      ),
    );
  }
}
