import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../location/domain/tracking_config.dart';
import '../../location/presentation/location_debug_controller.dart';
import '../domain/rider_task.dart';
import '../domain/task_repositories.dart';
import '../domain/task_rules.dart';
import '../domain/task_status.dart';
import 'task_block.dart';
import 'task_providers.dart';

/// Problems found on the phone, before or instead of a server call.
enum TaskLocalError {
  /// The action is not valid in the current task state (no call made).
  notAllowed,

  /// No GPS fix for arrived-at-store / arrived-at-customer.
  locationUnavailable,

  /// The typed or scanned pickup code is not 4 letters or digits.
  invalidPickupCode,

  /// COD not collected or not confirmed ([CodProblem]).
  codIncomplete,

  /// "Not reachable" before the calls and the 10-minute wait, or "Other"
  /// without a note ([FailBlock]).
  failNotAllowedYet,
}

/// Shown when the task ended on the server side without the rider.
enum TaskNotice {
  /// Ops reassigned the order (08 §3): it is no longer this rider's.
  unassigned,

  /// A step-changing action (pickup, deliver, fail…) got no answer and the
  /// server no longer reports the task. It may have gone through (e.g. the
  /// delivery succeeded) or not: the app can't tell, so it says so instead
  /// of guessing "reassigned".
  unconfirmed,
}

@immutable
class TaskFlowState {
  const TaskFlowState({
    this.loaded = false,
    this.task,
    this.busy,
    this.refreshing = false,
    this.error,
    this.localError,
    this.notice,
    this.callAttempts = 0,
  });

  /// `GET /rider/tasks/current/` answered at least once.
  final bool loaded;
  final RiderTask? task;

  /// The action in flight (one at a time: double taps do nothing).
  final TaskAction? busy;
  final bool refreshing;

  /// The last server error of an action, shown on the task screen.
  final ApiError? error;
  final TaskLocalError? localError;
  final TaskNotice? notice;

  /// "Call customer" taps on this task. Kept on the phone only: a restart
  /// resets it (the wait timer comes from the server and does not reset).
  final int callAttempts;

  /// The task screen is the rider's screen (a task, or a notice to read).
  bool get hasTask => task != null || notice != null;

  /// Logout and going offline are blocked (agent rule 7).
  bool get blocksGoingOffline => task?.status.blocksGoingOffline ?? false;

  TaskFlowState copyWith({
    bool? loaded,
    RiderTask? task,
    bool clearTask = false,
    TaskAction? busy,
    bool clearBusy = false,
    bool? refreshing,
    ApiError? error,
    TaskLocalError? localError,
    bool clearErrors = false,
    TaskNotice? notice,
    bool clearNotice = false,
    int? callAttempts,
  }) => TaskFlowState(
    loaded: loaded ?? this.loaded,
    task: clearTask ? null : task ?? this.task,
    busy: clearBusy ? null : busy ?? this.busy,
    refreshing: refreshing ?? this.refreshing,
    // A new error replaces the old ones; clearErrors drops them.
    error: error ?? (clearErrors ? null : this.error),
    localError: localError ?? (clearErrors ? null : this.localError),
    notice: clearNotice ? null : notice ?? this.notice,
    callAttempts: callAttempts ?? this.callAttempts,
  );
}

final taskFlowControllerProvider =
    NotifierProvider<TaskFlowController, TaskFlowState>(TaskFlowController.new);

/// The rider's delivery task, step by step (04 §2.5–§2.6, 08 §3).
///
/// - Restores the exact step from `GET /rider/tasks/current/` when an ACTIVE
///   rider opens the app and every time it comes back to the foreground, so
///   a crash or restart mid-delivery resumes instead of resetting.
/// - Calls an endpoint only from a state where 08 §3 allows the action.
/// - Renders whatever the server answers. After an uncertain failure (no
///   network, timeout, server error, `INVALID_STATE_TRANSITION`) it asks the
///   server for the current task, because the action may have gone through
///   while the response was lost.
class TaskFlowController extends Notifier<TaskFlowState> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);

  @override
  TaskFlowState build() {
    final active = ref.watch(riderWorkActiveProvider);
    if (!active) {
      // Signed out or not ACTIVE: nothing blocks going offline.
      Future.microtask(() {
        if (ref.mounted) {
          ref.read(taskBlocksGoingOfflineProvider.notifier).set(false);
        }
      });
      return const TaskFlowState();
    }
    final lifecycle = AppLifecycleListener(onResume: () => unawaited(load()));
    ref.onDispose(lifecycle.dispose);
    Future.microtask(load);
    return const TaskFlowState();
  }

  bool get _active => ref.mounted && ref.read(riderWorkActiveProvider);

  /// `GET /rider/tasks/current/` and show that step. [force] runs it even
  /// while another refresh is in flight (after an uncertain accept, the
  /// caller must see this fetch's answer).
  Future<void> load({bool force = false}) async {
    if (!_active || (state.refreshing && !force)) return;
    state = state.copyWith(refreshing: true);
    try {
      final task = await _repo.fetchCurrentTask();
      if (!ref.mounted) return;
      _applyFetched(task);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return;
      reportAppControlError(ref, error);
      // Keep what is on screen; the next resume or Retry tries again.
      state = state.copyWith(refreshing: false, loaded: true);
      debugPrint('TaskFlowController.load: ${error.code}');
    }
  }

  /// Shows [fetched]. [afterUncertain] is the step-changing action whose
  /// answer was lost, when this fetch is its reconcile.
  void _applyFetched(RiderTask? fetched, {TaskAction? afterUncertain}) {
    final current = state.task;
    final visible = fetched != null && fetched.status.isRiderTask;
    if (!visible) {
      if (current != null && !current.status.isTerminal) {
        // The task is gone. After a lost answer to a step-changing action
        // that may simply mean it succeeded (e.g. delivered): don't claim a
        // reassignment.
        final unconfirmed = afterUncertain?.leadsTo != null;
        _setTask(null);
        state = state.copyWith(
          clearTask: true,
          refreshing: false,
          loaded: true,
          notice: unconfirmed ? TaskNotice.unconfirmed : TaskNotice.unassigned,
          clearErrors: true,
        );
      } else {
        // Nothing active, or a finished task waiting for "Done".
        state = state.copyWith(refreshing: false, loaded: true);
      }
      return;
    }
    final sameTask = current?.id == fetched.id;
    _setTask(fetched);
    state = state.copyWith(
      task: fetched,
      refreshing: false,
      loaded: true,
      clearNotice: true,
      callAttempts: sameTask ? state.callAttempts : 0,
    );
  }

  /// The offer was accepted: the task starts (ASSIGNED).
  void assigned(RiderTask task) {
    _setTask(task);
    state = TaskFlowState(loaded: true, task: task);
  }

  /// Arrived at the store: sends where the rider is; the server checks the
  /// geofence (`OUTSIDE_GEOFENCE`).
  Future<bool> arrivedAtStore() => _withLocation(
    TaskAction.arrivedStore,
    (task, at) => _repo.arrivedAtStore(task.id, at),
  );

  /// Picked up with the code typed or scanned from the bag.
  Future<bool> pickup(String code) async {
    final normalised = normalisePickupCode(code);
    if (normalised == null) {
      if (state.busy != null) return false;
      state = state.copyWith(
        clearErrors: true,
        localError: TaskLocalError.invalidPickupCode,
      );
      return false;
    }
    return _run(TaskAction.pickup, (task) => _repo.pickup(task.id, normalised));
  }

  /// Arrived at the customer. [overrideReason] when the pin is wrong and
  /// the server said `OUTSIDE_GEOFENCE` (04 §2.6).
  Future<bool> arrivedAtCustomer({String? overrideReason}) => _withLocation(
    TaskAction.arrivedCustomer,
    (task, at) =>
        _repo.arrivedAtCustomer(task.id, at, overrideReason: overrideReason),
  );

  /// A UPI QR for the COD amount.
  Future<bool> createCodQr() => _run(TaskAction.codQr, (task) async {
    final qr = await _repo.createCodQr(task.id);
    return task.copyWith(codQr: qr);
  });

  /// Delivered with the customer's OTP and, for COD, the collection. The
  /// amount sent is the server's amount due, unchanged.
  Future<bool> deliver({required String otp, CodCollection? collection}) {
    final task = state.task;
    if (task != null &&
        TaskAction.deliver.allowedIn(task.status) &&
        validateCodForDeliver(task, collection) != null) {
      state = state.copyWith(
        clearErrors: true,
        localError: TaskLocalError.codIncomplete,
      );
      return Future.value(false);
    }
    return _run(
      TaskAction.deliver,
      (task) => _repo.deliver(
        task.id,
        otp: otp,
        codMode: task.isCod ? collection?.mode : null,
        codAmount: task.isCod ? task.codAmountDue : null,
      ),
    );
  }

  /// Failed delivery (T13): the task moves on to RETURNING.
  Future<bool> fail(FailReport report) {
    final task = state.task;
    if (task != null &&
        TaskAction.fail.allowedIn(task.status) &&
        failReasonBlock(
              reason: report.reason,
              task: task,
              callAttempts: state.callAttempts,
              now: ref.read(clockProvider)(),
              note: report.note,
            ) !=
            null) {
      state = state.copyWith(
        clearErrors: true,
        localError: TaskLocalError.failNotAllowedYet,
      );
      return Future.value(false);
    }
    return _run(TaskAction.fail, (task) => _repo.fail(task.id, report));
  }

  /// Dials the customer (`tel:`; masked calling is v2) and counts the try.
  Future<bool> callCustomer() async {
    final phone = state.task?.customer?.phone;
    if (phone == null) return false;
    state = state.copyWith(callAttempts: state.callAttempts + 1);
    return ref.read(urlOpenerProvider).open(Uri(scheme: 'tel', path: phone));
  }

  /// The rider read how the task ended (delivered, returned, cancelled,
  /// reassigned): back to waiting for orders.
  void finish() {
    final task = state.task;
    if (task != null && !task.status.isTerminal) return;
    _setTask(null);
    state = const TaskFlowState(loaded: true);
  }

  void clearError() {
    if (state.error != null || state.localError != null) {
      state = state.copyWith(clearErrors: true);
    }
  }

  Future<bool> _withLocation(
    TaskAction action,
    Future<RiderTask> Function(RiderTask task, GeoPoint at) call,
  ) async {
    final task = state.task;
    if (task == null || state.busy != null || !action.allowedIn(task.status)) {
      return _notAllowed();
    }
    // Busy from the first tap until the server answered: a second tap
    // during the GPS read or the call does nothing.
    state = state.copyWith(busy: action, clearErrors: true);
    final GeoPoint at;
    try {
      at = await ref.read(currentLocationReaderProvider).current();
    } on Object {
      if (!ref.mounted) return false;
      state = state.copyWith(
        clearBusy: true,
        localError: TaskLocalError.locationUnavailable,
      );
      return false;
    }
    if (!ref.mounted) return false;
    return _perform(task, action, (task) => call(task, at));
  }

  Future<bool> _run(
    TaskAction action,
    Future<RiderTask> Function(RiderTask task) call,
  ) async {
    final task = state.task;
    if (task == null || state.busy != null || !action.allowedIn(task.status)) {
      return _notAllowed();
    }
    state = state.copyWith(busy: action, clearErrors: true);
    return _perform(task, action, call);
  }

  /// Runs [call] with [action] already marked busy, and clears it.
  Future<bool> _perform(
    RiderTask task,
    TaskAction action,
    Future<RiderTask> Function(RiderTask task) call,
  ) async {
    try {
      final updated = await call(task);
      if (!ref.mounted) return false;
      _setTask(updated);
      state = state.copyWith(task: updated, clearBusy: true);
      return true;
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return false;
      if (reportAppControlError(ref, error)) {
        state = state.copyWith(clearBusy: true);
        return false;
      }
      var latest = state.task ?? task;
      switch (error.code) {
        case ApiErrorCode.deliveryOtpInvalid:
          final left = error.attemptsRemaining;
          if (left != null) {
            latest = latest.copyWith(otpAttemptsRemaining: left);
          }
        case ApiErrorCode.deliveryOtpLocked:
          latest = latest.copyWith(otpLocked: true, otpAttemptsRemaining: 0);
        default:
          break;
      }
      state = state.copyWith(task: latest, clearBusy: true, error: error);
      if (_isUncertain(error)) await _reconcile(task.status, action);
      return false;
    }
  }

  /// The action may have gone through: show what the server has now. If
  /// the task moved on, the error no longer applies.
  Future<void> _reconcile(TaskStatus before, TaskAction action) async {
    try {
      final fetched = await _repo.fetchCurrentTask();
      if (!ref.mounted) return;
      _applyFetched(fetched, afterUncertain: action);
      if (state.task?.status != before) {
        state = state.copyWith(clearErrors: true);
      }
    } on Object catch (e) {
      debugPrint('TaskFlowController.reconcile: ${ApiError.from(e).code}');
    }
  }

  static bool _isUncertain(ApiError error) => switch (error.code) {
    ApiErrorCode.network ||
    ApiErrorCode.timeout ||
    ApiErrorCode.serverError ||
    ApiErrorCode.unknown ||
    ApiErrorCode.invalidStateTransition => true,
    _ => false,
  };

  bool _notAllowed() {
    if (state.busy == null) {
      state = state.copyWith(
        clearErrors: true,
        localError: TaskLocalError.notAllowed,
      );
    }
    return false;
  }

  /// GPS every 5–10 s while on a task, every 30 s otherwise (04 §3).
  void _setTask(RiderTask? task) {
    final onTask = task?.status.blocksGoingOffline ?? false;
    ref.read(taskBlocksGoingOfflineProvider.notifier).set(onTask);
    try {
      ref
          .read(locationServiceClientProvider)
          .setMode(onTask ? TrackingMode.onTask : TrackingMode.idle);
    } on Object catch (error) {
      debugPrint('TaskFlowController: setMode ${error.runtimeType}');
    }
  }
}
