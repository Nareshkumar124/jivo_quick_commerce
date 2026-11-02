import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/data/in_memory_point_store.dart';
import 'package:rider_app/features/location/domain/location_buffer.dart';

import '../../../helpers/location_fakes.dart';

void main() {
  group('LocationBuffer', () {
    late InMemoryPointStore store;
    late LocationBuffer buffer;

    setUp(() {
      store = InMemoryPointStore();
      buffer = LocationBuffer(store: store, maxPoints: 5);
    });

    test('batches are oldest first and limited to maxSize', () async {
      for (var i = 0; i < 4; i++) {
        await buffer.add(pointN(i));
      }

      final batch = buffer.peekBatch(3)!;

      expect(batch.points, [pointN(0), pointN(1), pointN(2)]);
      expect(buffer.length, 4, reason: 'peek does not remove');
    });

    test('peekBatch returns null when empty', () {
      expect(buffer.peekBatch(10), isNull);
    });

    test('acknowledge removes only the uploaded batch', () async {
      for (var i = 0; i < 3; i++) {
        await buffer.add(pointN(i));
      }
      final batch = buffer.peekBatch(2)!;

      // A new fix arrives while the upload is in flight.
      await buffer.add(pointN(3));
      await buffer.acknowledge(batch);

      expect(buffer.points, [pointN(2), pointN(3)]);
    });

    test('drops the oldest points when full and counts them', () async {
      for (var i = 0; i < 7; i++) {
        await buffer.add(pointN(i));
      }

      expect(buffer.points, [for (var i = 2; i < 7; i++) pointN(i)]);
      expect(buffer.droppedOverflow, 2);
    });

    test('acknowledge stays correct when overflow dropped points of the '
        'in-flight batch', () async {
      for (var i = 0; i < 5; i++) {
        await buffer.add(pointN(i));
      }
      final batch = buffer.peekBatch(3)!; // points 0..2

      // Offline for a while: 4 more fixes push out points 0..3.
      for (var i = 5; i < 9; i++) {
        await buffer.add(pointN(i));
      }
      await buffer.acknowledge(batch);

      expect(buffer.points, [for (var i = 4; i < 9; i++) pointN(i)]);
    });

    test('adds are appended to the store; acks rewrite it', () async {
      await buffer.add(pointN(0));
      await buffer.add(pointN(1));
      expect(store.appendCalls, 2);
      expect(store.replaceCalls, 0);
      expect(store.points, [pointN(0), pointN(1)]);

      await buffer.acknowledge(buffer.peekBatch(1)!);

      expect(store.replaceCalls, 1);
      expect(store.points, [pointN(1)]);
    });

    test('store writes keep call order across ack and add', () async {
      await buffer.add(pointN(0));
      final batch = buffer.peekBatch(1)!;

      // Not awaited one by one: the rewrite must not swallow the new point.
      final ack = buffer.acknowledge(batch);
      final add = buffer.add(pointN(1));
      await Future.wait([ack, add]);

      expect(store.points, [pointN(1)]);
    });

    test('compacts the store once it holds twice maxPoints lines', () async {
      for (var i = 0; i < 10; i++) {
        await buffer.add(pointN(i));
      }
      expect(store.replaceCalls, 0);
      expect(store.points.length, 10, reason: 'stale lines allowed up to 2x');

      await buffer.add(pointN(10));

      expect(store.replaceCalls, 1);
      expect(store.points, [for (var i = 6; i < 11; i++) pointN(i)]);
    });

    test('restore loads persisted points and keeps only the newest '
        'maxPoints', () async {
      final persisted = InMemoryPointStore([
        for (var i = 0; i < 8; i++) pointN(i),
      ]);
      final restored = LocationBuffer(store: persisted, maxPoints: 5);

      await restored.restore();

      expect(restored.points, [for (var i = 3; i < 8; i++) pointN(i)]);
      expect(restored.droppedOverflow, 3);
      expect(persisted.points, restored.points);
    });

    test('a failing store never loses points in memory and is rewritten '
        'once it recovers', () async {
      final failing = FailingPointStore();
      final b = LocationBuffer(store: failing, maxPoints: 5);

      await b.add(pointN(0));
      await b.add(pointN(1));
      expect(b.points, [pointN(0), pointN(1)]);
      expect(b.lastStoreError, isA<StateError>());

      failing.fail = false;
      await b.add(pointN(2));

      expect(failing.stored, [pointN(0), pointN(1), pointN(2)]);
    });
  });
}
