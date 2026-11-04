import '../../../shared/fake_api_endpoint.dart';
import '../../../shared/paging.dart';
import '../../onboarding/domain/validators.dart';
import '../../task/domain/task_status.dart';
import '../domain/task_history.dart';

/// TODO(api): stands in for `GET /rider/tasks/history/` (06 §3) until the
/// rider contract lands (end of P4). Newest first, paged like the API.
class FakeHistoryBackend extends FakeApiEndpoint
    implements TaskHistoryRepository {
  FakeHistoryBackend({
    DateTime Function()? clock,
    super.delay = const Duration(milliseconds: 400),
    super.pageSize = 10,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  Future<Page<TaskHistoryEntry>> fetchHistory({int page = 1}) async {
    await recordCall('fetchHistory $page');
    final today = istToday(_clock());
    const statuses = [
      TaskStatus.delivered,
      TaskStatus.delivered,
      TaskStatus.returned,
      TaskStatus.delivered,
      TaskStatus.cancelled,
    ];
    final all = [
      for (var i = 0; i < 23; i++)
        TaskHistoryEntry(
          taskId: 600 - i,
          orderNumber: 'JQ-10${501 - i}',
          completedAt: completedAtOf(today, i),
          storeName: 'Jivo Sector 18',
          dropLocality: i.isEven ? 'Sector 21, Noida' : 'Sector 27, Noida',
          status: statuses[i % statuses.length],
          // A cancelled task before pickup has no distance or payout.
          distanceKm: statuses[i % statuses.length] == TaskStatus.cancelled
              ? null
              : '${2 + i % 4}.${i % 10}',
          payout: statuses[i % statuses.length] == TaskStatus.cancelled
              ? null
              : '${40 + i % 3 * 5}.00',
        ),
    ];
    return pageOf(all, page);
  }

  /// Four tasks a day, newest first: entry [i] ended on the IST day
  /// `today - i ~/ 4` (today: an IST date as `istToday()` returns it) at
  /// 11:40, 10:45, 09:20 or 08:05 IST.
  static DateTime completedAtOf(DateTime today, int i) {
    const times = [(11, 40), (10, 45), (9, 20), (8, 5)];
    final (hour, minute) = times[i % times.length];
    final day = today.subtract(Duration(days: i ~/ times.length));
    return istWallClock(day, hour, minute);
  }
}
