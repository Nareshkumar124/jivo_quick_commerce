import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/task/domain/task_status.dart';

typedef S = TaskStatus;

void main() {
  group('08 §3 transitions', () {
    // Every edge of the 08 §3 diagram, plus the ops reassignment in its prose.
    const edges = [
      (S.searching, S.offered),
      (S.offered, S.searching),
      (S.searching, S.unassigned),
      (S.unassigned, S.assigned),
      (S.unassigned, S.searching),
      (S.offered, S.assigned),
      (S.assigned, S.atStore),
      (S.atStore, S.pickedUp),
      (S.pickedUp, S.atCustomer),
      (S.atCustomer, S.delivered),
      (S.pickedUp, S.failed),
      (S.atCustomer, S.failed),
      (S.failed, S.returning),
      (S.returning, S.returned),
      (S.searching, S.cancelled),
      (S.offered, S.cancelled),
      (S.assigned, S.cancelled),
      (S.atStore, S.cancelled),
      (S.assigned, S.searching),
      (S.atStore, S.searching),
    ];

    test('every diagram edge is allowed', () {
      for (final (from, to) in edges) {
        expect(from.canTransitionTo(to), isTrue, reason: '$from → $to');
      }
    });

    test('nothing else is allowed (the table is exactly the diagram)', () {
      var allowed = 0;
      for (final from in S.values) {
        for (final to in S.values) {
          final expected = edges.contains((from, to));
          expect(from.canTransitionTo(to), expected, reason: '$from → $to');
          if (expected) allowed++;
        }
      }
      expect(allowed, edges.length);
    });

    test('representative illegal transitions', () {
      // Skipping the store.
      expect(S.assigned.canTransitionTo(S.pickedUp), isFalse);
      // Cancelling after pickup (that is a failed delivery, T13).
      expect(S.pickedUp.canTransitionTo(S.cancelled), isFalse);
      expect(S.atCustomer.canTransitionTo(S.cancelled), isFalse);
      // Delivering before arriving, or straight from the store.
      expect(S.pickedUp.canTransitionTo(S.delivered), isFalse);
      expect(S.atStore.canTransitionTo(S.atCustomer), isFalse);
      // Failing before pickup.
      expect(S.atStore.canTransitionTo(S.failed), isFalse);
      // Back from returned, or out of any terminal state.
      expect(S.returned.canTransitionTo(S.returning), isFalse);
      for (final terminal in [S.delivered, S.returned, S.cancelled]) {
        for (final to in S.values) {
          expect(terminal.canTransitionTo(to), isFalse, reason: '$terminal');
        }
      }
      // Doc gap kept as written: no UNASSIGNED → CANCELLED edge in 08 §3.
      expect(S.unassigned.canTransitionTo(S.cancelled), isFalse);
    });

    test('wire values round-trip; unknown values are unknown', () {
      for (final status in S.values.where((s) => s != S.unknown)) {
        expect(S.fromWire(status.wireValue), status);
      }
      expect(S.fromWire('PARKED'), S.unknown);
      expect(S.fromWire(null), S.unknown);
    });
  });

  group('rider view of the states', () {
    test('terminal states', () {
      expect(
        S.values.where((s) => s.isTerminal),
        unorderedEquals([S.delivered, S.returned, S.cancelled]),
      );
    });

    test('dispatch-only states are not the rider\'s task', () {
      for (final s in [S.searching, S.offered, S.unassigned, S.unknown]) {
        expect(s.isRiderTask, isFalse, reason: '$s');
      }
    });

    test('an active task blocks logout and going offline; a finished one '
        'does not', () {
      for (final s in [
        S.assigned,
        S.atStore,
        S.pickedUp,
        S.atCustomer,
        S.failed,
        S.returning,
      ]) {
        expect(s.blocksGoingOffline, isTrue, reason: '$s');
      }
      for (final s in [S.delivered, S.returned, S.cancelled, S.searching]) {
        expect(s.blocksGoingOffline, isFalse, reason: '$s');
      }
    });
  });

  group('actions', () {
    test('each action is allowed only in its 08 §3 state(s)', () {
      final expected = {
        TaskAction.arrivedStore: {S.assigned},
        TaskAction.pickup: {S.atStore},
        TaskAction.arrivedCustomer: {S.pickedUp},
        TaskAction.codQr: {S.atCustomer},
        TaskAction.deliver: {S.atCustomer},
        TaskAction.fail: {S.pickedUp, S.atCustomer},
      };
      for (final MapEntry(key: action, value: states) in expected.entries) {
        for (final status in S.values) {
          expect(
            action.allowedIn(status),
            states.contains(status),
            reason: '$action in $status',
          );
        }
      }
    });

    test('every state-changing action follows a diagram edge', () {
      for (final action in TaskAction.values) {
        final to = action.leadsTo;
        if (to == null) continue;
        for (final from in action.allowedFrom) {
          expect(from.canTransitionTo(to), isTrue, reason: '$action');
        }
      }
    });
  });
}
