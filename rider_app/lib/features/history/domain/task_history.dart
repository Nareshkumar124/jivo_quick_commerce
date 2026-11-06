import '../../../shared/paging.dart';
import '../../earnings/domain/earnings.dart';
import '../../task/domain/rider_task.dart';
import '../../task/domain/task_rules.dart';
import '../../task/domain/task_status.dart';

/// A finished task (04 §2.8 "History").
class TaskHistoryEntry {
  const TaskHistoryEntry({
    required this.taskId,
    required this.orderNumber,
    required this.completedAt,
    required this.storeName,
    required this.dropLocality,
    required this.status,
    this.distanceKm,
    this.payout,
  });

  final int taskId;
  final String orderNumber;
  final DateTime completedAt;
  final String storeName;
  final String dropLocality;

  /// DELIVERED, RETURNED, CANCELLED (or FAILED while returning).
  final TaskStatus status;
  final String? distanceKm;

  /// What the rider earned on it, as the server sends it.
  final String? payout;
}

/// One line of what was in the bag.
class HistoryItem {
  const HistoryItem({required this.name, required this.quantity, this.unit});

  final String name;
  final String? unit;
  final int quantity;
}

/// `GET /rider/tasks/history/{id}/` (04 §2.8): one ended task with its
/// items, times and pay lines. No customer personal data (locality only).
class TaskHistoryDetail {
  const TaskHistoryDetail({
    required this.entry,
    required this.paymentType,
    required this.items,
    required this.itemCount,
    this.codCollected,
    this.assignedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.failedAt,
    this.failReason,
    this.returnedAt,
    this.cancelledAt,
    this.earningsTotal,
    this.earningLines = const [],
  });

  final TaskHistoryEntry entry;
  final PaymentType paymentType;
  final List<HistoryItem> items;
  final int itemCount;

  /// COD delivered: the amount collected (cash or UPI), as sent.
  final String? codCollected;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? failedAt;

  /// Null for a reason this app version does not know.
  final FailReason? failReason;
  final DateTime? returnedAt;
  final DateTime? cancelledAt;

  /// `earnings.total` and its lines (DELIVERED only), as sent.
  final String? earningsTotal;
  final List<EarningLine> earningLines;
}

/// `GET /rider/tasks/history/` (06 §3), newest first, and one task. Throws
/// jivo_core's `ApiError`.
abstract interface class TaskHistoryRepository {
  /// [cursor]: null for the newest, then the previous page's `nextPage` (a
  /// `before_id`; api-requests #24).
  Future<Page<TaskHistoryEntry>> fetchHistory({int? cursor});

  /// 404 for another rider's task or one still active.
  Future<TaskHistoryDetail> fetchDetail(int taskId);
}
