import 'package:jivo_core/jivo_core.dart';

import '../../../shared/fake_api_endpoint.dart';
import '../../../shared/paging.dart';
import '../../earnings/domain/earnings.dart';
import '../../onboarding/domain/validators.dart';
import '../../task/domain/rider_task.dart';
import '../../task/domain/task_status.dart';
import '../domain/task_history.dart';

/// Stands in for `GET /rider/tasks/history/` and `.../history/{id}/`
/// (06 §3) in `FAKE_API` builds and tests. Newest first; the cursor is a
/// page number here (the API's is a `before_id`).
class FakeHistoryBackend extends FakeApiEndpoint
    implements TaskHistoryRepository {
  FakeHistoryBackend({
    DateTime Function()? clock,
    super.delay = const Duration(milliseconds: 400),
    super.pageSize = 10,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  Future<Page<TaskHistoryEntry>> fetchHistory({int? cursor}) async {
    final page = cursor ?? 1;
    await recordCall('fetchHistory $page');
    return pageOf(_all(), page);
  }

  @override
  Future<TaskHistoryDetail> fetchDetail(int taskId) async {
    await recordCall('fetchDetail $taskId');
    final entry = _all().where((e) => e.taskId == taskId).firstOrNull;
    if (entry == null) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    final delivered = entry.status == TaskStatus.delivered;
    final cod = entry.taskId.isEven;
    final at = entry.completedAt;
    return TaskHistoryDetail(
      entry: entry,
      paymentType: cod ? PaymentType.cod : PaymentType.prepaid,
      codCollected: cod && delivered ? '349.00' : null,
      items: const [
        HistoryItem(name: 'Jivo Canola Oil', unit: '1 L', quantity: 2),
        HistoryItem(name: 'Jivo Olive Pomace Oil', unit: '500 ml', quantity: 1),
      ],
      itemCount: 3,
      assignedAt: at.subtract(const Duration(minutes: 20)),
      pickedUpAt: entry.status == TaskStatus.cancelled
          ? null
          : at.subtract(const Duration(minutes: 12)),
      deliveredAt: delivered ? at : null,
      returnedAt: entry.status == TaskStatus.returned ? at : null,
      cancelledAt: entry.status == TaskStatus.cancelled ? at : null,
      earningsTotal: delivered ? entry.payout : null,
      earningLines: delivered
          ? const [
              EarningLine(type: EarningType.base, amount: '30.00'),
              EarningLine(
                type: EarningType.distance,
                amount: '10.00',
                note: '2.4 km',
              ),
            ]
          : const [],
    );
  }

  List<TaskHistoryEntry> _all() {
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
    return all;
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
