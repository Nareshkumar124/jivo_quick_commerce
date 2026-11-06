import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/location/domain/backoff.dart';

/// Always returns [value] (0 = no jitter, close to 1 = maximum jitter).
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

void main() {
  Backoff build({double random = 0}) => Backoff(
    initial: const Duration(seconds: 10),
    max: const Duration(seconds: 60),
    random: _FixedRandom(random),
  );

  test('doubles from the initial delay up to the cap', () {
    final backoff = build();
    expect(
      [for (var i = 0; i < 5; i++) backoff.fail().inSeconds],
      [10, 20, 40, 60, 60],
    );
    expect(backoff.failures, 5);
  });

  test('reset starts again from the initial delay', () {
    final backoff = build()
      ..fail()
      ..fail()
      ..reset();
    expect(backoff.failures, 0);
    expect(backoff.fail(), const Duration(seconds: 10));
  });

  test('jitter only shortens the delay, by at most 20 %', () {
    final backoff = build(random: 0.999);
    final first = backoff.fail();
    expect(first, lessThanOrEqualTo(const Duration(seconds: 10)));
    expect(first, greaterThanOrEqualTo(const Duration(seconds: 8)));
  });

  test("a longer server hint (Retry-After) wins, still capped", () {
    final backoff = build();
    expect(
      backoff.fail(serverHint: const Duration(seconds: 45)),
      const Duration(seconds: 45),
    );
    expect(
      backoff.fail(serverHint: const Duration(minutes: 10)),
      const Duration(seconds: 60),
    );
    expect(
      backoff.fail(serverHint: const Duration(seconds: 1)),
      const Duration(seconds: 40),
      reason: 'a shorter hint does not shorten the backoff',
    );
  });

  test('many failures never overflow', () {
    final backoff = build();
    for (var i = 0; i < 200; i++) {
      backoff.fail();
    }
    expect(backoff.fail(), const Duration(seconds: 60));
  });
}
