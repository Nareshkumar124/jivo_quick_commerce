import 'dart:math';

/// Exponential backoff with jitter for retrying uploads on a bad network.
///
/// The delay after the n-th consecutive failure (n starting at 1) is
/// `initial * multiplier^(n-1)`, capped at [max], then reduced by up to
/// [jitter] (a fraction) so that many riders who lost the network together
/// do not all retry at the same second when it comes back.
///
/// Pure Dart; [random] is injectable for tests.
class Backoff {
  Backoff({
    required this.initial,
    required this.max,
    this.multiplier = 2,
    this.jitter = 0.2,
    Random? random,
  }) : assert(initial > Duration.zero),
       assert(max >= initial),
       assert(multiplier >= 1),
       assert(jitter >= 0 && jitter < 1),
       _random = random ?? Random();

  final Duration initial;
  final Duration max;
  final double multiplier;
  final double jitter;
  final Random _random;

  int _failures = 0;

  /// Consecutive failures since the last [reset].
  int get failures => _failures;

  /// Records a failure and returns how long to wait before the next try.
  /// [serverHint] (for example a `Retry-After` header) wins when it is
  /// longer than the computed delay; it is still capped at [max].
  Duration fail({Duration? serverHint}) {
    _failures++;
    final exponent = min(_failures - 1, 30);
    final rawMs = initial.inMilliseconds * pow(multiplier, exponent);
    final cappedMs = min(rawMs, max.inMilliseconds.toDouble());
    final jittered = cappedMs * (1 - jitter * _random.nextDouble());
    var delay = Duration(milliseconds: jittered.round());
    if (serverHint != null && serverHint > delay) {
      delay = serverHint > max ? max : serverHint;
    }
    return delay;
  }

  /// Call after a success.
  void reset() => _failures = 0;
}
