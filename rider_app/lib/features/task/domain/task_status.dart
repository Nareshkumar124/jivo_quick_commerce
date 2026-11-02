/// Delivery task states (08 §3). The server owns every transition; the app
/// uses this table to show only the actions that are valid now and to never
/// call an endpoint from the wrong state.
enum TaskStatus {
  searching('SEARCHING'),
  offered('OFFERED'),
  assigned('ASSIGNED'),
  atStore('AT_STORE'),
  pickedUp('PICKED_UP'),
  atCustomer('AT_CUSTOMER'),
  delivered('DELIVERED'),
  failed('FAILED'),
  returning('RETURNING'),
  returned('RETURNED'),
  unassigned('UNASSIGNED'),
  cancelled('CANCELLED'),

  /// A value this app version does not know.
  unknown('');

  const TaskStatus(this.wireValue);

  final String wireValue;

  static TaskStatus fromWire(String? value) {
    for (final status in values) {
      if (status != unknown && status.wireValue == value) return status;
    }
    return unknown;
  }

  /// Nothing can follow these states.
  bool get isTerminal => switch (this) {
    TaskStatus.delivered || TaskStatus.returned || TaskStatus.cancelled => true,
    _ => false,
  };

  /// States in which the task belongs to a rider: the rider app shows it and
  /// blocks logout and going offline (agent rule 7). Terminal states are
  /// still shown until the rider acknowledges them.
  bool get isRiderTask => switch (this) {
    TaskStatus.assigned ||
    TaskStatus.atStore ||
    TaskStatus.pickedUp ||
    TaskStatus.atCustomer ||
    TaskStatus.delivered ||
    TaskStatus.failed ||
    TaskStatus.returning ||
    TaskStatus.returned ||
    TaskStatus.cancelled => true,
    TaskStatus.searching ||
    TaskStatus.offered ||
    TaskStatus.unassigned ||
    TaskStatus.unknown => false,
  };

  /// The rider is on the job: logout and going offline are blocked.
  bool get blocksGoingOffline => isRiderTask && !isTerminal;

  /// Whether 08 §3 allows going from this state to [next].
  bool canTransitionTo(TaskStatus next) =>
      taskTransitions[this]?.contains(next) ?? false;
}

/// The 08 §3 state diagram, exactly, plus the ops reassignment in its prose
/// ("ops may unassign a rider in ASSIGNED/AT_STORE ... back to SEARCHING").
///
/// Doc gap (reported, not added): the diagram has no UNASSIGNED → CANCELLED,
/// although an order with an unassigned task can be cancelled (T11/T12).
const Map<TaskStatus, Set<TaskStatus>> taskTransitions = {
  TaskStatus.searching: {
    TaskStatus.offered,
    TaskStatus.unassigned,
    TaskStatus.cancelled,
  },
  TaskStatus.offered: {
    TaskStatus.searching,
    TaskStatus.assigned,
    TaskStatus.cancelled,
  },
  TaskStatus.unassigned: {TaskStatus.assigned, TaskStatus.searching},
  TaskStatus.assigned: {
    TaskStatus.atStore,
    TaskStatus.cancelled,
    TaskStatus.searching,
  },
  TaskStatus.atStore: {
    TaskStatus.pickedUp,
    TaskStatus.cancelled,
    TaskStatus.searching,
  },
  TaskStatus.pickedUp: {TaskStatus.atCustomer, TaskStatus.failed},
  TaskStatus.atCustomer: {TaskStatus.delivered, TaskStatus.failed},
  TaskStatus.failed: {TaskStatus.returning},
  TaskStatus.returning: {TaskStatus.returned},
  TaskStatus.delivered: {},
  TaskStatus.returned: {},
  TaskStatus.cancelled: {},
  TaskStatus.unknown: {},
};

/// What the rider can do on a task, and the states each action is valid in.
enum TaskAction {
  /// `POST /rider/tasks/{id}/arrived-store/` → AT_STORE.
  arrivedStore({TaskStatus.assigned}, TaskStatus.atStore),

  /// `POST /rider/tasks/{id}/pickup/` → PICKED_UP (order must be PACKED).
  pickup({TaskStatus.atStore}, TaskStatus.pickedUp),

  /// `POST /rider/tasks/{id}/arrived-customer/` → AT_CUSTOMER.
  arrivedCustomer({TaskStatus.pickedUp}, TaskStatus.atCustomer),

  /// `POST /rider/tasks/{id}/cod-qr/` (no state change).
  codQr({TaskStatus.atCustomer}, null),

  /// `POST /rider/tasks/{id}/deliver/` → DELIVERED.
  deliver({TaskStatus.atCustomer}, TaskStatus.delivered),

  /// `POST /rider/tasks/{id}/fail/` → FAILED, then RETURNING (T13).
  fail({TaskStatus.pickedUp, TaskStatus.atCustomer}, TaskStatus.failed);

  const TaskAction(this.allowedFrom, this.leadsTo);

  final Set<TaskStatus> allowedFrom;

  /// The state the server moves the task to, or null for no change.
  final TaskStatus? leadsTo;

  bool allowedIn(TaskStatus status) => allowedFrom.contains(status);
}
