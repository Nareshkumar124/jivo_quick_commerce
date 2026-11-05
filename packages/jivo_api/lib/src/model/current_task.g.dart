// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_task.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CurrentTaskCWProxy {
  CurrentTask task(RiderTask? task);

  CurrentTask recentTask(RecentTask? recentTask);

  CurrentTask serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CurrentTask(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CurrentTask(...).copyWith(id: 12, name: "My name")
  /// ````
  CurrentTask call({
    RiderTask? task,
    RecentTask? recentTask,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCurrentTask.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCurrentTask.copyWith.fieldName(...)`
class _$CurrentTaskCWProxyImpl implements _$CurrentTaskCWProxy {
  const _$CurrentTaskCWProxyImpl(this._value);

  final CurrentTask _value;

  @override
  CurrentTask task(RiderTask? task) => this(task: task);

  @override
  CurrentTask recentTask(RecentTask? recentTask) =>
      this(recentTask: recentTask);

  @override
  CurrentTask serverTime(DateTime serverTime) => this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CurrentTask(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CurrentTask(...).copyWith(id: 12, name: "My name")
  /// ````
  CurrentTask call({
    Object? task = const $CopyWithPlaceholder(),
    Object? recentTask = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return CurrentTask(
      task: task == const $CopyWithPlaceholder()
          ? _value.task
          // ignore: cast_nullable_to_non_nullable
          : task as RiderTask?,
      recentTask: recentTask == const $CopyWithPlaceholder()
          ? _value.recentTask
          // ignore: cast_nullable_to_non_nullable
          : recentTask as RecentTask?,
      serverTime: serverTime == const $CopyWithPlaceholder()
          ? _value.serverTime
          // ignore: cast_nullable_to_non_nullable
          : serverTime as DateTime,
    );
  }
}

extension $CurrentTaskCopyWith on CurrentTask {
  /// Returns a callable class that can be used as follows: `instanceOfCurrentTask.copyWith(...)` or like so:`instanceOfCurrentTask.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CurrentTaskCWProxy get copyWith => _$CurrentTaskCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CurrentTask _$CurrentTaskFromJson(Map<String, dynamic> json) => $checkedCreate(
  'CurrentTask',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['task', 'recent_task', 'server_time'],
    );
    final val = CurrentTask(
      task: $checkedConvert(
        'task',
        (v) => v == null ? null : RiderTask.fromJson(v as Map<String, dynamic>),
      ),
      recentTask: $checkedConvert(
        'recent_task',
        (v) =>
            v == null ? null : RecentTask.fromJson(v as Map<String, dynamic>),
      ),
      serverTime: $checkedConvert(
        'server_time',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {'recentTask': 'recent_task', 'serverTime': 'server_time'},
);

Map<String, dynamic> _$CurrentTaskToJson(CurrentTask instance) =>
    <String, dynamic>{
      'task': instance.task?.toJson(),
      'recent_task': instance.recentTask?.toJson(),
      'server_time': instance.serverTime.toIso8601String(),
    };
