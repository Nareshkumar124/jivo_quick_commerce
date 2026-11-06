import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../shared/errors/rider_error_codes.dart';
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

  /// `PICKUP_CODE_LOCKED` was answered for this task: no more tries from
  /// the phone (the store or ops hand the order over).
  pickupLocked,

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
    this.pickupAttemptsRemaining,
    this.pickupLocked = false,
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

  /// From the last `PICKUP_CODE_INVALID` (`attempts_remaining`) for this
  /// task; null before any wrong code.
  ///
  /// TODO(api): `RiderTask` does not carry the pickup-code attempts, so a
  /// restart forgets them until the next answer (reported as an API gap).
  final int? pickupAttemptsRemaining;

  /// `PICKUP_CODE_LOCKED` answered for this task.
  final bool pickupLocked;

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
    int? pickupAttemptsRemaining,
    bool? pickupLocked,
    bool resetPickup = false,
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
    pickupAttemptsRemaining: resetPickup
        ? null
        : pickupAttemptsRemaining ?? this.pickupAttemptsRemaining,
    pickupLocked: resetPickup ? false : pickupLocked ?? this.pickupLocked,
  );
}

/// Whether the task screen polls `GET /rider/tasks/current/` while in the
/// foreground ([taskPollInterval]). Tests that do not exercise polling may
/// turn it off.
final taskPollingEnabledProvider = Provider<bool>((ref) => true);

final taskFlowControllerProvider =
    NotifierProvider<TaskFlowController, TaskFlowState>(TaskFlowController.new);

/// The rider's delivery task, step by step (04 §2.5–§2.6, 08 §3).
///
/// - Restores the exact step from `GET /rider/tasks/current/` when an ACTIVE
///   rider opens the app and every time it comes back to the foreground, so
///   a crash or restart mid-delivery resumes instead of resetting.
/// - Calls an endpoint only from a state where 08 §3 allows the action.
/// - Polls the current task while the app is in the foreground
///   ([taskPollInterval]): the fallback for pushes that never came (store
///   packed, UPI paid, items received back, ops cancelled).
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
    _foreground = true;
    final lifecycle = AppLifecycleListener(
      onResume: () {
        _foreground = true;
        unawaited(load());
      },
      onHide: _stopPolling,
      onPause: _stopPolling,
    );
    ref.onDispose(() {
      lifecycle.dispose();
      _pollTimer?.cancel();
      _pollTimer = null;
    });
    Future.microtask(load);
    return const TaskFlowState();
  }

  Timer? _pollTimer;
  bool _foreground = true;

  void _stopPolling() {
    _foreground = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Re-arms the poll for the task now on screen (one timer at a time).
  void _armPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (!ref.mounted || !_foreground) return;
    if (!ref.read(taskPollingEnabledProvider)) return;
    final interval = taskPollInterval(state.task);
    if (interval == null) return;
    _pollTimer = Timer(interval, () {
      _pollTimer = null;
      if (!ref.mounted) return;
      // An action in flight answers for itself.
      if (state.busy != null) {
        _armPoll();
        return;
      }
      unawaited(load());
    });
  }

  bool get _active => ref.mounted && ref.read(riderWorkActiveProvider);

  /// `GET /rider/tasks/current/` and show that step. [force] runs it even
  /// while another refresh is in flight (after an uncertain accept, the
  /// caller must see this fetch's answer).
  Future<void> load({bool force = false}) async {
    if (!_active || (state.refreshing && !force)) return;
    state = state.copyWith(refreshing: true);
    try {
      final current = await _repo.fetchCurrentTask();
      if (!ref.mounted) return;
      _applyFetched(current);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return;
      reportAppControlError(ref, error);
      // Keep what is on screen; the next resume or Retry tries again.
      state = state.copyWith(refreshing: false, loaded: true);
      debugPrint('TaskFlowController.load: ${error.code}');
    } finally {
      _armPoll();
    }
  }

  /// Shows [fetched]. [afterUncertain] is the step-changing action whose
  /// answer was lost, when this fetch is its reconcile.
  void _applyFetched(CurrentTask answer, {TaskAction? afterUncertain}) {
    final current = state.task;
    final fetched = answer.task;
    final visible = fetched != null && fetched.status.isRiderTask;
    final recent = answer.recentTask;
    if (!visible &&
        current != null &&
        !current.status.isTerminal &&
        recent != null &&
        recent.id == current.id &&
        recent.status.isTerminal) {
      // The task just ended (delivered, items received back, cancelled):
      // show how, instead of a guess.
      final ended = current.copyWith(status: recent.status);
      _setTask(ended);
      state = state.copyWith(
        task: ended,
        refreshing: false,
        loaded: true,
        clearNotice: true,
        clearErrors: true,
      );
      return;
    }
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
      resetPickup: !sameTask,
    );
  }

  /// The offer was accepted: the task starts (ASSIGNED).
  void assigned(RiderTask task) {
    _setTask(task);
    state = TaskFlowState(loaded: true, task: task);
    _armPoll();
  }

  /// Arrived at the store: sends where the rider is; the server checks the
  /// geofence (`OUTSIDE_GEOFENCE`).
  Future<bool> arrivedAtStore() => _withLocation(
    TaskAction.arrivedStore,
    (task, at) => _repo.arrivedAtStore(task.id, at),
  );

  /// Picked up with the code typed, or the bag QR payload scanned
  /// (`JQC1:<order>:<code>`). The server checks it: 5 wrong codes lock it.
  Future<bool> pickup(String code) async {
    if (state.busy != null) return false;
    if (state.pickupLocked) {
      state = state.copyWith(
        clearErrors: true,
        localError: TaskLocalError.pickupLocked,
      );
      return false;
    }
    final scanned = parseScannedPickup(
      code,
      orderNumber: state.task?.orderNumber ?? '',
    );
    if (scanned is! ScannedCode) {
      state = state.copyWith(
        clearErrors: true,
        localError: TaskLocalError.invalidPickupCode,
      );
      return false;
    }
    return _run(
      TaskAction.pickup,
      (task) => _repo.pickup(task.id, scanned.orderCode),
    );
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
    final sent = FailReport(
      reason: report.reason,
      note: report.note.trim(),
      callAttempts: state.callAttempts,
      photo: report.photo,
    );
    return _run(TaskAction.fail, (task) => _repo.fail(task.id, sent));
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
    _armPoll();
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
      _armPoll();
      return true;
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return false;
      if (reportAppControlError(ref, error)) {
        state = state.copyWith(clearBusy: true);
        return false;
      }
      var latest = state.task ?? task;
      int? pickupLeft;
      var pickupLocked = false;
      switch (error.riderCode) {
        case RiderErrorCode.pickupCodeInvalid:
          pickupLeft = error.attemptsRemaining;
        case RiderErrorCode.pickupCodeLocked:
          pickupLeft = 0;
          pickupLocked = true;
        case RiderErrorCode.riderOffline || null:
          break;
      }
      final notReachableAfter = error.notReachableAfter;
      if (error.isWaitNotElapsed && notReachableAfter != null) {
        latest = latest.copyWith(notReachableAfter: notReachableAfter);
      }
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
      state = state.copyWith(
        task: latest,
        clearBusy: true,
        error: error,
        pickupAttemptsRemaining: pickupLeft,
        pickupLocked: pickupLocked ? true : null,
      );
      // The COD amount changed under the rider (400 with `amount_due`):
      // show the server's amount now; the error text says to collect it.
      final amountChanged = error.codAmountDueNow != null;
      if (_isUncertain(error) || amountChanged) {
        await _reconcile(task.status, action, keepError: amountChanged);
      }
      _armPoll();
      return false;
    }
  }

  /// The action may have gone through: show what the server has now. If
  /// the task moved on, the error no longer applies.
  Future<void> _reconcile(
    TaskStatus before,
    TaskAction action, {
    bool keepError = false,
  }) async {
    final error = state.error;
    try {
      final fetched = await _repo.fetchCurrentTask();
      if (!ref.mounted) return;
      _applyFetched(fetched, afterUncertain: action);
      if (keepError && state.task?.status == before && error != null) {
        state = state.copyWith(error: error);
      }
      if (state.task?.status != before) {
        state = state.copyWith(clearErrors: true);
      }
    } on Object catch (e) {
      debugPrint('TaskFlowController.reconcile: ${ApiError.from(e).code}');
    }
  }

  static bool _isUncertain(ApiError error) {
    // Rider codes the server answered on purpose are certain.
    if (error.riderCode != null) return false;
    // WAIT_NOT_ELAPSED: the task did not move; nothing to reconcile.
    if (error.isWaitNotElapsed) return false;
    return switch (error.code) {
      ApiErrorCode.network ||
      ApiErrorCode.timeout ||
      ApiErrorCode.serverError ||
      ApiErrorCode.unknown ||
      ApiErrorCode.invalidStateTransition => true,
      _ => false,
    };
  }

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
