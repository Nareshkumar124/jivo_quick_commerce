import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../task/presentation/task_providers.dart';
import '../data/api_today_summary.dart';
import '../data/fake_today_summary.dart';
import '../domain/today_summary.dart';

/// The fake today summary (`FAKE_API` builds). Overridden in tests.
final fakeTodaySummaryProvider = Provider<FakeTodaySummary>(
  (ref) => FakeTodaySummary(),
);

final todaySummaryRepositoryProvider = Provider<TodaySummaryRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) {
    return const UnavailableTodaySummary();
  }
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeTodaySummaryProvider);
  }
  return ApiTodaySummary(ref.watch(jivoApiProvider));
});

/// Home's today tiles. Refreshed by pull-to-refresh, on going online or
/// offline, and when a task ends (`ref.invalidate`).
final todaySummaryProvider = FutureProvider<TodaySummary>(
  (ref) => ref.watch(todaySummaryRepositoryProvider).fetch(),
);
