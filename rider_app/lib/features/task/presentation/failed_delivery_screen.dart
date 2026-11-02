import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../onboarding/domain/image_compression.dart';
import '../../onboarding/domain/image_picking.dart';
import '../../onboarding/presentation/onboarding_providers.dart';
import '../domain/task_repositories.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';
import 'task_flow_controller.dart';
import 'task_screen.dart';

/// Failed delivery (04 §2.6, screen 13): a reason, a note, an optional
/// photo, then "Return to store" (T13: the task moves on to RETURNING).
/// "Customer not reachable" opens only after the calls and the 10-minute
/// wait at the address; the wait counts from the server's arrival time.
class FailedDeliveryScreen extends ConsumerStatefulWidget {
  const FailedDeliveryScreen({super.key});

  @override
  ConsumerState<FailedDeliveryScreen> createState() =>
      _FailedDeliveryScreenState();
}

class _FailedDeliveryScreenState extends ConsumerState<FailedDeliveryScreen> {
  final _note = TextEditingController();
  FailReason? _reason;
  Uint8List? _photo;
  bool _photoBusy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _note.dispose();
    super.dispose();
  }

  /// The photo goes straight through the picker and the compressor. It does
  /// not use the KYC capture flow, so a recovered photo can never end up in
  /// a KYC document.
  Future<void> _takePhoto() async {
    final picker = ref.read(kycImagePickerProvider);
    setState(() => _photoBusy = true);
    PickedImage? picked;
    try {
      picked = await picker.pick(ImagePickSource.camera, selfie: false);
      if (picked == null) return;
      final image = await compressToLimit(
        codec: ref.read(imageCodecProvider),
        sourcePath: picked.path,
      );
      if (mounted) setState(() => _photo = image.bytes);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failPhotoError)),
        );
      }
    } finally {
      if (picked != null) await picker.discard(picked);
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    final ok = await ref
        .read(taskFlowControllerProvider.notifier)
        .fail(
          FailReport(reason: reason, note: _note.text.trim(), photo: _photo),
        );
    if (ok && mounted && context.canPop()) context.pop();
  }

  String _reasonText(AppLocalizations l10n, FailReason reason) =>
      switch (reason) {
        FailReason.notReachable => l10n.failNotReachable,
        FailReason.refused => l10n.failRefused,
        FailReason.wrongAddress => l10n.failWrongAddress,
        FailReason.other => l10n.failOther,
      };

  String _mmss(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(taskFlowControllerProvider);
    final task = state.task;
    final controller = ref.read(taskFlowControllerProvider.notifier);
    if (task == null || !TaskAction.fail.allowedIn(task.status)) {
      return Scaffold(appBar: AppBar(title: Text(l10n.failTitle)));
    }
    final now = ref.read(clockProvider)();
    final waitLeft = notReachableWaitLeft(task, now);
    final reason = _reason;
    final block = reason == null
        ? null
        : failReasonBlock(
            reason: reason,
            task: task,
            callAttempts: state.callAttempts,
            now: now,
            note: _note.text,
          );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.failTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('fail-list'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(l10n.failIntro, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                RadioGroup<FailReason>(
                  groupValue: _reason,
                  onChanged: (value) {
                    controller.clearError();
                    setState(() => _reason = value);
                  },
                  child: Column(
                    children: [
                      for (final r in FailReason.values)
                        RadioListTile<FailReason>(
                          key: Key('fail-${r.wireValue}'),
                          value: r,
                          title: Text(_reasonText(l10n, r)),
                        ),
                    ],
                  ),
                ),
                if (reason == FailReason.notReachable) ...[
                  _Requirement(
                    key: const Key('fail-calls'),
                    done: state.callAttempts >= kMinCallAttempts,
                    text: l10n.failCallsNeeded(
                      kMinCallAttempts,
                      state.callAttempts,
                    ),
                    action: OutlinedButton.icon(
                      key: const Key('fail-call'),
                      onPressed: controller.callCustomer,
                      icon: const Icon(Icons.call),
                      label: Text(l10n.taskCallCustomer),
                    ),
                  ),
                  _Requirement(
                    key: const Key('fail-wait'),
                    done: waitLeft == Duration.zero,
                    text: waitLeft == null
                        ? l10n.failWaitNotArrived
                        : waitLeft == Duration.zero
                        ? l10n.failWaitDone
                        : l10n.failWaitLeft(_mmss(waitLeft)),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  key: const Key('fail-note'),
                  controller: _note,
                  maxLines: 2,
                  maxLength: 300,
                  decoration: InputDecoration(
                    labelText: reason == FailReason.other
                        ? l10n.failNoteRequired
                        : l10n.failNoteOptional,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (_photo == null)
                  OutlinedButton.icon(
                    key: const Key('fail-photo'),
                    onPressed: _photoBusy ? null : _takePhoto,
                    icon: const Icon(Icons.photo_camera),
                    label: Text(l10n.failAddPhoto),
                  )
                else
                  Row(
                    key: const Key('fail-photo-added'),
                    children: [
                      const Icon(Icons.image),
                      const SizedBox(width: 16),
                      Expanded(child: Text(l10n.failPhotoAdded)),
                      TextButton(
                        key: const Key('fail-photo-remove'),
                        onPressed: () => setState(() => _photo = null),
                        child: Text(l10n.failPhotoRemove),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          PrimaryActionBar(
            buttonKey: const Key('fail-submit'),
            label: l10n.failSubmit,
            busy: state.busy != null,
            onPressed: reason == null || block != null ? null : _submit,
            hint: reason == null ? l10n.failChooseReason : null,
            errorKey: const Key('task-error'),
            error: taskStepError(context, state, action: TaskAction.fail),
          ),
        ],
      ),
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.done,
    required this.text,
    this.action,
    super.key,
  });

  final bool done;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The action sits under the text: as a ListTile trailing it squeezed the
    // text into a narrow, very tall column on phone widths.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.schedule,
                color: done ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ],
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}
