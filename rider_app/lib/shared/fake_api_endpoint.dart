import 'package:flutter/foundation.dart';
import 'package:jivo_core/jivo_core.dart';

import 'paging.dart';

/// TODO(api): shared plumbing of the rider records fakes (earnings, cash,
/// history) until the rider contract lands: a delay like the network, a
/// call log for tests, an optional failure for the next call, and paging
/// like the API (02 §5).
///
/// Dev flavor and tests only (DL-30, DL-32): the repository providers hand
/// out a fake only when `riderWorkEnabledProvider` is true.
abstract class FakeApiEndpoint {
  FakeApiEndpoint({required this.delay, required this.pageSize});

  final Duration delay;
  final int pageSize;

  /// Calls made, in order (for tests).
  final List<String> calls = [];

  /// When set, the next call fails with it (then it is cleared).
  ApiError? failNext;

  /// Logs [name], waits [delay], then throws [failNext] if set.
  @protected
  Future<void> recordCall(String name) async {
    calls.add(name);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  /// Page [page] (from 1) of [all], [pageSize] items per page.
  @protected
  Page<T> pageOf<T>(List<T> all, int page) {
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, all.length);
    return Page(
      items: start >= all.length ? const [] : all.sublist(start, end),
      nextPage: end < all.length ? page + 1 : null,
      count: all.length,
    );
  }
}

/// The UTC instant of [hour]:[minute] IST on [istDate], an Indian calendar
/// date held as a UTC-midnight value (what `istToday()` returns). The fakes
/// build every demo time with it, so an entry meant for a day stays on that
/// IST day once the screen converts it back (a date value is not an
/// instant: midnight UTC is already 05:30 IST).
DateTime istWallClock(DateTime istDate, int hour, [int minute = 0]) =>
    DateTime.utc(
      istDate.year,
      istDate.month,
      istDate.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 5, minutes: 30));

/// `YYYY-MM-DD`, as the API takes dates in query strings.
String apiDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
