// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_task.dart';
import 'package:jivo_api/src/model/recent_task.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'current_task.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CurrentTask {
  /// Returns a new [CurrentTask] instance.
  CurrentTask({
    required this.task,

    required this.recentTask,

    required this.serverTime,
  });

  /// The active task (ASSIGNED, AT_STORE, PICKED_UP, AT_CUSTOMER, RETURNING), or null.
  @JsonKey(name: r'task', required: true, includeIfNull: true)
  final RiderTask? task;

  /// When `task` is null: the rider's last task if it ended in the last 10 minutes (delivered, returned, or cancelled by the store/customer/ops), so a lost response can be explained. Null otherwise.
  @JsonKey(name: r'recent_task', required: true, includeIfNull: true)
  final RecentTask? recentTask;

  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrentTask &&
          other.task == task &&
          other.recentTask == recentTask &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      (task == null ? 0 : task.hashCode) +
      (recentTask == null ? 0 : recentTask.hashCode) +
      serverTime.hashCode;

  factory CurrentTask.fromJson(Map<String, dynamic> json) =>
      _$CurrentTaskFromJson(json);

  Map<String, dynamic> toJson() => _$CurrentTaskToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
